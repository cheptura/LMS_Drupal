#!/bin/bash

# RTTI Drupal - Шаг 9: Базовая безопасность
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 9: Настройка безопасности ==="
echo "🛡️ Базовая защита системы"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

NGINX_DIR="/etc/nginx"
PHP_VERSION="8.3"

echo "1. Удаление конфликтующих файлов..."

# Удаление проблемных конфигураций
rm -f "$NGINX_DIR/conf.d/drupal-static.conf"
rm -f "$NGINX_DIR/conf.d/drupal-performance.conf"

echo "2. Настройка основного Nginx..."

# Простая безопасная конфигурация nginx.conf
cat > "$NGINX_DIR/nginx.conf" << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Базовые настройки
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Ограничения размеров
    client_max_body_size 100m;
    client_body_buffer_size 128k;
    
    # Gzip сжатие
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
        application/json;
    
    # Базовые заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Include конфигурации
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

echo "3. Создание безопасной конфигурации сайта..."

# Простая безопасная конфигурация Drupal
cat > "$NGINX_DIR/sites-available/drupal-ssl" << 'EOF'
# Безопасная конфигурация Drupal
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
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    
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
    
    # Основная обработка
    location / {
        try_files $uri /index.php?$query_string;
    }
    
    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }
    
    # PHP обработка
    location ~ '\.php$|^/update.php' {
        fastcgi_split_path_info ^(.+?\.php)(|/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $request_filename;
        fastcgi_intercept_errors on;
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        fastcgi_param HTTPS on;
    }
    
    # Styles обработка
    location ~ ^/sites/.*/files/styles/ {
        try_files $uri @rewrite;
    }
    
    # Статические файлы - optimized for Drupal aggregation
    location ~* \.(css|js|jpg|jpeg|gif|png|ico|svg|woff2?|ttf|eot)$ {
        try_files $uri /index.php?$query_string;
        expires 1M;
        access_log off;
        add_header Cache-Control "public";
    }
}
EOF

echo "4. Настройка базового файрвола..."

# Простая настройка UFW
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

echo "5. Применение настроек..."

# Проверка конфигурации Nginx
if nginx -t >/dev/null 2>&1; then
    echo "   ✅ Конфигурация Nginx корректна"
    
    # Активация сайта
    ln -sf "$NGINX_DIR/sites-available/drupal-ssl" "$NGINX_DIR/sites-enabled/"
    rm -f "$NGINX_DIR/sites-enabled/default"
    rm -f "$NGINX_DIR/sites-enabled/drupal-temp"
    
    # Перезапуск сервисов
    systemctl restart nginx
    systemctl restart php$PHP_VERSION-fpm
    
    echo "   ✅ Nginx и PHP перезапущены"
else
    echo "   ❌ Ошибка в конфигурации Nginx!"
    nginx -t
    exit 1
fi

echo "6. Проверка статуса..."

echo "📊 Статус сервисов:"
systemctl is-active nginx && echo "✅ Nginx активен" || echo "❌ Nginx неактивен"
systemctl is-active php$PHP_VERSION-fpm && echo "✅ PHP-FPM активен" || echo "❌ PHP-FPM неактивен"
systemctl is-active postgresql && echo "✅ PostgreSQL активен" || echo "❌ PostgreSQL неактивен"
systemctl is-active ufw && echo "✅ UFW активен" || echo "❌ UFW неактивен"

echo
echo "✅ Шаг 9 завершен успешно!"
echo "🛡️ Базовая безопасность настроена"
echo "🔧 Конфигурация Nginx оптимизирована"
echo "🚫 Файрвол активирован"
echo "📌 Следующий шаг: ./10-final-check.sh"
echo
