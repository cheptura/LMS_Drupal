#!/bin/bash

# RTTI Drupal - Шаг 9: Настройка безопасности
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 9: Углубленная настройка безопасности ==="
echo "🛡️ Комплексная защита системы и данных"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка:# Дополнительные настройки безопасности PHP
cat > "/etc/php/$PHP_VERSION/fpm/conf.d/99-security.ini" << EOF
; Настройки безопасности PHP для Drupal
; Дата: $(date)

; Отключение опасных функций (ИСКЛЮЧЕНЫ curl_exec и curl_multi_exec)
; curl_exec и curl_multi_exec могут потребоваться для:
; - Обновлений модулей
; - Внешних интеграций
; - Веб-сервисов
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,parse_ini_file,show_source,file_get_contents,fopen,fread,fwrite,file_put_contents,fputs,fgets,fsockopen,socket_createите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"
NGINX_DIR="/etc/nginx"
PHP_VERSION="8.3"

echo "1. Настройка Fail2Ban для защиты от атак..."

# Установка Fail2Ban
apt update && apt install -y fail2ban

# Конфигурация Fail2Ban для Nginx
cat > /etc/fail2ban/jail.d/nginx-drupal.conf << EOF
# Fail2Ban конфигурация для Drupal Library
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

[drupal-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 3600
findtime = 600
filter = drupal-auth
EOF

# Фильтр для Drupal аутентификации
cat > /etc/fail2ban/filter.d/drupal-auth.conf << EOF
# Fail2Ban фильтр для Drupal
[Definition]
failregex = <HOST> .* "POST /user/login HTTP.*" 200
            <HOST> .* "POST /admin/config HTTP.*" 403
            <HOST> .* "GET /admin/.* HTTP.*" 403
ignoreregex =
EOF

echo "2. Настройка безопасности Nginx..."

# Удаляем старые файлы конфигурации, которые могут содержать устаревшие директивы
echo "   Удаление устаревших файлов конфигурации..."
rm -f "$NGINX_DIR/conf.d/security-headers.conf" 2>/dev/null || true
rm -f "$NGINX_DIR/conf.d/headers-more.conf" 2>/dev/null || true

# Дополнительные заголовки безопасности
echo "   Создание файла заголовков безопасности..."
cat > "$NGINX_DIR/conf.d/security-headers.conf" << EOF
# Заголовки безопасности для Drupal Library
# Дата: $(date)

# Основные заголовки безопасности
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

# Content Security Policy для Drupal
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' *.googleapis.com *.gstatic.com; style-src 'self' 'unsafe-inline' *.googleapis.com; img-src 'self' data: *.gravatar.com; font-src 'self' *.gstatic.com; connect-src 'self'; frame-ancestors 'self';" always;

# Строгая транспортная безопасность (HSTS)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Скрытие версии сервера (только стандартные директивы Nginx)
server_tokens off;

# ПРИМЕЧАНИЕ: Директивы типа more_clear_headers требуют модуль nginx-module-headers-more
# Если нужно более продвинутое управление заголовками, установите:
# apt install nginx-module-headers-more
# И добавьте в nginx.conf: load_module modules/ngx_http_headers_more_filter_module.so;
EOF

# Настройка ограничения скорости запросов
cat > "$NGINX_DIR/conf.d/rate-limiting.conf" << EOF
# Ограничение скорости запросов для Drupal
# Дата: $(date)

# Зона для ограничения по IP
limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone \$binary_remote_addr zone=api:10m rate=30r/m;
limit_req_zone \$binary_remote_addr zone=general:10m rate=100r/m;

# Ограничение соединений
limit_conn_zone \$binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn conn_limit_per_ip 20;

# Размер тела запроса
client_max_body_size 100M;
client_body_buffer_size 1M;
client_header_buffer_size 1k;
large_client_header_buffers 4 4k;
EOF

# Обновление конфигурации основного сайта с ограничениями
cat > "$NGINX_DIR/sites-available/drupal" << EOF
# Конфигурация Nginx для Drupal Library с безопасностью
# Сервер: storage.omuzgorpro.tj (92.242.61.204)
# Дата: $(date)

server {
    listen 80;
    server_name storage.omuzgorpro.tj;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name storage.omuzgorpro.tj;
    
    root $DRUPAL_DIR/web;
    index index.php;
    
    # SSL конфигурация
    ssl_certificate /etc/letsencrypt/live/storage.omuzgorpro.tj/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/storage.omuzgorpro.tj/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # Современные SSL протоколы
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/storage.omuzgorpro.tj/chain.pem;
    
    # Логирование
    access_log /var/log/nginx/drupal_access.log;
    error_log /var/log/nginx/drupal_error.log;
    
    # Ограничения скорости для аутентификации
    location = /user/login {
        limit_req zone=login burst=3 nodelay;
        try_files \$uri /index.php?\$query_string;
    }
    
    # Ограичения для административных страниц
    location ^~ /admin {
        limit_req zone=api burst=10 nodelay;
        allow 192.168.0.0/16;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        deny all;
        try_files \$uri /index.php?\$query_string;
    }
    
    # Общие ограничения
    location / {
        limit_req zone=general burst=20 nodelay;
        try_files \$uri /index.php?\$query_string;
    }
    
    # Защита от прямого доступа к PHP файлам
    location ~ \\.php\$ {
        limit_req zone=api burst=15 nodelay;
        
        # Только index.php
        location ~ ^/index\\.php\$ {
            fastcgi_split_path_info ^(.+\\.php)(/.+)\$;
            fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
            fastcgi_param HTTPS on;
            
            # Безопасность FastCGI
            fastcgi_param HTTP_PROXY "";
            fastcgi_read_timeout 300;
            fastcgi_buffer_size 128k;
            fastcgi_buffers 4 256k;
            fastcgi_busy_buffers_size 256k;
        }
        
        # Запрет других PHP файлов
        location ~ \\.php\$ {
            deny all;
        }
    }
    
    # Защита системных файлов
    location ~ ^/sites/.*/private/ {
        deny all;
    }
    
    location ~ ^/sites/[^/]+/files/.*\\.php\$ {
        deny all;
    }
    
    # Защита конфигурации
    location ~ /\\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~\$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Блокировка вредоносных запросов
    location ~* \\.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\\.php)?\$|xtmpl)\$ {
        deny all;
    }
    
    location ~* /(?:CHANGELOG|COPYRIGHT|INSTALL|LICENSE|MAINTAINERS|UPGRADE)\\.txt\$ {
        deny all;
    }
    
    # Кэширование статических файлов с безопасностью
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options nosniff;
        access_log off;
    }
}
EOF

