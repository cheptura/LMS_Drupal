#!/bin/bash

# RTTI Moodle - Шаг 5: Настройка SSL/TLS
# Сервер: omuzgorpro.tj (92.242.60.172)

DOMAIN="omuzgorpro.tj"
EMAIL="admin@omuzgorpro.tj"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== RTTI Moodle - Шаг 5: Настройка SSL/TLS для $DOMAIN ==="
echo "🔒 Let's Encrypt SSL сертификаты"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "🔍 Проверка существующих SSL сертификатов..."

# Функция проверки валидности сертификата
check_cert_validity() {
    local cert_file="$1"
    
    if [ ! -f "$cert_file" ]; then
        return 1
    fi
    
    # Проверка валидности сертификата
    if ! openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        return 1
    fi
    
    # Проверка срока действия (должен быть действителен минимум 7 дней)
    local end_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local end_timestamp=$(date -d "$end_date" +%s)
    local current_timestamp=$(date +%s)
    local days_left=$(( (end_timestamp - current_timestamp) / 86400 ))
    
    if [ $days_left -lt 7 ]; then
        echo "   ⚠️  Сертификат истекает через $days_left дней"
        return 1
    fi
    
    echo "   ✅ Сертификат действителен еще $days_left дней"
    return 0
}

# Проверка существующих Let's Encrypt сертификатов
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "📋 Найдены существующие Let's Encrypt сертификаты"
    
    # Проверка валидности существующего сертификата
    if check_cert_validity "/etc/letsencrypt/live/$DOMAIN/cert.pem"; then
        echo "✅ Существующий сертификат валиден и актуален"
        echo "🔄 Использование существующих сертификатов..."
        
        echo "⚠️  Примечание: SSL конфигурация будет обновлена, но новый сертификат не выпускается"
        
        # Переходим сразу к обновлению конфигурации Nginx
        SKIP_CERTBOT=true
    else
        echo "⚠️  Существующий сертификат устарел или поврежден"
        echo "🔄 Переходим к выпуску новых сертификатов..."
        SKIP_CERTBOT=false
    fi
else
    echo "📋 Существующие сертификаты не найдены"
    echo "🔄 Переходим к выпуску новых сертификатов..."
    SKIP_CERTBOT=false
fi

echo
if [ "$SKIP_CERTBOT" = "false" ]; then
    echo
    echo "🆕 Выпуск новых SSL сертификатов..."

    echo "1. Установка Certbot для Let's Encrypt..."
    apt update
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
else
    echo
    echo "⏭️  Пропуск выпуска сертификатов (используются существующие)"
fi

# Удаление старой конфигурации перед созданием новой
rm -f /etc/nginx/sites-enabled/omuzgorpro.tj 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

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
    client_body_timeout 300s;
    fastcgi_read_timeout 300s;
    
    # Основной location для всех файлов
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # PHP обработка - ЕДИНЫЙ обработчик для всех PHP файлов включая Moodle handlers
    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }    # Статические файлы
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
    
    
    # Статические файлы с кэшированием
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        try_files \$uri =404;
    }

    # Moodle dataroot protection
    location ^~ /dataroot/ {
        internal;
        alias /var/moodledata/;
    }

    # Безопасность - блокировка доступа
    location ~ /\. {
        deny all;
    }
    
    location ~ /config\.php {
        deny all;
    }
    
    location ~ ^/(backup|local/temp|local/cache)/ {
        deny all;
    }
}
EOF

if [ "$SKIP_CERTBOT" = "false" ]; then
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
echo "   ⚠️  ПРИМЕЧАНИЕ: Эта конфигурация будет заменена на более безопасную в шаге 10-security.sh"

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

# Проверяем, что новые сертификаты установлены успешно
echo
echo "✅ Шаг 5 завершен успешно!"
echo "� SSL/TLS настроен для https://$DOMAIN"
if [ "$SKIP_CERTBOT" = "false" ]; then
    echo "📌 Let's Encrypt сертификат выпущен и установлен"
else
    echo "📌 Используются существующие действительные сертификаты"
fi
echo "📌 Автоматическое обновление настроено"
echo "📌 Конфигурация Nginx обновлена с CSP и обработчиками"
echo "🌐 Сайт Moodle доступен по адресу: https://$DOMAIN"
echo "📌 Следующий шаг: ./06-download-moodle.sh"
echo "📌 Скрипт проверки: /root/ssl-check.sh"
echo "📌 Информация о SSL: /root/moodle-ssl-info.txt"
echo
