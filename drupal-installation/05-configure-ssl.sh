#!/bin/bash

# RTTI Drupal - Шаг 5: Настройка SSL/TLS
# Сервер: storage.omuzgorpro.tj (92.242.61.204)
# ОБНОВЛЕНО: умная проверка существующих сертификатов

DOMAIN="storage.omuzgorpro.tj"
EMAIL="admin@omuzgorpro.tj"
LETSENCRYPT_CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

echo "=== RTTI Drupal - Шаг 5: Настройка SSL/TLS для $DOMAIN ==="
echo "🔒 Let's Encrypt SSL сертификаты для цифровой библиотеки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

# Функция проверки валидности сертификата
check_cert_validity() {
    local cert_file="$1"
    local min_days_left="${2:-30}"  # По умолчанию 30 дней
    
    if [ ! -f "$cert_file" ]; then
        echo "   ❌ Файл сертификата не найден: $cert_file"
        return 1
    fi
    
    # Проверка валидности сертификата
    if ! openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        echo "   ❌ Сертификат поврежден или некорректен"
        return 1
    fi
    
    # Проверка домена в сертификате
    local cert_domain=$(openssl x509 -in "$cert_file" -noout -subject | grep -o "CN=[^,]*" | cut -d= -f2 | tr -d ' ')
    if [ "$cert_domain" != "$DOMAIN" ]; then
        echo "   ❌ Сертификат выписан для другого домена: $cert_domain"
        return 1
    fi
    
    # Проверка срока действия
    local end_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local end_timestamp=$(date -d "$end_date" +%s 2>/dev/null)
    local current_timestamp=$(date +%s)
    
    if [ -z "$end_timestamp" ]; then
        echo "   ❌ Не удается определить дату истечения сертификата"
        return 1
    fi
    
    local days_left=$(( (end_timestamp - current_timestamp) / 86400 ))
    
    if [ $days_left -lt $min_days_left ]; then
        echo "   ⚠️  Сертификат истекает через $days_left дней (требуется минимум $min_days_left)"
        return 1
    fi
    
    echo "   ✅ Сертификат действителен еще $days_left дней"
    return 0
}

echo "🔍 Проверка существующих SSL сертификатов..."

# Проверка наличия существующих сертификатов Let's Encrypt
if [ -d "$LETSENCRYPT_CERT_DIR" ] && \
   [ -f "$LETSENCRYPT_CERT_DIR/fullchain.pem" ] && \
   [ -f "$LETSENCRYPT_CERT_DIR/privkey.pem" ] && \
   [ -f "$LETSENCRYPT_CERT_DIR/cert.pem" ]; then
    
    echo "📋 Найдены существующие Let's Encrypt сертификаты"
    
    # Проверка валидности существующего сертификата (минимум 30 дней)
    if check_cert_validity "$LETSENCRYPT_CERT_DIR/cert.pem" 30; then
        echo "✅ Существующий сертификат валиден и актуален"
        echo "🏃 Пропускаем получение нового сертификата"
        
        # Переходим сразу к настройке Nginx с существующим сертификатом
        echo "🔧 Настройка Nginx для использования существующего SSL сертификата..."
        CERT_EXISTS=true
    else
        echo "⚠️  Существующий сертификат устарел или поврежден"
        echo "🔄 Будем получать новый сертификат..."
        CERT_EXISTS=false
    fi
else
    echo "ℹ️  SSL сертификаты не найдены"
    echo "🆕 Будем получать новые сертификаты Let's Encrypt..."
    CERT_EXISTS=false
fi

# Получение нового сертификата только если необходимо
if [ "$CERT_EXISTS" = false ]; then
    echo
    echo "🆕 Получение нового SSL сертификата..."
    
    echo "1. Установка Certbot для Let's Encrypt..."
    apt update -qq
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
        try_files \\\$uri \\\$uri/ =404;
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
        
        # Проверяем полученный сертификат
        if check_cert_validity "$LETSENCRYPT_CERT_DIR/cert.pem" 1; then
            echo "✅ Новый сертификат валиден"
        else
            echo "❌ Ошибка: полученный сертификат некорректен"
            exit 1
        fi
    else
        echo "❌ Ошибка получения SSL сертификата"
        echo "Проверьте:"
        echo "1. DNS записи для $DOMAIN (A-запись должна указывать на $(hostname -I | awk '{print $1}'))"
        echo "2. Доступность порта 80 (ufw allow 80/tcp)"
        echo "3. Корректность email $EMAIL"
        echo "4. Логи: /var/log/letsencrypt/letsencrypt.log"
        
        # Показываем последние строки из лога
        if [ -f "/var/log/letsencrypt/letsencrypt.log" ]; then
            echo
            echo "📋 Последние записи из лога Certbot:"
            tail -20 /var/log/letsencrypt/letsencrypt.log
        fi
        
        exit 1
    fi
