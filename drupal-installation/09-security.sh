#!/bin/bash

# RTTI Drupal - Шаг 9: Настройка безопасности
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 9: Углубленная настройка безопасности ==="
echo "🛡️ Комплексная защита системы"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"
NGINX_DIR="/etc/nginx"
PHP_VERSION="8.3"

echo "1. Настройка Fail2Ban для защиты от атак..."

# Установка Fail2Ban
apt update && apt install -y fail2ban

# Конфигурация Fail2Ban для Nginx
cat > /etc/fail2ban/jail.d/nginx-drupal.conf << 'EOF'
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600
findtime = 600

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/drupal_access.log
maxretry = 6
bantime = 86400
findtime = 60

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/drupal_access.log
maxretry = 2
bantime = 86400
findtime = 60

[drupal-auth]
enabled = true
port = http,https
filter = drupal-auth
logpath = /var/log/nginx/drupal_access.log
maxretry = 3
findtime = 300
bantime = 1800
EOF

# Создание фильтров для Drupal
cat > /etc/fail2ban/filter.d/drupal-auth.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"POST /user/login HTTP.*" 200
            ^<HOST> -.*"POST /admin/.* HTTP.*" 403
ignoreregex =
EOF

# Перезапуск Fail2Ban
systemctl restart fail2ban
systemctl enable fail2ban

echo "✅ Fail2Ban настроен для Drupal"

echo "2. Настройка ограничений скорости Nginx..."

# Обновление основной конфигурации Nginx
cat > "$NGINX_DIR/nginx.conf" << 'EOF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;
    
    # Connection limiting
    limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
    limit_conn conn_limit_per_ip 20;
    
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Buffer sizes
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    client_max_body_size 10m;
    large_client_header_buffers 4 4k;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        image/svg+xml;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Include additional configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

echo "✅ Основная конфигурация Nginx обновлена"

echo "3. Создание безопасной конфигурации сайта..."

# Конфигурация сайта с ограничениями безопасности
cat > "$NGINX_DIR/sites-available/drupal" << 'EOF'
# Конфигурация Nginx для Drupal с безопасностью
server {
    listen 80;
    server_name storage.omuzgorpro.tj;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name storage.omuzgorpro.tj;
    
    root /var/www/drupal/web;
    index index.php;
    
    # SSL конфигурация
    ssl_certificate /etc/letsencrypt/live/storage.omuzgorpro.tj/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/storage.omuzgorpro.tj/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/storage.omuzgorpro.tj/chain.pem;
    
    # Логи
    access_log /var/log/nginx/drupal_access.log;
    error_log /var/log/nginx/drupal_error.log;
    
    # Базовые файлы
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    
    # Ограничения доступа к системным файлам
    location ~* \.(txt|log)$ {
        allow 192.168.0.0/16;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        deny all;
    }
    
    # Блокировка опасных файлов
    location ~ \..*/.*\.php$ {
        return 403;
    }
    
    location ~ ^/sites/.*/private/ {
        return 403;
    }
    
    location ~ (^|/)\. {
        return 403;
    }
    
    location ~* \.(module|inc|install|engine|theme|tpl(\.php)?$|info|po|sh|.*sql|xtmpl)$ {
        deny all;
    }
    
    # Ограничения на логин
    location = /user/login {
        limit_req zone=login burst=3 nodelay;
        try_files $uri /index.php?$query_string;
    }
    
    # Ограничения на админку
    location ^~ /admin {
        limit_req zone=api burst=10 nodelay;
        allow 192.168.0.0/16;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 109.75.50.43;
        deny all;
        try_files $uri /index.php?$query_string;
    }
    
    # Основная обработка
    location / {
        limit_req zone=general burst=20 nodelay;
        try_files $uri /index.php?$query_string;
    }
    
    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }
    
    # PHP обработка для Drupal 8+
    location ~ '\.php$|^/update.php' {
        limit_req zone=api burst=15 nodelay;
        
        fastcgi_split_path_info ^(.+?\.php)(|/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $request_filename;
        fastcgi_intercept_errors on;
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        fastcgi_param HTTPS on;
        
        fastcgi_param HTTP_PROXY "";
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }
    
    # Styles обработка
    location ~ ^/sites/.*/files/styles/ {
        try_files $uri @rewrite;
    }
    
    # Статические файлы
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires max;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options nosniff;
        log_not_found off;
        access_log off;
    }
}
EOF

echo "✅ Конфигурация сайта создана"

echo "4. Настройка файрвола UFW..."

# Настройка файрвола
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 127.0.0.1 to any port 5432
ufw allow from 127.0.0.1 to any port 6379

ufw --force enable

echo "✅ Файрвол UFW настроен"

echo "5. Применение конфигураций..."

# Проверка конфигурации Nginx
nginx -t
if [ $? -eq 0 ]; then
    echo "✅ Конфигурация Nginx корректна"
    
    ln -sf "$NGINX_DIR/sites-available/drupal" "$NGINX_DIR/sites-enabled/"
    rm -f "$NGINX_DIR/sites-enabled/default"
    
    systemctl restart nginx
    systemctl restart php${PHP_VERSION}-fpm
    
    echo "✅ Nginx и PHP перезапущены"
else
    echo "❌ Ошибка в конфигурации Nginx!"
    exit 1
fi

echo "6. Финальная проверка..."

echo "📊 Статус сервисов:"
systemctl is-active nginx && echo "✅ Nginx активен" || echo "❌ Nginx неактивен"
systemctl is-active php${PHP_VERSION}-fpm && echo "✅ PHP-FPM активен" || echo "❌ PHP-FPM неактивен"
systemctl is-active postgresql && echo "✅ PostgreSQL активен" || echo "❌ PostgreSQL неактивен"
systemctl is-active redis-server && echo "✅ Redis активен" || echo "❌ Redis неактивен"
systemctl is-active fail2ban && echo "✅ Fail2Ban активен" || echo "❌ Fail2Ban неактивен"
systemctl is-active ufw && echo "✅ UFW активен" || echo "❌ UFW неактивен"

echo
echo "🎉 УСПЕШНО: Настройка безопасности завершена!"
echo
echo "📋 Система защищена от:"
echo "   • Атак перебора паролей (Fail2Ban)"
echo "   • DDoS атак (Rate limiting)"
echo "   • Несанкционированного доступа (Файрвол)"
echo "   • Уязвимостей веб-сервера (Безопасные заголовки)"
echo "   • Утечек данных (Ограничения доступа)"
echo
echo "🔐 Мониторинг:"
echo "   • Логи: /var/log/nginx/drupal_*.log"
echo "   • Fail2Ban: fail2ban-client status"
echo "   • Файрвол: ufw status"
echo
echo "⚠️  ВАЖНО: Регулярно обновляйте систему и проверяйте логи!"