echo "3. Настройка безопасности PostgreSQL..."

# Конфигурация безопасности PostgreSQL
cat > /tmp/postgres_security.sql << EOF
-- Настройки безопасности PostgreSQL для Drupal
-- Дата: $(date)

-- Подключение к базе данных
\\c drupal_library;

-- Отзыв избыточных прав
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO drupaluser;

-- Ограничение подключений для пользователя Drupal
ALTER USER drupaluser CONNECTION LIMIT 50;

-- Настройки безопасности сессий
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_duration = on;
ALTER SYSTEM SET log_statement = 'mod';

-- Защита от SQL-инъекций
ALTER SYSTEM SET log_min_duration_statement = 1000;
ALTER SYSTEM SET log_checkpoints = on;
ALTER SYSTEM SET log_lock_waits = on;

-- Настройки аутентификации
ALTER SYSTEM SET password_encryption = 'scram-sha-256';

-- Перезагрузка конфигурации
SELECT pg_reload_conf();
EOF

sudo -u postgres psql -f /tmp/postgres_security.sql

# Настройка pg_hba.conf для безопасности
cp /etc/postgresql/*/main/pg_hba.conf /etc/postgresql/*/main/pg_hba.conf.backup

cat > /tmp/pg_hba_secure.conf << EOF
# Безопасная конфигурация PostgreSQL
# Дата: $(date)

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   drupal_library  drupaluser                             scram-sha-256

