#!/bin/bash
# Скрипт автоматической установки Moodle 5.0.2 для продакшн с NAS
# Поддерживает Ubuntu 24.04 LTS с интеграцией NAS хранилища

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Конфигурация по умолчанию
MOODLE_VERSION="5.0"  # Moodle 5.0+ (latest stable)
PHP_VERSION="8.2"
MOODLE_DOMAIN="lms.rtti.tj"  # Установлен конкретный домен
SERVER_IP="92.242.60.172"    # IP сервера LMS
MOODLE_ROOT="/var/www/moodle"
MOODLE_DATA="/var/moodledata"
MOODLE_DATA_NAS="/mnt/nas/moodledata"
NAS_HOST=""
NAS_USER="moodleuser"
NAS_SHARE="moodle-files"
ADMIN_EMAIL="admin@rtti.tj"
ADMIN_USER="admin"
ADMIN_PASS=""
LOG_FILE="/var/log/moodle-production-install.log"

# Функция настройки параметров
setup_configuration() {
    echo "=== Настройка параметров установки Moodle Production ==="
    
    read -p "Домен для Moodle (например: lms.rtti.tj): " MOODLE_DOMAIN
    read -p "Email администратора: " ADMIN_EMAIL
    read -p "IP адрес NAS сервера: " NAS_HOST
    read -p "Пользователь NAS (по умолчанию: moodleuser): " nas_user_input
    NAS_USER=${nas_user_input:-$NAS_USER}
    
    # Генерация пароля администратора
    ADMIN_PASS=$(openssl rand -base64 16)
    
    log "Конфигурация настроена"
    log "Пароль администратора: $ADMIN_PASS (будет сохранен в /root/moodle-credentials.txt)"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен запускаться с правами root"
    fi
}

# Обновление системы
update_system() {
    log "Обновление системы Ubuntu 24.04..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt update && apt upgrade -y
    
    # Настройка временной зоны
    timedatectl set-timezone Asia/Dushanbe
    
    log "Система обновлена"
}

# Установка необходимого ПО
install_software() {
    log "Установка необходимого ПО..."
    
    apt install -y \
        nginx \
        php$PHP_VERSION-fpm php$PHP_VERSION-cli php$PHP_VERSION-mysql php$PHP_VERSION-pgsql \
        php$PHP_VERSION-xml php$PHP_VERSION-gd php$PHP_VERSION-zip php$PHP_VERSION-mbstring \
        php$PHP_VERSION-curl php$PHP_VERSION-intl php$PHP_VERSION-ldap php$PHP_VERSION-soap \
        php$PHP_VERSION-xmlrpc php$PHP_VERSION-opcache php$PHP_VERSION-redis php$PHP_VERSION-bcmath \
        postgresql-16 postgresql-client-16 \
        redis-server \
        certbot python3-certbot-nginx \
        git curl wget unzip \
        cifs-utils nfs-common \
        fail2ban ufw \
        htop iotop nethogs \
        logrotate rsyslog
    
    log "Необходимое ПО установлено"
}

# Настройка NAS подключения
setup_nas_connection() {
    log "Настройка подключения к NAS..."
    
    # Создание точки монтирования
    mkdir -p /mnt/nas
    mkdir -p "$MOODLE_DATA_NAS"
    
    # Запрос пароля для NAS
    read -s -p "Пароль для пользователя NAS $NAS_USER: " nas_password
    echo
    
    # Создание файла с учетными данными
    cat > /etc/samba/nas-credentials << EOF
username=$NAS_USER
password=$nas_password
domain=rtti.local
EOF
    
    chmod 600 /etc/samba/nas-credentials
    
    # Добавление в fstab для автоматического монтирования
    echo "//$NAS_HOST/$NAS_SHARE /mnt/nas cifs credentials=/etc/samba/nas-credentials,uid=www-data,gid=www-data,file_mode=0664,dir_mode=0775,vers=3.0 0 0" >> /etc/fstab
    
    # Монтирование NAS
    mount -a
    
    if mountpoint -q /mnt/nas; then
        log "NAS подключен успешно"
        
        # Создание символической ссылки для moodledata
        ln -sf "$MOODLE_DATA_NAS" "$MOODLE_DATA"
        
        # Настройка прав доступа
        chown -R www-data:www-data /mnt/nas
        chmod -R 775 /mnt/nas
    else
        error "Не удалось подключиться к NAS"
    fi
}