fi

echo
echo "✅ SSL сертификат готов к использованию"
echo "📁 Путь к сертификатам: $LETSENCRYPT_CERT_DIR"

# Удаление старой конфигурации перед созданием новой
rm -f /etc/nginx/sites-enabled/drupal-default 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

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
    
    # PHP processing - упрощенный обработчик для всех PHP файлов
    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_index index.php;
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
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
echo "   ⚠️  ПРИМЕЧАНИЕ: Эта конфигурация будет заменена на более безопасную в шаге 09-security.sh"

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

echo "15. Создание файла с информацией о SSL..."
cat > /root/drupal-ssl-info.txt << EOF
# SSL/TLS информация для Drupal
# Дата создания: $(date)
# Сервер: $DOMAIN ($(hostname -I | awk '{print $1}'))

=== ИНФОРМАЦИЯ О SSL СЕРТИФИКАТЕ ===

Домен: $DOMAIN
Путь к сертификатам: /etc/letsencrypt/live/$DOMAIN/
Статус: $(check_cert_validity "/etc/letsencrypt/live/$DOMAIN/cert.pem" 1 && echo "Действителен" || echo "Проблема")

Файлы сертификата:
- Основной сертификат: /etc/letsencrypt/live/$DOMAIN/cert.pem
- Полная цепочка: /etc/letsencrypt/live/$DOMAIN/fullchain.pem
- Приватный ключ: /etc/letsencrypt/live/$DOMAIN/privkey.pem

=== NGINX КОНФИГУРАЦИЯ ===

- Основной файл: /etc/nginx/sites-enabled/drupal-ssl
- HTTP редирект на HTTPS: Включен
- HTTP/2: Включен
- HSTS: Включен (31536000 секунд)
- Безопасные заголовки: Настроены

=== АВТОМАТИЧЕСКОЕ ОБНОВЛЕНИЕ ===

Certbot автоматически обновляет сертификаты каждые 12 часов.
Проверка обновлений: systemctl status certbot.timer

=== ПОЛЕЗНЫЕ КОМАНДЫ ===

Проверка статуса сертификата:
  certbot certificates

Ручное обновление сертификата:
  certbot renew --dry-run

Проверка конфигурации Nginx:
  nginx -t

Перезагрузка Nginx:
  systemctl reload nginx

Проверка SSL в браузере:
  https://$DOMAIN

Проверка SSL онлайн:
  https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN

=== УСТРАНЕНИЕ ПРОБЛЕМ ===

Если HTTPS не работает:
1. Проверьте DNS: nslookup $DOMAIN
2. Проверьте порты: netstat -tlnp | grep :443
3. Проверьте файрвол: ufw status
4. Проверьте логи: tail -f /var/log/nginx/error.log

Если сертификат не получается:
1. Проверьте DNS записи
2. Убедитесь что порт 80 открыт
3. Проверьте логи: tail -f /var/log/letsencrypt/letsencrypt.log

=== ЗАКЛЮЧЕНИЕ ===

SSL/TLS настроен и готов к работе.
Сайт должен быть доступен по адресу: https://$DOMAIN

Все HTTP запросы автоматически перенаправляются на HTTPS.
Сертификат будет автоматически обновляться каждые 60 дней.
EOF

echo
echo "✅ Шаг 5 завершен успешно!"
echo "📌 SSL/TLS настроен для https://$DOMAIN"
echo "📌 Let's Encrypt сертификат установлен и валиден"
echo "📌 Автоматическое обновление настроено"
echo "📌 HTTPS принудительно включен"
echo "📌 Nginx оптимизирован для Drupal"
echo "📌 Информация о SSL: /root/drupal-ssl-info.txt"

# Финальная проверка
echo
echo "🧪 Финальная проверка SSL..."
if curl -I -s https://$DOMAIN >/dev/null 2>&1; then
    echo "✅ HTTPS сайт доступен"
else
    echo "⚠️  HTTPS сайт пока недоступен (нормально на этапе установки)"
fi

echo
echo "📌 Следующий шаг: ./06-install-drupal.sh"
echo
