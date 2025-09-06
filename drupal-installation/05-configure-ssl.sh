#!/bin/bash

# RTTI Drupal - Шаг 5: Настройка SSL/TLS
# Сервер: storage.omuzgorpro.tj (92.242.61.204)
# ИСПРАВЛЕНО: убрана поддержка www домена

echo "=== RTTI Drupal - Шаг 5: Настройка SSL/TLS для storage.omuzgorpro.tj ==="
echo "🔒 Let's Encrypt SSL сертификаты для цифровой библиотеки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DOMAIN="storage.omuzgorpro.tj"
EMAIL="admin@omuzgorpro.tj"

echo "1. Установка Certbot для Let's Encrypt..."
apt install -y certbot python3-certbot-nginx

echo "2. Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Ошибка конфигурации Nginx"
    exit 1
fi

echo "3. Создание временного HTTP сайта для получения сертификата..."
mkdir -p /var/www/html
echo "<!DOCTYPE html><html><head><title>RTTI Digital Library</title></head><body><h1>RTTI Digital Library - SSL Setup</h1><p>Настройка SSL...</p></body></html>" > /var/www/html/index.html

# Временная конфигурация только для HTTP
cat > /etc/nginx/sites-available/drupal-temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/html;
    index index.html;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Активация временной конфигурации
ln -sf /etc/nginx/sites-available/drupal-temp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/drupal-default

echo "4. Перезапуск Nginx..."
systemctl reload nginx

echo "5. Получение SSL сертификата от Let's Encrypt..."
certbot certonly \
    --nginx \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domains $DOMAIN

if [ $? -eq 0 ]; then
    echo "✅ SSL сертификат получен успешно"
else
    echo "❌ Ошибка получения SSL сертификата"
    echo "Проверьте:"
    echo "1. DNS записи для $DOMAIN (A-запись должна указывать на $(hostname -I | awk '{print $1}'))"
    echo "2. Доступность порта 80 (ufw allow 80/tcp)"
    echo "3. Корректность email $EMAIL"
    echo "4. Логи: /var/log/letsencrypt/letsencrypt.log"
    echo ""
    echo "Команда для повторной попытки:"
    echo "certbot certonly --nginx --non-interactive --agree-tos --email $EMAIL --domains $DOMAIN"
    exit 1
fi

echo "6. Создание HTTPS конфигурации Nginx для Drupal..."
cat > /etc/nginx/sites-available/drupal-ssl << EOF
# HTTP redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server for Drupal
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    root /var/www/drupal/web;
    index index.php;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; img-src 'self' data: https:; font-src 'self' data: https:;" always;
    
    # File upload size
    client_max_body_size 100M;
    
    # Drupal specific configurations
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    
    # Deny access to configuration files
    location ~ \..*/.*\.php$ {
        return 403;
    }
    
    location ~ ^/sites/.*/private/ {
        return 403;
    }
    
    location ~ ^/sites/[^/]+/files/.*\.php$ {
        deny all;
    }
    
    location ~* ^/.well-known/ {
        allow all;
    }
    
    location ~ (^|/)\. {
        return 403;
    }
    
    # Drupal clean URLs
    location / {
        try_files \$uri /index.php?\$query_string;
    }
    
    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=\$1;
    }
    
    # PHP processing
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Drupal specific parameters
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_path_info;
        fastcgi_param QUERY_STRING \$query_string;
        fastcgi_param REQUEST_METHOD \$request_method;
        fastcgi_param CONTENT_TYPE \$content_type;
        fastcgi_param CONTENT_LENGTH \$content_length;
        fastcgi_param HTTPS on;
        
        fastcgi_intercept_errors on;
        fastcgi_ignore_client_abort off;
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 180;
        fastcgi_read_timeout 180;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }
    
    # Static files caching and optimization
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        log_not_found off;
        
        # Gzip compression for static assets
        gzip_static on;
    }
    
    # Deny access to vendor and other sensitive directories
    location ^~ /vendor/ {
        deny all;
        return 403;
    }
    
    location ^~ /core/ {
        deny all;
        return 403;
    }
    
    location ~* composer\.(json|lock)$ {
        deny all;
        return 403;
    }
    
    location ~* package\.json$ {
        deny all;
        return 403;
    }
    
    # Drupal file serving for private files
    location ^~ /system/files/ {
        try_files \$uri /index.php?\$query_string;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_min_length 1000;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json
        application/xml
        application/xml+rss
        application/atom+xml
        image/svg+xml;
}
EOF