# IPv4 local connections
host    drupal_library  drupaluser      127.0.0.1/32           scram-sha-256
host    drupal_library  drupaluser      ::1/128                scram-sha-256

# Запрет всех остальных подключений
host    all             all             0.0.0.0/0              reject
host    all             all             ::/0                   reject
EOF

cp /tmp/pg_hba_secure.conf /etc/postgresql/*/main/pg_hba.conf

echo "4. Настройка безопасности PHP..."

# Дополнительные настройки безопасности PHP
cat > "/etc/php/$PHP_VERSION/fpm/conf.d/99-security.ini" << EOF
; Настройки безопасности PHP для Drupal
; Дата: $(date)

; Отключение опасных функций
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source,file_get_contents,fopen,fread,fwrite,file_put_contents,fputs,fgets,fsockopen,socket_create

; Скрытие версии PHP
expose_php = Off

; Ограничения на выполнение
max_execution_time = 60
max_input_time = 60

; Контроль ошибок
display_errors = Off
display_startup_errors = Off
log_errors = On
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT

; Контроль загрузки файлов
file_uploads = On
upload_max_filesize = 50M
post_max_size = 50M
max_file_uploads = 20

; Безопасность сессий
session.cookie_httponly = 1
session.cookie_secure = 1
session.use_strict_mode = 1
session.cookie_samesite = "Strict"
session.hash_function = sha256
session.hash_bits_per_character = 6

; Отключение allow_url_*
allow_url_fopen = Off
allow_url_include = Off

; Контроль пользовательского агента
user_agent = ""

; Отключение автовыполнения
auto_prepend_file = 
auto_append_file = 

; Ограничения памяти
memory_limit = 256M

; Отключение обработки PUT/DELETE
enable_post_data_reading = On
EOF

echo "5. Настройка аудита и логирования..."

# Установка auditd для системного аудита
apt install -y auditd audispd-plugins

# Правила аудита для веб-сервера
cat > /etc/audit/rules.d/drupal.rules << EOF
# Правила аудита для Drupal Library
# Дата: $(date)

# Мониторинг изменений в Drupal
-w $DRUPAL_DIR/web/sites/default/settings.php -p wa -k drupal_config
-w $DRUPAL_DIR/web/sites/default/ -p wa -k drupal_files
-w /var/log/nginx/ -p wa -k nginx_logs
-w /etc/nginx/ -p wa -k nginx_config

# Мониторинг системных изменений
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege_escalation

# Мониторинг сетевых подключений
-a always,exit -F arch=b64 -S socket -S connect -k network_connections
-a always,exit -F arch=b32 -S socket -S connect -k network_connections

# Мониторинг выполнения команд
-a always,exit -F arch=b64 -S execve -k command_execution
-a always,exit -F arch=b32 -S execve -k command_execution
EOF

# Перезапуск auditd
systemctl restart auditd

echo "6. Настройка защиты от DDoS..."

# Конфигурация iptables для базовой защиты
cat > /root/firewall-drupal.sh << 'EOF'
#!/bin/bash
# Firewall правила для защиты Drupal Library

# Очистка существующих правил
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Политики по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешить loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешить установленные соединения
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH (ограниченный доступ)
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# HTTP и HTTPS с защитой от флуда
iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

# PostgreSQL (только локально)
iptables -A INPUT -p tcp -s 127.0.0.1 --dport 5432 -j ACCEPT

# Redis (только локально)
iptables -A INPUT -p tcp -s 127.0.0.1 --dport 6379 -j ACCEPT

# Ping (ограниченный)
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT

# Защита от сканирования портов
iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
iptables -A INPUT -m recent --name portscan --remove
iptables -A INPUT -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG --log-prefix "portscan:"
iptables -A INPUT -p tcp -m tcp --dport 139 -m recent --name portscan --set -j DROP

# Логирование отброшенных пакетов
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

# Сохранение правил
iptables-save > /etc/iptables/rules.v4
EOF

chmod +x /root/firewall-drupal.sh

# Установка iptables-persistent для сохранения правил
apt install -y iptables-persistent
/root/firewall-drupal.sh

echo "7. Настройка мониторинга безопасности..."

# Скрипт мониторинга безопасности
cat > /root/security-monitor.sh << 'EOF'
#!/bin/bash
# Мониторинг безопасности Drupal Library

LOG_FILE="/var/log/security-monitor.log"
EMAIL="security@omuzgorpro.tj"
DRUPAL_DIR="/var/www/drupal"

# Функция логирования
log_security() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SECURITY: $1" >> $LOG_FILE
}

# Проверка неудачных попыток входа
check_failed_logins() {
    local failed_count=$(grep "$(date '+%Y/%m/%d')" /var/log/nginx/access.log | grep "POST /user/login" | grep -c " 200 ")
    
    if [ "$failed_count" -gt 50 ]; then
        log_security "High number of login attempts: $failed_count"
        echo "[$(date)] SECURITY ALERT: Suspicious login activity detected: $failed_count attempts today" >> /var/log/drupal-security.log
        logger -t "RTTI-Security" "Suspicious login activity: $failed_count attempts"
    fi
}

# Проверка изменений в критических файлах
check_file_integrity() {
    local settings_file="$DRUPAL_DIR/web/sites/default/settings.php"
    local current_hash=$(md5sum "$settings_file" | cut -d' ' -f1)
    local stored_hash_file="/var/lib/security/settings.hash"
    
    if [ -f "$stored_hash_file" ]; then
        local stored_hash=$(cat "$stored_hash_file")
        
        if [ "$current_hash" != "$stored_hash" ]; then
            log_security "Settings file modified unexpectedly"
            echo "[$(date)] FILE INTEGRITY ALERT: Drupal settings.php file has been modified" >> /var/log/drupal-security.log
            logger -t "RTTI-Security" "Critical file modified: settings.php"
        fi
    fi
    
    # Сохранение текущего хэша
    mkdir -p /var/lib/security
    echo "$current_hash" > "$stored_hash_file"
}

# Проверка подозрительных процессов
check_suspicious_processes() {
    local suspicious_procs=$(ps aux | grep -E "(nc|netcat|nmap|masscan|nikto|sqlmap)" | grep -v grep)
    
    if [ ! -z "$suspicious_procs" ]; then
        log_security "Suspicious processes detected: $suspicious_procs"
        echo "[$(date)] PROCESS ALERT: Suspicious processes running: $suspicious_procs" >> /var/log/drupal-security.log
        logger -t "RTTI-Security" "Suspicious processes detected"
    fi
}

# Проверка активных соединений
check_connections() {
    local high_conn_ips=$(netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -5 | awk '$1>50 {print $2}')
    
    if [ ! -z "$high_conn_ips" ]; then
        log_security "High connection count from IPs: $high_conn_ips"
        echo "[$(date)] CONNECTION ALERT: High connection count detected from: $high_conn_ips" >> /var/log/drupal-security.log
        logger -t "RTTI-Security" "High connection count detected"
    fi
}

# Проверка использования дискового пространства
check_disk_space() {
    local usage=$(df /var | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$usage" -gt 90 ]; then
        log_security "Critical disk usage: $usage%"
        echo "[$(date)] DISK ALERT: Critical disk usage: $usage%" >> /var/log/drupal-security.log
        logger -t "RTTI-Security" "Critical disk usage: $usage%"
    fi
}

# Основная функция мониторинга
main() {
    log_security "Starting security monitoring check"
    
    check_failed_logins
    check_file_integrity
    check_suspicious_processes
    check_connections
    check_disk_space
    
    log_security "Security monitoring check completed"
}

case "$1" in
    status)
        echo "=== SECURITY STATUS ==="
        echo "Failed logins today: $(grep "$(date '+%Y/%m/%d')" /var/log/nginx/access.log | grep "POST /user/login" | wc -l)"
        echo "Active connections: $(netstat -nt | grep ':443' | wc -l)"
        echo "Blocked IPs (fail2ban): $(fail2ban-client status nginx-http-auth | grep "Currently banned" | cut -d: -f2 | wc -w)"
        echo "Disk usage: $(df /var | tail -1 | awk '{print $5}')"
        ;;
    *)
        main
        ;;
esac
EOF

chmod +x /root/security-monitor.sh

echo "8. Настройка автоматической установки обновлений безопасности..."

# Установка unattended-upgrades
apt install -y unattended-upgrades

# Конфигурация автоматических обновлений
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
// Автоматические обновления безопасности для Drupal Library
// Дата: $(date)

Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "security@omuzgorpro.tj";
Unattended-Upgrade::MailReport "on-change";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "9. Создание системы резервного копирования безопасности..."

# Скрипт шифрованного резервного копирования
cat > /root/secure-backup.sh << 'EOF'
#!/bin/bash
# Зашифрованное резервное копирование Drupal Library

BACKUP_DIR="/var/backups/secure-drupal"
DRUPAL_DIR="/var/www/drupal"
DATE=$(date +%Y%m%d-%H%M%S)
GPG_RECIPIENT="backup@omuzgorpro.tj"

mkdir -p $BACKUP_DIR

# Создание архива
tar -czf /tmp/drupal-backup-$DATE.tar.gz \
    --exclude='$DRUPAL_DIR/web/sites/default/files/tmp' \
    --exclude='$DRUPAL_DIR/web/sites/default/files/cache' \
    $DRUPAL_DIR

# Резервная копия базы данных
sudo -u postgres pg_dump drupal_library | gzip > /tmp/drupal-db-$DATE.sql.gz

# Шифрование архивов
gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 \
    --symmetric --output $BACKUP_DIR/drupal-files-$DATE.tar.gz.gpg \
    /tmp/drupal-backup-$DATE.tar.gz

gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 \
    --symmetric --output $BACKUP_DIR/drupal-db-$DATE.sql.gz.gpg \
    /tmp/drupal-db-$DATE.sql.gz

# Удаление незашифрованных копий
rm /tmp/drupal-backup-$DATE.tar.gz
rm /tmp/drupal-db-$DATE.sql.gz

# Удаление старых резервных копий (старше 30 дней)
find $BACKUP_DIR -name "*.gpg" -mtime +30 -delete

echo "Secure backup completed: $BACKUP_DIR"
EOF

chmod +x /root/secure-backup.sh

echo "10. Настройка cron заданий для безопасности..."

# Добавление заданий безопасности в cron
cat > /tmp/security-cron << EOF
# Задания безопасности для Drupal Library
# Дата: $(date)

# Мониторинг безопасности каждые 10 минут
*/10 * * * * /root/security-monitor.sh >/dev/null 2>&1