# Настройка PostgreSQL
setup_postgresql() {
    log "Настройка PostgreSQL 16..."
    
    systemctl start postgresql
    systemctl enable postgresql
    
    # Создание базы данных и пользователя
    DB_PASSWORD=$(openssl rand -base64 32)
    
    sudo -u postgres psql -c "CREATE DATABASE moodle;"
    sudo -u postgres psql -c "CREATE USER moodleuser WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE moodle TO moodleuser;"
    sudo -u postgres psql -c "ALTER USER moodleuser CREATEDB;"
    
    # Настройка PostgreSQL для производительности
    PG_VERSION="16"
    PG_CONFIG="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    
    # Оптимизация конфигурации
    sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" "$PG_CONFIG"
    sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 1GB/" "$PG_CONFIG"
    sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 128MB/" "$PG_CONFIG"
    sed -i "s/#checkpoint_completion_target = 0.9/checkpoint_completion_target = 0.9/" "$PG_CONFIG"
    sed -i "s/#wal_buffers = -1/wal_buffers = 16MB/" "$PG_CONFIG"
    sed -i "s/#random_page_cost = 4.0/random_page_cost = 1.1/" "$PG_CONFIG"
    
    systemctl restart postgresql
    
    # Сохранение паролей
    cat > /root/moodle-db-credentials.txt << EOF
Database: moodle
Username: moodleuser
Password: $DB_PASSWORD
Host: localhost
Port: 5432
EOF
    chmod 600 /root/moodle-db-credentials.txt
    
    log "PostgreSQL настроен"
}

# Настройка Redis
setup_redis() {
    log "Настройка Redis..."
    
    systemctl start redis-server
    systemctl enable redis-server
    
    # Оптимизация конфигурации Redis
    cat >> /etc/redis/redis.conf << EOF

# Moodle optimization
maxmemory 256mb
maxmemory-policy allkeys-lru
tcp-keepalive 60
timeout 300
EOF
    
    systemctl restart redis-server
    
    log "Redis настроен"
}

# Настройка PHP
configure_php() {
    log "Настройка PHP $PHP_VERSION..."
    
    # Основные настройки PHP
    PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
    
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2048M/' "$PHP_INI"
    sed -i 's/post_max_size = 8M/post_max_size = 2048M/' "$PHP_INI"
    sed -i 's/max_execution_time = 30/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/max_input_time = 60/max_input_time = 300/' "$PHP_INI"
    sed -i 's/memory_limit = 128M/memory_limit = 512M/' "$PHP_INI"
    sed -i 's/;max_input_vars = 1000/max_input_vars = 5000/' "$PHP_INI"
    
    # Настройка OPcache
    cat >> "$PHP_INI" << EOF

; OPcache настройки для Moodle
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.save_comments=1
opcache.enable_cli=1
EOF
    
    # Настройка pool для Moodle
    cat > /etc/php/$PHP_VERSION/fpm/pool.d/moodle.conf << EOF
[moodle]
user = www-data
group = www-data
listen = /var/run/php/php$PHP_VERSION-fpm-moodle.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0666

pm = dynamic
pm.max_children = 50
pm.start_servers = 20
pm.min_spare_servers = 10
pm.max_spare_servers = 30
pm.process_idle_timeout = 10s
pm.max_requests = 500

php_admin_value[disable_functions] = exec,passthru,shell_exec,system
php_admin_flag[allow_url_fopen] = off
php_admin_value[memory_limit] = 512M
php_admin_value[upload_max_filesize] = 2048M
php_admin_value[post_max_size] = 2048M
php_admin_value[max_execution_time] = 300
EOF
    
    systemctl restart php$PHP_VERSION-fpm
    
    log "PHP настроен"
}

