#!/bin/bash

# RTTI Moodle - Шаг 5: Настройка SSL/TLS
# Сервер: omuzgorpro.tj (92.242.60.172)
# ИСПРАВЛЕНО: убрана поддержка www домена
#
# ✅ ИНТЕГРИРОВАННЫЕ ИСПРАВЛЕНИЯ (2025-09-05):
# - Content Security Policy с 'unsafe-eval' для YUI framework  
# - Обработчики font.php и image.php с PATH_INFO поддержкой
# - Все необходимые JavaScript/CSS handlers для SSL

echo "=== RTTI Moodle - Шаг 5: Настройка SSL/TLS для omuzgorpro.tj ==="
echo "🔒 Let's Encrypt SSL сертификаты"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DOMAIN="omuzgorpro.tj"
EMAIL="admin@omuzgorpro.tj"

echo "1. Установка Certbot для Let's Encrypt..."
apt install -y certbot python3-certbot-nginx

echo "2. Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Ошибка конфигурации Nginx"
    exit 1
fi

echo "3. Проверка доступности домена $DOMAIN..."
ping -c 2 $DOMAIN
if [ $? -ne 0 ]; then
    echo "⚠️  Предупреждение: Домен $DOMAIN недоступен"
    echo "    Убедитесь, что DNS записи настроены правильно"
    echo "    A-запись $DOMAIN должна указывать на $(hostname -I | awk '{print $1}')"
    read -p "Продолжить? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        echo "Прервано пользователем"
        exit 1
    fi
fi

echo "4. Создание SSL конфигурации Nginx с CSP и обработчиками для $DOMAIN..."
cat > /etc/nginx/sites-available/moodle-ssl << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Для проверки Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Перенаправление на HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    root /var/www/moodle;
    index index.php;
    
    # SSL конфигурация (будет добавлена Certbot)
    
    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Размеры загрузки файлов
    client_max_body_size 100M;
    
    # PHP обработка
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
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

    # Moodle JavaScript handler
    location ~ ^/lib/javascript\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$2;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle CSS/theme handler
    location ~ ^/theme/styles\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$2;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle pluginfile handler
    location ~ ^/pluginfile\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Moodle font.php handler
    location ~ ^/font\.php/(.+)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root/font.php;
        fastcgi_param PATH_INFO \$1;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Moodle image.php handler  
    location ~ ^/image\.php/(.+)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root/image.php;
        fastcgi_param PATH_INFO \$1;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }
    
    # Статические файлы
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Дополнительные статические файлы с правильным кэшированием
    location ~* \.(woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        try_files \$uri =404;
    }
    
    # Moodle специфичные настройки
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # Moodle dataroot protection
    location ^~ /dataroot/ {
        internal;
        alias /var/moodledata/;
    }

    # Block access to various Moodle internal paths
    location ~ ^/(backup|local/temp|local/cache)/ {
        deny all;
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

echo "5. Создание временного HTTP сайта для получения сертификата..."
mkdir -p /var/www/html
echo "<!DOCTYPE html><html><head><title>RTTI LMS</title></head><body><h1>RTTI LMS - SSL Setup</h1><p>Настройка SSL...</p></body></html>" > /var/www/html/index.html

# Временная конфигурация только для HTTP
cat > /etc/nginx/sites-available/moodle-temp << EOF
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
ln -sf /etc/nginx/sites-available/moodle-temp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "6. Перезапуск Nginx..."
systemctl reload nginx

echo "7. Получение SSL сертификата от Let's Encrypt..."
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

echo "8. Обновление конфигурации Nginx с SSL..."
# Удаляем временную конфигурацию
rm -f /etc/nginx/sites-enabled/moodle-temp

# Добавляем SSL параметры в основную конфигурацию
sed -i '/# SSL конфигурация (будет добавлена Certbot)/a\
    ssl_certificate /etc/letsencrypt/live/'$DOMAIN'/fullchain.pem;\
    ssl_certificate_key /etc/letsencrypt/live/'$DOMAIN'/privkey.pem;\
    include /etc/letsencrypt/options-ssl-nginx.conf;\
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;' /etc/nginx/sites-available/moodle-ssl

# Активация SSL конфигурации
ln -sf /etc/nginx/sites-available/moodle-ssl /etc/nginx/sites-enabled/

echo "9. Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Ошибка конфигурации Nginx"
    exit 1
fi

echo "10. Перезапуск Nginx..."
systemctl reload nginx

echo "11. Настройка автоматического обновления сертификатов..."
# Создание задачи cron для обновления сертификатов
cat > /etc/cron.d/certbot-renewal << 'EOF'
# Автоматическое обновление Let's Encrypt сертификатов
# Проверка дважды в день
0 12 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
0 0 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
EOF

echo "12. Проверка SSL сертификата..."
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -text -noout | grep -A 3 "Validity"

echo "13. Тестирование HTTPS подключения..."
curl -I https://$DOMAIN 2>/dev/null | head -1
if [ $? -eq 0 ]; then
    echo "✅ HTTPS работает корректно"
else
    echo "⚠️  HTTPS может работать некорректно"
fi

echo "14. Создание скрипта проверки SSL..."
cat > /root/ssl-check.sh << EOF
#!/bin/bash
echo "=== SSL Certificate Status ==="
certbot certificates

echo -e "\n=== Certificate Expiry ==="
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -dates

echo -e "\n=== HTTPS Test ==="
curl -I https://$DOMAIN 2>/dev/null | head -3

echo -e "\n=== SSL Grade Test ==="
echo "Проверьте SSL на: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
EOF

chmod +x /root/ssl-check.sh

echo "15. Настройка файрвола для HTTPS..."
ufw allow 443/tcp comment "HTTPS"
ufw status

echo "16. Создание файла с информацией о SSL..."
cat > /root/moodle-ssl-info.txt << EOF
# SSL/TLS информация для Moodle
# Дата создания: $(date)
# Сервер: omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

Домен: $DOMAIN
SSL сертификат: Let's Encrypt
Путь к сертификату: /etc/letsencrypt/live/$DOMAIN/
Конфигурация Nginx: /etc/nginx/sites-available/moodle-ssl

# Команды для управления:
# Проверка статуса: certbot certificates
# Обновление: certbot renew
# Тест конфигурации: nginx -t
# Перезагрузка: systemctl reload nginx

# Скрипт проверки: /root/ssl-check.sh

# Важно:
# - Сертификат обновляется автоматически через cron
# - Проверяйте лог: /var/log/letsencrypt/letsencrypt.log
# - При смене IP нужно обновить DNS записи
EOF

echo
echo "✅ Шаг 5 завершен успешно!"
echo "📌 SSL/TLS настроен для https://$DOMAIN"
echo "📌 Let's Encrypt сертификат установлен"
echo "📌 Автоматическое обновление настроено"
echo "📌 Конфигурация Nginx обновлена с CSP и обработчиками"
echo "📌 Скрипт проверки: /root/ssl-check.sh"
echo "📌 Информация о SSL: /root/moodle-ssl-info.txt"
echo "📌 Следующий шаг: ./06-download-moodle.sh"
echo
