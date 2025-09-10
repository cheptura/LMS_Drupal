#!/bin/bash

# RTTI Moodle - Шаг 10: Настройка безопасности
# Сервер: omuzgorpro.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 10: Углубленная настройка безопасности ==="
echo "🛡️ Комплексная защита системы и данных"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

MOODLE_DIR="/var/www/moodle"
NGINX_DIR="/etc/nginx"
PHP_VERSION="8.3"

echo "1. Установка и настройка Fail2Ban..."

# Установка Fail2Ban
apt update && apt install -y fail2ban

# Конфигурация Fail2Ban для Moodle
cat > /etc/fail2ban/jail.d/nginx-moodle.conf << EOF
# Fail2Ban конфигурация для Moodle LMS
# Дата: $(date)

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
logpath = /var/log/nginx/access.log
maxretry = 6
bantime = 86400
findtime = 60
filter = nginx-noscript

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400
findtime = 600
filter = nginx-badbots

[nginx-noproxy]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400
findtime = 600
filter = nginx-noproxy

[moodle-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 3600
findtime = 600
filter = moodle-auth

[ssh]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

# Фильтр для Moodle аутентификации
cat > /etc/fail2ban/filter.d/moodle-auth.conf << EOF
# Fail2Ban фильтр для Moodle
[Definition]
failregex = <HOST> .* "POST /login/index.php HTTP.*" 200
            <HOST> .* "POST /admin/.* HTTP.*" 403
            <HOST> .* "GET /admin/.* HTTP.*" 403
            <HOST> .* "POST /user/edit.php HTTP.*" 403
ignoreregex =
EOF

echo "2. Настройка автоматических обновлений безопасности..."
apt install -y unattended-upgrades

# Конфигурация автоматических обновлений
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "admin@omuzgorpro.tj";
EOF

# Включение автоматических обновлений
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

echo "3. Настройка расширенной безопасности Nginx..."

# Удаляем старые файлы конфигурации, которые могут содержать устаревшие директивы
echo "   Удаление устаревших файлов конфигурации..."
rm -f "$NGINX_DIR/conf.d/security-headers.conf" 2>/dev/null || true
rm -f "$NGINX_DIR/conf.d/headers-more.conf" 2>/dev/null || true

# Дополнительные заголовки безопасности
echo "   Создание файла заголовков безопасности..."
cat > "$NGINX_DIR/conf.d/security-headers.conf" << EOF
# Заголовки безопасности для Moodle LMS
# Дата: $(date)

# Основные заголовки безопасности
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

# Content Security Policy для Moodle (с поддержкой YUI)
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline' *.googleapis.com *.gstatic.com; style-src 'self' 'unsafe-inline' *.googleapis.com; img-src 'self' data: *.gravatar.com https:; font-src 'self' *.gstatic.com data:; connect-src 'self'; frame-ancestors 'self'; object-src 'none';" always;

# Строгая транспортная безопасность (HSTS)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Скрытие версии сервера (только стандартные директивы Nginx)
server_tokens off;

# ПРИМЕЧАНИЕ: Директивы типа more_clear_headers требуют модуль nginx-module-headers-more
# Если нужно более продвинутое управление заголовками, установите:
# apt install nginx-module-headers-more
# И добавьте в nginx.conf: load_module modules/ngx_http_headers_more_filter_module.so;
EOF

# Настройка общих параметров безопасности в отдельном файле
cat > "$NGINX_DIR/conf.d/security-general.conf" << EOF
# Общие параметры безопасности для Moodle
# Дата: $(date)

# Ограничение соединений (применяется глобально)
limit_conn_zone \$binary_remote_addr zone=conn_limit_per_ip:10m;

# Размеры буферов и тела запроса
client_max_body_size 512M;
client_body_buffer_size 2M;
client_header_buffer_size 2k;
large_client_header_buffers 4 8k;

# Таймауты безопасности
client_body_timeout 30s;
client_header_timeout 30s;
keepalive_timeout 65s;
send_timeout 30s;
EOF

echo "4. Настройка защиты от DDoS..."

# Добавление rate limiting зон в nginx.conf (если их еще нет)
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    echo "   Добавляем rate limiting зоны в nginx.conf..."
    
    # Создаем резервную копию
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup-$(date +%Y%m%d_%H%M%S)
    
    # Добавляем rate limiting зоны в http блок
    sed -i '/http {/a\\n\t# Rate limiting zones for DDoS protection\n\tlimit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;\n\tlimit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;\n\tlimit_req_zone $binary_remote_addr zone=uploads:10m rate=10r/m;\n\tlimit_conn_zone $binary_remote_addr zone=perip:10m;\n' /etc/nginx/nginx.conf
    
    echo "   ✅ Rate limiting зоны добавлены в nginx.conf"
else
    echo "   ℹ️  Rate limiting зоны уже настроены"
fi

# Определяем файл конфигурации сайта для добавления location блоков
SITE_CONFIG=""
if [ -f /etc/nginx/sites-available/moodle-ssl ]; then
    SITE_CONFIG="/etc/nginx/sites-available/moodle-ssl"
    echo "   🔍 Найдена SSL конфигурация, обновляем её"
elif [ -f /etc/nginx/sites-available/omuzgorpro.tj ]; then
    SITE_CONFIG="/etc/nginx/sites-available/omuzgorpro.tj"
    echo "   🔍 Найдена базовая конфигурация, обновляем её"
elif [ -f /etc/nginx/sites-available/default ]; then
    SITE_CONFIG="/etc/nginx/sites-available/default"
    echo "   🔍 Найдена стандартная конфигурация, обновляем её"
else
    echo "   ⚠️  Конфигурация Nginx не найдена, создаём новую защищённую"
fi

# Добавляем DDoS защиту в server блок, если её еще нет и файл найден
if [ -n "$SITE_CONFIG" ] && ! grep -q "limit_req zone=login" "$SITE_CONFIG"; then
    echo "   Добавляем DDoS защиту в конфигурацию сайта: $SITE_CONFIG"
    
    # Создаем резервную копию
    cp "$SITE_CONFIG" "${SITE_CONFIG}.backup-$(date +%Y%m%d_%H%M%S)"
    
    # Добавляем location блоки перед закрывающей скобкой server блока
    sed -i '/^}$/i\    # DDoS Protection - Rate Limiting\
    location = /login/index.php {\
        limit_req zone=login burst=3 nodelay;\
        limit_req_status 429;\
        fastcgi_split_path_info ^(.+\.php)(/.+)$;\
        fastcgi_index index.php;\
        fastcgi_pass unix:/var/run/php/php'"$PHP_VERSION"'-fpm.sock;\
        include fastcgi_params;\
        fastcgi_param PATH_INFO $fastcgi_path_info;\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\
        fastcgi_read_timeout 300;\
    }\
\
    location ~ ^/admin/.*\.php(/|$) {\
        limit_req zone=api burst=5 nodelay;\
        limit_req_status 429;\
        fastcgi_split_path_info ^(.+\.php)(/.+)$;\
        fastcgi_index index.php;\
        fastcgi_pass unix:/var/run/php/php'"$PHP_VERSION"'-fpm.sock;\
        include fastcgi_params;\
        fastcgi_param PATH_INFO $fastcgi_path_info;\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\
        fastcgi_read_timeout 300;\
    }\
\
    location ~ ^/repository/.*\.php(/|$) {\
        limit_req zone=uploads burst=5 nodelay;\
        limit_req_status 429;\
        fastcgi_split_path_info ^(.+\.php)(/.+)$;\
        fastcgi_index index.php;\
        fastcgi_pass unix:/var/run/php/php'"$PHP_VERSION"'-fpm.sock;\
        include fastcgi_params;\
        fastcgi_param PATH_INFO $fastcgi_path_info;\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\
        fastcgi_read_timeout 300;\
    }\
\
    # Connection limiting\
    limit_conn perip 25;' "$SITE_CONFIG"
    
    echo "   ✅ DDoS защита добавлена в конфигурацию сайта"
else
    echo "   ℹ️  DDoS защита уже настроена или файл конфигурации не найден"
fi

echo "5. Настройка защищенности PHP..."

# Дополнительная настройка PHP для безопасности
cat >> "/etc/php/$PHP_VERSION/fpm/conf.d/99-security.ini" << EOF
; Дополнительные настройки безопасности PHP для Moodle
; Дата: $(date)

; Отключение опасных функций (ИСКЛЮЧЕНЫ curl_exec и curl_multi_exec для Moodle)
; curl_exec и curl_multi_exec НЕОБХОДИМЫ для:
; - Загрузки языковых пакетов
; - Обновлений Moodle
; - Веб-сервисов и внешних интеграций
; - Работы с внешними репозиториями
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,parse_ini_file,show_source

; Скрытие версии PHP
expose_php = Off

; Логирование ошибок без показа пользователю
display_errors = Off
log_errors = On
error_log = /var/log/php_errors.log

; Ограничения для файловых операций
allow_url_fopen = Off
allow_url_include = Off

; Ограничения времени выполнения
max_execution_time = 300
max_input_time = 300
memory_limit = 512M

; Ограничения загрузки файлов
file_uploads = On
upload_max_filesize = 512M
post_max_size = 512M
max_file_uploads = 20
EOF

echo "6. Настройка мониторинга безопасности..."

# Создание скрипта мониторинга
cat > /usr/local/bin/moodle-security-check.sh << 'EOF'
#!/bin/bash
# Скрипт мониторинга безопасности Moodle

LOG_FILE="/var/log/moodle-security.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] === Проверка безопасности Moodle ===" >> $LOG_FILE

# Проверка активных подключений
ACTIVE_CONN=$(netstat -an | grep :80 | grep ESTABLISHED | wc -l)
if [ $ACTIVE_CONN -gt 100 ]; then
    echo "[$DATE] ПРЕДУПРЕЖДЕНИЕ: Много активных соединений ($ACTIVE_CONN)" >> $LOG_FILE
fi

# Проверка логов на подозрительную активность
SUSPICIOUS=$(tail -n 1000 /var/log/nginx/access.log | grep -c "POST.*login")
if [ $SUSPICIOUS -gt 50 ]; then
    echo "[$DATE] ПРЕДУПРЕЖДЕНИЕ: Подозрительная активность входа ($SUSPICIOUS попыток)" >> $LOG_FILE
fi

# Проверка дискового пространства
DISK_USAGE=$(df /var/www/moodle | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "[$DATE] ПРЕДУПРЕЖДЕНИЕ: Мало места на диске ($DISK_USAGE%)" >> $LOG_FILE
fi

# Проверка процессов PHP
PHP_PROC=$(ps aux | grep php-fpm | grep -v grep | wc -l)
if [ $PHP_PROC -lt 3 ]; then
    echo "[$DATE] ПРЕДУПРЕЖДЕНИЕ: Мало процессов PHP-FPM ($PHP_PROC)" >> $LOG_FILE
fi
EOF

chmod +x /usr/local/bin/moodle-security-check.sh

# Добавление в cron
echo "*/15 * * * * root /usr/local/bin/moodle-security-check.sh" > /etc/cron.d/moodle-security

echo "7. Настройка логирования..."

# Проверяем, есть ли уже log_format в nginx.conf
if grep -q "log_format security" /etc/nginx/nginx.conf; then
    echo "   ℹ️  Log format уже настроен в nginx.conf"
else
    echo "   Добавляем log format в http блок nginx.conf..."
    
    # Создаем резервную копию
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup-logging-$(date +%Y%m%d_%H%M%S)
    
    # Добавляем log_format в http блок (после других директив)
    sed -i '/http {/a\\n\t# Security logging format\n\tlog_format security '"'"'$remote_addr - $remote_user [$time_local] '"'"'\n\t                   '"'"'"$request" $status $body_bytes_sent '"'"'\n\t                   '"'"'"$http_referer" "$http_user_agent" '"'"'\n\t                   '"'"'"$http_x_forwarded_for" rt=$request_time '"'"'\n\t                   '"'"'ua="$upstream_addr" us="$upstream_status" '"'"'\n\t                   '"'"'ut="$upstream_response_time"'"'"';\n' /etc/nginx/nginx.conf
    
    echo "   ✅ Log format добавлен в nginx.conf"
fi

# Создаем отдельный файл для security access log
cat > "$NGINX_DIR/conf.d/security-logging.conf" << 'EOF'
# Security logging configuration
# Дата: $(date)

# Логирование безопасности (использует log_format security из nginx.conf)
access_log /var/log/nginx/security.log security;
EOF

echo "8. Запуск и включение служб безопасности..."

# Запуск Fail2Ban
systemctl enable fail2ban
systemctl start fail2ban

# Включение автоматических обновлений
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Активация обновленной конфигурации, если она была изменена
if [ -n "$SITE_CONFIG" ]; then
    # Определяем имя файла для активации
    CONFIG_NAME=$(basename "$SITE_CONFIG")
    echo "   🔄 Активация обновленной конфигурации: $CONFIG_NAME"
    
    # Удаляем старые активные конфигурации
    rm -f /etc/nginx/sites-enabled/omuzgorpro.tj 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/moodle-ssl 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    # Активируем обновленную конфигурацию
    ln -sf "$SITE_CONFIG" "/etc/nginx/sites-enabled/"
    echo "   ✅ Конфигурация $CONFIG_NAME активирована"
fi

# Перезапуск Nginx с новыми настройками
echo "   Проверка конфигурации Nginx..."
if nginx -t; then
    echo "   ✅ Конфигурация Nginx корректна"
    systemctl reload nginx
    echo "   ✅ Nginx перезагружен"
else
    echo "   ❌ ОШИБКА в конфигурации Nginx!"
    echo "   🔧 Откатываем изменения..."
    
    # Откатываем изменения в nginx.conf
    if [ -f "/etc/nginx/nginx.conf.backup-logging-$(date +%Y%m%d)_"* ]; then
        LATEST_BACKUP=$(ls -t /etc/nginx/nginx.conf.backup-logging-$(date +%Y%m%d)_* | head -1)
        cp "$LATEST_BACKUP" /etc/nginx/nginx.conf
        echo "   ↩️  nginx.conf восстановлен из: $LATEST_BACKUP"
    fi
    
    # Удаляем проблемные конфигурации
    rm -f "$NGINX_DIR/conf.d/security-logging.conf"
    
    # Пробуем еще раз
    if nginx -t; then
        echo "   ✅ Конфигурация исправлена"
        systemctl reload nginx
    else
        echo "   ❌ Конфигурация все еще содержит ошибки"
        echo "   📋 Вывод nginx -t:"
        nginx -t
        echo "   ⚠️  Пропускаем перезагрузку Nginx"
    fi
fi

# Перезапуск PHP-FPM
systemctl restart php$PHP_VERSION-fpm

echo "9. Создание резервной копии конфигураций..."
mkdir -p /root/security-backup-$(date +%Y%m%d)
cp -r /etc/nginx/conf.d /root/security-backup-$(date +%Y%m%d)/
cp -r /etc/fail2ban /root/security-backup-$(date +%Y%m%d)/
cp /etc/php/$PHP_VERSION/fpm/conf.d/99-security.ini /root/security-backup-$(date +%Y%m%d)/

echo "10. Финальная проверка..."

# Проверка статуса служб
echo "Статус Fail2Ban:"
systemctl status fail2ban --no-pager -l

echo "Активные правила Fail2Ban:"
fail2ban-client status

echo "Статус файрвола:"
ufw status verbose

echo "Статус автоматических обновлений:"
systemctl status unattended-upgrades --no-pager -l

echo
echo "✅ Настройка безопасности завершена успешно!"
echo
echo "🛡️ УСТАНОВЛЕННЫЕ МЕРЫ ЗАЩИТЫ:"
echo "├── Fail2Ban: защита от атак перебора"
echo "├── UFW Firewall: базовая защита портов"
echo "├── Rate Limiting: защита от DDoS"
echo "├── Security Headers: защита веб-приложения"
echo "├── PHP Hardening: безопасная конфигурация PHP"
echo "├── Автоматические обновления: патчи безопасности"
echo "├── Мониторинг: отслеживание подозрительной активности"
echo "└── Логирование: детальные логи безопасности"
echo
echo "📊 ФАЙЛЫ МОНИТОРИНГА:"
echo "├── Логи безопасности: /var/log/moodle-security.log"
echo "├── Логи Nginx: /var/log/nginx/security.log"
echo "├── Логи Fail2Ban: /var/log/fail2ban.log"
echo "└── Резервные копии: /root/security-backup-$(date +%Y%m%d)/"
echo
echo "🔧 УПРАВЛЕНИЕ:"
echo "├── Статус Fail2Ban: fail2ban-client status"
echo "├── Разблокировка IP: fail2ban-client set [jail] unbanip [ip]"
echo "├── Проверка файрвола: ufw status"
echo "└── Логи безопасности: tail -f /var/log/moodle-security.log"
echo
echo "📌 Следующий шаг: ./11-final-check.sh"
echo