# Скачивание и установка Moodle
install_moodle() {
    log "Скачивание и установка Moodle $MOODLE_VERSION..."
    
    # Создание директорий
    mkdir -p "$MOODLE_ROOT"
    mkdir -p "$MOODLE_DATA_NAS"
    
    # Скачивание Moodle 5.0+
    cd /tmp
    wget "https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz" -O "moodle-$MOODLE_VERSION.tgz"
    
    if [ ! -f "moodle-$MOODLE_VERSION.tgz" ]; then
        # Альтернативная ссылка если основная не работает
        log "Пробуем альтернативную ссылку..."
        wget "https://github.com/moodle/moodle/archive/refs/heads/MOODLE_500_STABLE.tar.gz" -O "moodle-$MOODLE_VERSION.tgz"
    fi
    
    tar -xzf moodle-$MOODLE_VERSION.tgz
    
    # Копируем файлы (проверяем структуру архива для Moodle 5.0)
    if [ -d "moodle" ]; then
        cp -R moodle/* "$MOODLE_ROOT/"
    elif [ -d "moodle-latest-500" ]; then
        cp -R "moodle-latest-500"/* "$MOODLE_ROOT/"
    elif [ -d "moodle-MOODLE_500_STABLE" ]; then
        cp -R "moodle-MOODLE_500_STABLE"/* "$MOODLE_ROOT/"
    else
        # Ищем любую директорию с moodle
        MOODLE_DIR=$(find . -maxdepth 1 -type d -name "*moodle*" | head -1)
        if [ -n "$MOODLE_DIR" ]; then
            cp -R "$MOODLE_DIR"/* "$MOODLE_ROOT/"
        else
            error "Не удалось найти файлы Moodle в архиве"
        fi
    fi
    
    # Настройка прав доступа
    chown -R www-data:www-data "$MOODLE_ROOT"
    chmod -R 755 "$MOODLE_ROOT"
    
    # Убедимся, что NAS данные доступны для записи
    chown -R www-data:www-data "$MOODLE_DATA_NAS"
    chmod -R 770 "$MOODLE_DATA_NAS"
    
    log "Moodle установлен"
}

# Настройка Moodle
configure_moodle() {
    log "Настройка Moodle..."
    
    DB_PASSWORD=$(grep "Password:" /root/moodle-db-credentials.txt | cut -d' ' -f2)
    
    # Создание config.php
    cat > "$MOODLE_ROOT/config.php" << EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'pgsql';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'moodleuser';
\$CFG->dbpass    = '$DB_PASSWORD';
\$CFG->prefix    = 'mdl_';

\$CFG->wwwroot   = 'https://$MOODLE_DOMAIN';
\$CFG->dataroot  = '$MOODLE_DATA';
\$CFG->admin     = 'admin';
\$CFG->directorypermissions = 0777;

// Производительность и кэширование
\$CFG->cachejs = true;
\$CFG->cachecss = true;
\$CFG->langstringcache = true;

// Redis кэширование
\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '127.0.0.1';
\$CFG->session_redis_port = 6379;
\$CFG->session_redis_database = 0;

// Настройки безопасности для продакшн
\$CFG->preventexecpath = true;
\$CFG->disableupdatenotifications = true;
\$CFG->disableupdateautodeploy = true;

// Настройки производительности
\$CFG->enablecompletion = true;
\$CFG->completiondefault = 1;

// Логирование
\$CFG->debugdisplay = 0;
\$CFG->debug = 0;

// Соль для паролей
\$CFG->passwordsaltmain = '$(openssl rand -base64 32)';

require_once(__DIR__ . '/lib/setup.php');
EOF
    
    chown www-data:www-data "$MOODLE_ROOT/config.php"
    chmod 644 "$MOODLE_ROOT/config.php"
    
    log "Конфигурация Moodle создана"
}

# Установка через CLI
install_moodle_cli() {
    log "Установка Moodle через CLI..."
    
    cd "$MOODLE_ROOT"
    
    sudo -u www-data php admin/cli/install.php \
        --lang=ru \
        --wwwroot="https://$MOODLE_DOMAIN" \
        --dataroot="$MOODLE_DATA" \
        --dbtype=pgsql \
        --dbhost=localhost \
        --dbname=moodle \
        --dbuser=moodleuser \
        --dbpass="$(grep "Password:" /root/moodle-db-credentials.txt | cut -d' ' -f2)" \
        --fullname="Российско-Таджикский институт - LMS" \
        --shortname="RTTI LMS" \
        --adminuser="$ADMIN_USER" \
        --adminpass="$ADMIN_PASS" \
        --adminemail="$ADMIN_EMAIL" \
        --non-interactive \
        --agree-license
    
    log "Moodle установлен через CLI"
}

# Настройка Nginx
configure_nginx() {
    log "Настройка Nginx для Moodle..."
    
    cat > /etc/nginx/sites-available/moodle << EOF
# Rate limiting
limit_req_zone \$binary_remote_addr zone=moodle:10m rate=10r/m;

server {
    listen 80;
    server_name $MOODLE_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $MOODLE_DOMAIN;
    
    root $MOODLE_ROOT;
    index index.php index.html;

    # SSL сертификаты (будут настроены автоматически)
    ssl_certificate /etc/letsencrypt/live/$MOODLE_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$MOODLE_DOMAIN/privkey.pem;
    
    # SSL настройки безопасности
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Максимальный размер файла
    client_max_body_size 2048M;
    
    # Rate limiting
    limit_req zone=moodle burst=20 nodelay;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ [^/]\.php(/|\$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm-moodle.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        
        # Продакшн настройки FastCGI
        fastcgi_buffer_size 256k;
        fastcgi_buffers 512 16k;
        fastcgi_busy_buffers_size 512k;
        fastcgi_temp_file_write_size 512k;
        fastcgi_read_timeout 900;
        fastcgi_send_timeout 900;
        fastcgi_connect_timeout 900;
    }

    # Запрет доступа к конфигурационным файлам
    location ~ /\.ht { deny all; }
    location ~ /\.git { deny all; }
    location ^~ /config.php { deny all; }
    
    # Статические файлы
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip сжатие
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Логирование
    access_log /var/log/nginx/moodle_access.log;
    error_log /var/log/nginx/moodle_error.log;
}
EOF
    
    # Включение сайта
    ln -sf /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Проверка конфигурации
    nginx -t
    systemctl restart nginx
    
    log "Nginx настроен"
}

# Получение SSL сертификата
setup_ssl() {
    log "Получение SSL сертификата Let's Encrypt..."
    
    # Временная конфигурация для получения сертификата
    cat > /etc/nginx/sites-available/moodle-temp << EOF
server {
    listen 80;
    server_name $MOODLE_DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/moodle-temp /etc/nginx/sites-enabled/moodle
    systemctl reload nginx
    
    # Получение сертификата
    certbot certonly --nginx -d "$MOODLE_DOMAIN" --non-interactive --agree-tos --email "$ADMIN_EMAIL"
    
    if [ $? -eq 0 ]; then
        log "SSL сертификат получен"
        # Восстановление основной конфигурации
        ln -sf /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/moodle
        systemctl reload nginx
        
        # Настройка автообновления сертификата
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'") | crontab -
    else
        warning "Не удалось получить SSL сертификат. Настройте его вручную."
        # Конфигурация без SSL
        cat > /etc/nginx/sites-available/moodle << EOF
server {
    listen 80;
    server_name $MOODLE_DOMAIN;
    
    root $MOODLE_ROOT;
    index index.php index.html;

    client_max_body_size 2048M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ [^/]\.php(/|\$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm-moodle.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_buffer_size 256k;
        fastcgi_buffers 512 16k;
        fastcgi_busy_buffers_size 512k;
        fastcgi_temp_file_write_size 512k;
        fastcgi_read_timeout 900;
    }

    location ~ /\.ht { deny all; }
}
EOF
        ln -sf /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/moodle
        systemctl reload nginx
    fi
}

# Настройка безопасности
setup_security() {
    log "Настройка безопасности системы..."
    
    # Настройка UFW
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow http
    ufw allow https
    
    # Настройка Fail2Ban
    cat > /etc/fail2ban/jail.d/moodle.conf << EOF
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 600

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 1800
EOF
    
    systemctl restart fail2ban
    
    # Настройка автоматических обновлений безопасности
    apt install -y unattended-upgrades
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
    
    log "Безопасность настроена"
}

# Установка дополнительных модулей Moodle
install_additional_modules() {
    log "Установка дополнительных модулей для RTTI..."
    
    cd "$MOODLE_ROOT"
    
    # BigBlueButton интеграция
    sudo -u www-data git clone https://github.com/blindsidenetworks/moodle-mod_bigbluebuttonbn.git mod/bigbluebuttonbn
    
    # Система антиплагиата
    sudo -u www-data git clone https://github.com/danmarsden/moodle-plagiarism_urkund.git plagiarism/urkund
    
    # Дополнительные темы
    sudo -u www-data git clone https://github.com/bmbrands/theme_boost_union.git theme/boost_union
    
    # Обновление базы данных для новых модулей
    sudo -u www-data php admin/cli/upgrade.php --non-interactive
    
    log "Дополнительные модули установлены"
}

# Настройка мониторинга
setup_monitoring() {
    log "Настройка мониторинга системы..."
    
    # Создание скрипта мониторинга
    cat > /opt/moodle-monitor.sh << 'EOF'
#!/bin/bash
# Скрипт мониторинга Moodle

# Проверка сервисов
services=("nginx" "php8.2-fpm" "postgresql" "redis-server")
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "ALERT: $service is not running" | logger -t moodle-monitor
        systemctl restart "$service"
    fi
done

# Проверка доступности сайта
if ! curl -s -f http://localhost > /dev/null; then
    echo "ALERT: Moodle website is not responding" | logger -t moodle-monitor
fi

# Проверка места на диске
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    echo "ALERT: Disk usage is $disk_usage%" | logger -t moodle-monitor
fi

# Проверка NAS подключения
if ! mountpoint -q /mnt/nas; then
    echo "ALERT: NAS is not mounted" | logger -t moodle-monitor
    mount -a
fi
EOF
    
    chmod +x /opt/moodle-monitor.sh
    
    # Добавление в cron
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/moodle-monitor.sh") | crontab -
    
    log "Мониторинг настроен"
}

# Создание информационного файла
create_info_file() {
    log "Создание информационного файла..."
    
    cat > /root/moodle-production-info.txt << EOF
=== MOODLE $MOODLE_VERSION PRODUCTION INSTALLATION ===
Installation Date: $(date)
Server: $(hostname -I | awk '{print $1}')
Domain: $MOODLE_DOMAIN

=== SYSTEM INFO ===
OS: $(lsb_release -d | cut -f2)
PHP Version: $PHP_VERSION
PostgreSQL: $(sudo -u postgres psql -c "SELECT version();" | head -3 | tail -1)
Nginx: $(nginx -v 2>&1)

=== PATHS ===
Moodle Root: $MOODLE_ROOT
Moodle Data: $MOODLE_DATA (NAS: $MOODLE_DATA_NAS)
Configuration: $MOODLE_ROOT/config.php
Logs: /var/log/nginx/moodle_*.log

=== CREDENTIALS ===
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASS
Admin Email: $ADMIN_EMAIL
Database Credentials: /root/moodle-db-credentials.txt

=== NAS INFO ===
NAS Host: $NAS_HOST
NAS Share: $NAS_SHARE
Mount Point: /mnt/nas
Data Location: $MOODLE_DATA_NAS

=== SERVICES ===
$(systemctl is-active nginx) - Nginx
$(systemctl is-active php$PHP_VERSION-fpm) - PHP-FPM
$(systemctl is-active postgresql) - PostgreSQL
$(systemctl is-active redis-server) - Redis

=== SSL CERTIFICATE ===
$(if [ -f "/etc/letsencrypt/live/$MOODLE_DOMAIN/fullchain.pem" ]; then echo "✓ SSL configured"; else echo "⚠ SSL not configured"; fi)

=== NEXT STEPS ===
1. Войдите в Moodle: https://$MOODLE_DOMAIN/login/
2. Настройте основные параметры системы
3. Создайте курсы и пользователей
4. Настройте интеграцию с внешними системами
5. Проверьте работу NAS резервного копирования

=== BACKUP INFO ===
Monitoring Script: /opt/moodle-monitor.sh
Backup Script: /opt/nas-backup.sh (если установлен)
Log Rotation: Configured for all services

=== SUPPORT COMMANDS ===
Service Status: systemctl status nginx php$PHP_VERSION-fpm postgresql redis-server
Logs: tail -f /var/log/nginx/moodle_error.log
NAS Status: mountpoint /mnt/nas
Moodle CLI: cd $MOODLE_ROOT && sudo -u www-data php admin/cli/
EOF
    
    chmod 600 /root/moodle-production-info.txt
    
    # Сохранение учетных данных
    cat > /root/moodle-credentials.txt << EOF
=== MOODLE CREDENTIALS ===
Admin URL: https://$MOODLE_DOMAIN/login/
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASS
Admin Email: $ADMIN_EMAIL

Database Connection:
Host: localhost
Database: moodle
User: moodleuser
Password: $(grep "Password:" /root/moodle-db-credentials.txt | cut -d' ' -f2)

NAS Connection:
Host: $NAS_HOST
Share: $NAS_SHARE
User: $NAS_USER
Mount: /mnt/nas
EOF
    
    chmod 600 /root/moodle-credentials.txt
    
    log "Информационные файлы созданы"
}

# Финальная проверка
final_check() {
    log "Выполнение финальной проверки..."
    
    # Проверка сервисов
    services=("nginx" "php$PHP_VERSION-fpm" "postgresql" "redis-server")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✓ $service работает"
        else
            error "✗ $service не работает"
        fi
    done
    
    # Проверка доступности сайта
    if curl -s -o /dev/null "http://localhost"; then
        log "✓ Moodle отвечает на запросы"
    else
        warning "⚠ Moodle может быть недоступен"
    fi
    
    # Проверка NAS
    if mountpoint -q /mnt/nas; then
        log "✓ NAS подключен"
    else
        warning "⚠ Проблемы с NAS подключением"
    fi
    
    # Проверка SSL
    if [ -f "/etc/letsencrypt/live/$MOODLE_DOMAIN/fullchain.pem" ]; then
        log "✓ SSL сертификат установлен"
    else
        warning "⚠ SSL сертификат не установлен"
    fi
    
    log "Финальная проверка завершена"
}

# Главная функция
main() {
    echo "========================================="
    echo "   Установка Moodle $MOODLE_VERSION для RTTI (Production)"
    echo "========================================="
    
    check_root
    setup_configuration
    
    log "Начинаем установку Moodle для продакшн..."
    
    update_system
    install_software
    setup_nas_connection
    setup_postgresql
    setup_redis
    configure_php
    install_moodle
    configure_moodle
    install_moodle_cli
    configure_nginx
    setup_ssl
    setup_security
    install_additional_modules
    setup_monitoring
    create_info_file
    final_check
    
    echo "========================================="
    log "Установка Moodle завершена!"
    echo "========================================="
    log "URL: https://$MOODLE_DOMAIN"
    log "Администратор: $ADMIN_USER"
    log "Пароль: $ADMIN_PASS"
    log "Информация: /root/moodle-production-info.txt"
    log "Учетные данные: /root/moodle-credentials.txt"
    echo "========================================="
}

# Запуск установки
main "$@" 2>&1 | tee "$LOG_FILE"
