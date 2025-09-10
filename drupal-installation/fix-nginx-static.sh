#!/bin/bash

# Скрипт для исправления конфигурации Nginx - разрешение статических файлов Drupal

echo "🔧 Исправление конфигурации Nginx для статических файлов Drupal..."

# Создаем исправленную конфигурацию
cat > /etc/nginx/sites-available/drupal-ssl << 'EOF'
# HTTP redirect to HTTPS
server {
    listen 80;
    server_name storage.omuzgorpro.tj;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server for Drupal
server {
    listen 443 ssl http2;
    server_name storage.omuzgorpro.tj;

    root /var/www/drupal/web;
    index index.php;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/storage.omuzgorpro.tj/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/storage.omuzgorpro.tj/privkey.pem;
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

    # Favicon and robots - разрешаем доступ
    location = /favicon.ico {
        log_not_found off;
        access_log off;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # Статические файлы из core (шрифты, CSS, JS) - разрешаем доступ!
    location ~* ^/core/.*\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        log_not_found off;
        try_files $uri =404;
    }

    # Статические файлы из sites/default/files
    location ~* ^/sites/.*/files/.*\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        log_not_found off;
        try_files $uri =404;
    }

    # Общие статические файлы - должны идти ПЕРЕД блокировкой PHP
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        log_not_found off;
        try_files $uri =404;
    }

    # Блокировка исполняемых PHP файлов в опасных местах
    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    location ~ ^/sites/[^/]+/files/.*\.php$ {
        deny all;
    }

    # Блокировка PHP файлов в core, но НЕ статических ресурсов
    location ~ ^/core/.*\.php$ {
        deny all;
        return 403;
    }

    # Блокировка доступа к vendor директории (только PHP файлы)
    location ~ ^/vendor/.*\.php$ {
        deny all;
        return 403;
    }

    location ~* ^/.well-known/ {
        allow all;
    }

    location ~ (^|/)\. {
        return 403;
    }

    # Drupal clean URLs
    location / {
        try_files $uri /index.php?$query_string;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }

    # PHP processing - обработка PHP файлов
    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_index index.php;
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
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

    # Блокировка конфигурационных файлов (должна быть в конце)
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
        try_files $uri /index.php?$query_string;
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

echo "✅ Конфигурация Nginx обновлена"

# Проверяем конфигурацию
echo "🔍 Проверка конфигурации Nginx..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Конфигурация Nginx корректна"
    
    # Перезагружаем Nginx
    echo "🔄 Перезагрузка Nginx..."
    systemctl reload nginx
    
    if [ $? -eq 0 ]; then
        echo "✅ Nginx успешно перезагружен"
        echo ""
        echo "🎉 Исправление завершено!"
        echo "📌 Теперь статические файлы Drupal должны загружаться корректно"
        echo "📌 Проверьте сайт: https://storage.omuzgorpro.tj"
    else
        echo "❌ Ошибка перезагрузки Nginx"
        systemctl status nginx
    fi
else
    echo "❌ Ошибка в конфигурации Nginx"
    nginx -t
fi

# Проверяем права доступа к файлам
echo ""
echo "🔍 Проверка прав доступа к статическим файлам..."
if [ -d "/var/www/drupal/web/core" ]; then
    echo "📁 Директория /var/www/drupal/web/core существует"
    ls -la /var/www/drupal/web/core/ | head -5
    
    if [ -d "/var/www/drupal/web/core/themes" ]; then
        echo "📁 Директория тем существует"
        ls -la /var/www/drupal/web/core/themes/ | head -3
    fi
    
    # Проверяем права доступа
    echo ""
    echo "🔧 Исправление прав доступа..."
    chown -R www-data:www-data /var/www/drupal/web/
    chmod -R 755 /var/www/drupal/web/
    
    echo "✅ Права доступа исправлены"
else
    echo "❌ Директория /var/www/drupal/web/core не найдена"
fi

echo ""
echo "📋 Лог Nginx для диагностики:"
echo "   sudo tail -f /var/log/nginx/error.log"
echo "   sudo tail -f /var/log/nginx/access.log"