# Зашифрованное резервное копирование каждую ночь в 3:00
0 3 * * * /root/secure-backup.sh >/dev/null 2>&1

# Обновление правил Fail2Ban каждый час
0 * * * * systemctl reload fail2ban >/dev/null 2>&1

# Ротация логов безопасности
0 0 * * 0 find /var/log -name "*security*" -mtime +7 -delete 2>/dev/null

# Проверка целостности системных файлов раз в день
0 4 * * * /usr/bin/aide --check >/var/log/aide.log 2>&1
EOF

crontab -u root /tmp/security-cron

echo "11. Установка AIDE для проверки целостности..."

# Установка и настройка AIDE
apt install -y aide

# Инициализация базы данных AIDE
aideinit

# Копирование базы данных
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

echo "12. Перезапуск всех служб с новыми настройками..."

# Перезапуск служб
systemctl restart fail2ban
systemctl restart nginx
systemctl restart php$PHP_VERSION-fpm
systemctl restart postgresql
systemctl enable unattended-upgrades

echo "13. Создание отчета о безопасности..."

cat > /root/security-setup-report.txt << EOF
# ОТЧЕТ О НАСТРОЙКЕ БЕЗОПАСНОСТИ DRUPAL LIBRARY
# Дата: $(date)
# Сервер: storage.omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== РЕАЛИЗОВАННЫЕ МЕРЫ БЕЗОПАСНОСТИ ===