echo "7. Удаление временной конфигурации и активация SSL..."
rm -f /etc/nginx/sites-enabled/drupal-temp
ln -sf /etc/nginx/sites-available/drupal-ssl /etc/nginx/sites-enabled/

echo "8. Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Ошибка конфигурации Nginx"
    exit 1
fi

echo "9. Перезапуск Nginx..."
systemctl reload nginx

echo "10. Настройка автоматического обновления сертификатов..."
cat > /etc/cron.d/certbot-renewal-drupal << 'EOF'
# Автоматическое обновление Let's Encrypt сертификатов для Drupal
# Проверка дважды в день
0 12 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
0 0 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
EOF

echo "11. Проверка SSL сертификата..."
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -text -noout | grep -A 3 "Validity"

echo "12. Тестирование HTTPS подключения..."
curl -I https://$DOMAIN >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ HTTPS работает корректно"
else
    echo "⚠️  HTTPS может работать некорректно"
fi

echo "13. Создание скрипта проверки SSL..."
cat > /root/drupal-ssl-check.sh << EOF
#!/bin/bash
echo "=== Drupal SSL Certificate Status ==="
certbot certificates

echo -e "\n=== Certificate Expiry ==="
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -dates

echo -e "\n=== HTTPS Test ==="
curl -I https://$DOMAIN 2>/dev/null | head -3

echo -e "\n=== SSL Security Test ==="
echo "Проверьте SSL на: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"

echo -e "\n=== Nginx SSL Configuration ==="
nginx -T | grep -A 5 -B 5 ssl_certificate
EOF

chmod +x /root/drupal-ssl-check.sh

echo "14. Настройка файрвола для HTTPS..."
ufw allow 443/tcp comment "HTTPS Drupal"
ufw status

echo "15. Создание файла с информацией о SSL..."
cat > /root/drupal-ssl-info.txt << EOF
# SSL/TLS информация для Drupal
# Дата создания: $(date)
# Сервер: storage.omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

Домен: $DOMAIN
SSL сертификат: Let's Encrypt
Путь к сертификату: /etc/letsencrypt/live/$DOMAIN/
Конфигурация Nginx: /etc/nginx/sites-available/drupal-ssl

# Команды для управления:
# Проверка статуса: certbot certificates
# Обновление: certbot renew
# Тест конфигурации: nginx -t
# Перезагрузка: systemctl reload nginx

# Скрипт проверки: /root/drupal-ssl-check.sh

# Автоматическое обновление:
# - Сертификат обновляется автоматически через cron
# - Проверяйте лог: /var/log/letsencrypt/letsencrypt.log
# - При смене IP нужно обновить DNS записи

# Безопасность:
# - HSTS включен (Strict-Transport-Security)
# - Принудительное перенаправление HTTP -> HTTPS
# - Безопасные заголовки настроены
# - CSP политика установлена для Drupal

# Производительность:
# - HTTP/2 включен
# - Gzip сжатие активировано
# - Кэширование статических файлов
# - Оптимизация для Drupal

EOF

echo
echo "✅ Шаг 5 завершен успешно!"
echo "📌 SSL/TLS настроен для https://$DOMAIN"
echo "📌 Let's Encrypt сертификат установлен"
echo "📌 Автоматическое обновление настроено"
echo "📌 HTTPS принудительно включен"
echo "📌 Nginx оптимизирован для Drupal"
echo "📌 Скрипт проверки: /root/drupal-ssl-check.sh"
echo "📌 Информация о SSL: /root/drupal-ssl-info.txt"
echo "📌 Следующий шаг: ./06-install-drupal.sh"
echo
