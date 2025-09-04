#!/bin/bash

# RTTI Moodle - Quick SSL Fix
# Быстрое исправление SSL для lms.rtti.tj (только основной домен)

echo "=== RTTI Moodle - Быстрое исправление SSL ==="
echo "🔧 Получение SSL сертификата только для lms.rtti.tj"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DOMAIN="lms.rtti.tj"
EMAIL="admin@rtti.tj"

echo "1. Остановка и очистка предыдущих попыток..."
# Удаляем неудачные сертификаты
certbot delete --cert-name $DOMAIN --non-interactive 2>/dev/null || true

echo "2. Создание простой конфигурации Nginx для проверки..."
# Создаем минимальную конфигурацию только для HTTP
cat > /etc/nginx/sites-available/moodle-ssl-temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/html;
    index index.html;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    location / {
        return 200 'SSL Setup in progress...';
        add_header Content-Type text/plain;
    }
}
EOF

# Создаем директорию для проверки
mkdir -p /var/www/html/.well-known/acme-challenge/
echo "test" > /var/www/html/.well-known/acme-challenge/test.txt

# Активируем временную конфигурацию
rm -f /etc/nginx/sites-enabled/*
ln -sf /etc/nginx/sites-available/moodle-ssl-temp /etc/nginx/sites-enabled/

echo "3. Перезапуск Nginx..."
nginx -t && systemctl reload nginx

echo "4. Получение SSL сертификата ТОЛЬКО для основного домена..."
certbot certonly \
    --webroot \
    --webroot-path=/var/www/html \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domains $DOMAIN \
    --verbose

if [ $? -eq 0 ]; then
    echo "✅ SSL сертификат получен успешно!"
    
    echo "5. Создание полной конфигурации Nginx с SSL..."
    cat > /etc/nginx/sites-available/moodle-ssl << EOF
# HTTP - перенаправление на HTTPS
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

# HTTPS
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    root /var/www/moodle;
    index index.php;
    
    # SSL сертификаты
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Размеры загрузки файлов
    client_max_body_size 100M;
    
    # PHP обработка
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Moodle специфичные настройки
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_path_info;
        fastcgi_read_timeout 300;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }
    
    # Статические файлы
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Moodle специфичные настройки
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # Запрет доступа к конфигурационным файлам
    location ~ /\.ht {
        deny all;
    }
    
    location ~ /config\.php {
        deny all;
    }
    
    # Блокировка доступа к скрытым файлам
    location ~ /\. {
        deny all;
    }
}
EOF

    echo "6. Активация SSL конфигурации..."
    rm -f /etc/nginx/sites-enabled/*
    ln -sf /etc/nginx/sites-available/moodle-ssl /etc/nginx/sites-enabled/
    
    echo "7. Проверка и перезапуск Nginx..."
    nginx -t && systemctl reload nginx
    
    echo "8. Настройка автообновления сертификатов..."
    cat > /etc/cron.d/certbot-renewal << 'EOF'
0 12 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
0 0 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
EOF

    echo "9. Тестирование HTTPS..."
    sleep 2
    curl -I https://$DOMAIN 2>/dev/null | head -1
    
    echo
    echo "✅ SSL настроен успешно!"
    echo "🌐 Ваш сайт доступен по адресу: https://$DOMAIN"
    echo "📋 Информация о сертификате:"
    certbot certificates
    
else
    echo "❌ Ошибка получения SSL сертификата"
    echo
    echo "Проверьте логи:"
    echo "tail -20 /var/log/letsencrypt/letsencrypt.log"
    echo
    echo "Убедитесь что:"
    echo "1. DNS A-запись $DOMAIN указывает на $(hostname -I | awk '{print $1}')"
    echo "2. Порт 80 открыт: ufw allow 80/tcp"
    echo "3. Домен доступен: ping $DOMAIN"
    
    exit 1
fi