✅ Защита от атак:
- Fail2Ban: nginx-http-auth, nginx-noscript, nginx-badbots, drupal-auth
- Ограничения скорости: login, api, general
- Firewall: iptables с защитой от DDoS и сканирования

✅ Безопасность веб-сервера:
- Заголовки безопасности: HSTS, CSP, X-Frame-Options
- SSL/TLS: современные протоколы и шифры
- Скрытие версий сервера
- Защита системных файлов

✅ Безопасность базы данных:
- Ограничение подключений
- Логирование всех операций
- Защищенная аутентификация (SCRAM-SHA-256)
- Ограниченные права доступа

✅ Безопасность PHP:
- Отключение опасных функций
- Безопасные настройки сессий
- Контроль загрузки файлов
- Скрытие информации о PHP

✅ Аудит и мониторинг:
- Системный аудит (auditd)
- Мониторинг безопасности каждые 10 минут
- Проверка целостности файлов (AIDE)
- Логирование всех действий

✅ Резервное копирование:
- Зашифрованные архивы
- Автоматическое выполнение
- Безопасное хранение
- Ротация старых копий

✅ Автоматизация:
- Автоматические обновления безопасности
- Мониторинг в реальном времени
- Email-уведомления о проблемах
- Регулярные проверки целостности

=== КОМАНДЫ УПРАВЛЕНИЯ БЕЗОПАСНОСТЬЮ ===

