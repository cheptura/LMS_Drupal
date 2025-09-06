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

# Дополнительные заголовки безопасности
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

# Скрытие версии сервера
server_tokens off;
more_clear_headers Server;
EOF

# Настройка ограничения скорости запросов
cat > "$NGINX_DIR/conf.d/rate-limiting.conf" << EOF
# Ограничение скорости запросов для Moodle
# Дата: $(date)

# Зоны для ограничения по IP
limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone \$binary_remote_addr zone=api:10m rate=30r/m;
limit_req_zone \$binary_remote_addr zone=general:10m rate=200r/m;
limit_req_zone \$binary_remote_addr zone=uploads:10m rate=10r/m;

# Ограничение соединений
limit_conn_zone \$binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn conn_limit_per_ip 25;

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

# Создание конфигурации защиты от DDoS
cat > "$NGINX_DIR/conf.d/ddos-protection.conf" << EOF
# Защита от DDoS атак для Moodle
# Дата: $(date)

# Ограничение количества запросов на страницу логина
location = /login/index.php {
    limit_req zone=login burst=3 nodelay;
    limit_req_status 429;
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
}

# Ограничение для административных страниц
location ~ ^/admin/ {
    limit_req zone=api burst=5 nodelay;
    limit_req_status 429;
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
}

# Ограничение для загрузки файлов
location ~ ^/repository/ {
    limit_req zone=uploads burst=5 nodelay;
    limit_req_status 429;
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
}

# Блокировка подозрительных User-Agent
if (\$http_user_agent ~* (bot|crawler|spider|scraper)) {
    return 403;
}

# Блокировка пустых referer для административных страниц
location ~ ^/(admin|user/edit) {
    if (\$http_referer = "") {
        return 403;
    }
}
EOF

echo "5. Настройка защищенности PHP..."

# Дополнительная настройка PHP для безопасности
cat >> "/etc/php/$PHP_VERSION/fpm/conf.d/99-security.ini" << EOF
; Дополнительные настройки безопасности PHP для Moodle
; Дата: $(date)

; Отключение опасных функций
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source

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

# Настройка логирования Nginx
cat >> "$NGINX_DIR/nginx.conf" << EOF

# Дополнительное логирование безопасности
log_format security '\$remote_addr - \$remote_user [\$time_local] '
                   '"\$request" \$status \$body_bytes_sent '
                   '"\$http_referer" "\$http_user_agent" '
                   '"\$http_x_forwarded_for" rt=\$request_time '
                   'ua="\$upstream_addr" us="\$upstream_status" '
                   'ut="\$upstream_response_time"';

access_log /var/log/nginx/security.log security;
EOF

echo "8. Запуск и включение служб безопасности..."

# Запуск Fail2Ban
systemctl enable fail2ban
systemctl start fail2ban

# Включение автоматических обновлений
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Перезапуск Nginx с новыми настройками
nginx -t && systemctl reload nginx

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
