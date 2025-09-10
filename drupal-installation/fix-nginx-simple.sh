#!/bin/bash

# Простое исправление Nginx для статических файлов Drupal

echo "🔧 Упрощенное исправление Nginx..."

# Создаем простую конфигурацию с разрешением для sites/default/files
cat > /etc/nginx/sites-available/drupal-ssl << 'EOF'
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

server {
    listen 443 ssl http2;
    server_name storage.omuzgorpro.tj;
    root /var/www/drupal/web;
    index index.php;

    ssl_certificate /etc/letsencrypt/live/storage.omuzgorpro.tj/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/storage.omuzgorpro.tj/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 100M;

    # ГЛАВНОЕ: Разрешаем все файлы из sites/default/files/
    location ^~ /sites/default/files/ {
        expires 1y;
        try_files $uri =404;
    }

    # Разрешаем статические файлы из core/
    location ^~ /core/ {
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            try_files $uri =404;
        }
        location ~ \.php$ {
            deny all;
        }
    }

    # Favicon
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    # Clean URLs
    location / {
        try_files $uri /index.php?$query_string;
    }

    # PHP processing
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTPS on;
    }

    # Блокируем доступ к опасным файлам
    location ~ /\. {
        deny all;
    }
}
EOF

echo "✅ Конфигурация упрощена"

# Тестируем и перезагружаем
nginx -t && systemctl reload nginx

echo "✅ Nginx перезагружен"
echo "📌 Теперь все файлы из sites/default/files/ должны быть доступны"