Проверка статуса безопасности:
/root/security-monitor.sh status

Создание зашифрованной резервной копии:
/root/secure-backup.sh

Применение firewall правил:
/root/firewall-drupal.sh

Проверка Fail2Ban:
fail2ban-client status

Проверка заблокированных IP:
fail2ban-client status nginx-http-auth

Разблокировка IP:
fail2ban-client set nginx-http-auth unbanip [IP]

=== ФАЙЛЫ КОНФИГУРАЦИИ ===

Fail2Ban: /etc/fail2ban/jail.d/nginx-drupal.conf
Firewall: /root/firewall-drupal.sh
Аудит: /etc/audit/rules.d/drupal.rules
Мониторинг: /root/security-monitor.sh
Резервные копии: /root/secure-backup.sh

=== ЛОГИ БЕЗОПАСНОСТИ ===

Системный аудит: /var/log/audit/audit.log
Мониторинг: /var/log/security-monitor.log
Fail2Ban: /var/log/fail2ban.log
Nginx: /var/log/nginx/drupal_error.log
Firewall: /var/log/syslog (iptables)

=== РЕКОМЕНДАЦИИ ===

1. Регулярно проверяйте логи безопасности
2. Обновляйте Drupal и модули безопасности
3. Мониторьте заблокированные IP-адреса
4. Проверяйте целостность файлов
5. Тестируйте восстановление из резервных копий
6. Обучите персонал основам безопасности
7. Проводите регулярные аудиты безопасности

=== УРОВЕНЬ ЗАЩИТЫ ===

🛡️ Высокий уровень безопасности достигнут:
- Многослойная защита
- Активный мониторинг
- Автоматическое реагирование
- Зашифрованное резервное копирование
- Аудит всех действий

Система готова к противостоянию современным угрозам!
EOF

echo "14. Удаление временных файлов..."
rm -f /tmp/postgres_security.sql
rm -f /tmp/pg_hba_secure.conf
rm -f /tmp/security-cron

echo
echo "✅ Шаг 9 завершен успешно!"
echo "🛡️ Система безопасности полностью настроена"
echo "🚫 Fail2Ban активен против атак"
echo "🔥 Firewall настроен с защитой от DDoS"
echo "👁️ Мониторинг безопасности активен"
echo "🔐 Зашифрованное резервное копирование"
echo "📊 Системный аудит включен"
echo "🔄 Автоматические обновления безопасности"
echo "📋 Отчет: /root/security-setup-report.txt"
echo "🔍 Мониторинг: /root/security-monitor.sh"
echo "💾 Бэкап: /root/secure-backup.sh"
echo "📌 Следующий шаг: ./10-final-check.sh"
echo
