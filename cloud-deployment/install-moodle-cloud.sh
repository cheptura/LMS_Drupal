#!/bin/bash
# Скрипт установки Moodle 5.0.2 для облачного развертывания
# Поддержка: AWS, DigitalOcean, Google Cloud, Azure
# Usage: ./install-moodle-cloud.sh

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

# Конфигурация
MOODLE_VERSION="5.0"  # Moodle 5.0+ (latest stable)
SITE_NAME="RTTI Learning Management System"
DB_NAME="moodle"
DB_USER="moodleuser"
DB_HOST="localhost"
MOODLE_ROOT="/var/www/moodle"
MOODLE_DATA="/var/moodledata"
ADMIN_USER="admin"
DOMAIN="lms.rtti.tj"  # Установлен конкретный домен
SERVER_IP="92.242.60.172"  # IP сервера LMS
CLOUD_PROVIDER=""
USE_CLOUD_DB="false"
CLOUD_DB_HOST=""
CLOUD_DB_USER=""
CLOUD_DB_PASS=""

# Функция для определения облачного провайдера
detect_cloud_provider() {
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        CLOUD_PROVIDER="aws"
        log "Обнаружен AWS EC2"
    elif curl -s --max-time 3 http://169.254.169.254/metadata/v1/ &>/dev/null; then
        CLOUD_PROVIDER="digitalocean"
        log "Обнаружен DigitalOcean"
    elif curl -s --max-time 3 "http://metadata.google.internal/computeMetadata/v1/" -H "Metadata-Flavor: Google" &>/dev/null; then
        CLOUD_PROVIDER="gcp"
        log "Обнаружен Google Cloud Platform"
    elif curl -s --max-time 3 "http://169.254.169.254/metadata/instance" -H "Metadata: true" &>/dev/null; then
        CLOUD_PROVIDER="azure"
        log "Обнаружен Microsoft Azure"
    else
        CLOUD_PROVIDER="generic"
        log "Обычный VPS сервер"
    fi
}

# Функция для настройки параметров
setup_config() {
    echo "=== Настройка параметров установки ==="
    
    read -p "Введите домен для Moodle (например: lms.example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        error "Домен обязателен"
    fi
    
    read -p "Использовать облачную базу данных? (y/n): " use_cloud
    if [[ "$use_cloud" == "y" || "$use_cloud" == "Y" ]]; then
        USE_CLOUD_DB="true"
        read -p "Хост облачной БД: " CLOUD_DB_HOST
        read -p "Пользователь БД: " CLOUD_DB_USER
        read -s -p "Пароль БД: " CLOUD_DB_PASS
        echo
        DB_HOST="$CLOUD_DB_HOST"
        DB_USER="$CLOUD_DB_USER"
    fi
    
    log "Конфигурация завершена"
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
    apt update
    apt upgrade -y
    apt install -y software-properties-common curl wget git unzip
    
    # Настройка временной зоны
    timedatectl set-timezone Asia/Dushanbe
    
    log "Система обновлена"
}

# Установка PHP 8.2
install_php() {
    log "Установка PHP 8.2 для Moodle 5.0.2..."
    
    # Добавляем PPA для PHP
    add-apt-repository ppa:ondrej/php -y
    apt update
    
    # Установка PHP и расширений
    apt install -y \
        php8.2 \
        php8.2-fpm \
        php8.2-cli \
        php8.2-mysql \
        php8.2-pgsql \
        php8.2-xml \
        php8.2-gd \
        php8.2-zip \
        php8.2-mbstring \
        php8.2-curl \
        php8.2-intl \
        php8.2-ldap \
        php8.2-soap \
        php8.2-xmlrpc \
        php8.2-opcache \
        php8.2-redis \
        php8.2-bcmath \
        php8.2-imagick \
        php8.2-xsl
    
    log "PHP 8.2 установлен"
}

# Установка и настройка Nginx
install_nginx() {
    log "Установка Nginx..."
    
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Удаляем дефолтный сайт
    rm -f /etc/nginx/sites-enabled/default
    
    log "Nginx установлен и настроен"
}

# Установка базы данных
install_database() {
    if [[ "$USE_CLOUD_DB" == "true" ]]; then
        log "Используется облачная база данных: $CLOUD_DB_HOST"
        return 0
    fi
    
    log "Установка PostgreSQL 16..."
    
    # Добавляем официальный репозиторий PostgreSQL
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt update
    
    apt install -y postgresql-16 postgresql-client-16
    systemctl start postgresql
    systemctl enable postgresql
    
    # Создание базы данных и пользователя
    log "Настройка базы данных PostgreSQL..."
    
    # Проверяем существует ли база данных
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        warning "База данных $DB_NAME уже существует!"
        read -p "Удалить существующую базу данных и создать новую? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Удаляем существующую базу данных..."
            sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;"
            sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;"
        else
            log "Используем существующую базу данных..."
            # Пытаемся найти существующий пароль
            if [ -f "/root/moodle-credentials.txt" ]; then
                log "Используем существующие учетные данные из /root/moodle-credentials.txt"
                return 0
            else
                error "Не найдены учетные данные для существующей базы данных"
            fi
        fi
    fi
    
    DB_PASSWORD=$(openssl rand -base64 32)
    
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;"
    
    # Сохраняем пароль
    echo "DB_PASSWORD=$DB_PASSWORD" > /root/moodle-credentials.txt
    chmod 600 /root/moodle-credentials.txt
    
    log "PostgreSQL настроен"
}

# Установка Redis
install_redis() {
    log "Установка Redis 7..."
    
    apt install -y redis-server
    
    # Настройка Redis
    sed -i 's/^# maxmemory <bytes>/maxmemory 1gb/' /etc/redis/redis.conf
    sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
    
    systemctl restart redis-server
    systemctl enable redis-server
    
    log "Redis установлен"
}

# Установка Composer
install_composer() {
    log "Установка Composer 2.7..."
    
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    
    # Проверяем версию
    composer --version
    
    log "Composer установлен"
}

# Установка Node.js
install_nodejs() {
    log "Установка Node.js 20..."
    
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Установка Grunt CLI для сборки Moodle
    npm install -g grunt-cli
    
    log "Node.js 20 установлен"
}

# Загрузка и установка Moodle
install_moodle() {
    log "Загрузка Moodle $MOODLE_VERSION..."
    
    # Создаем директории
    mkdir -p "$MOODLE_ROOT"
    mkdir -p "$MOODLE_DATA"
    
    # Скачиваем Moodle 5.0+
    cd /tmp
    wget "https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz" -O "moodle-${MOODLE_VERSION}.tgz"
    
    if [ ! -f "moodle-${MOODLE_VERSION}.tgz" ]; then
        # Альтернативная ссылка если основная не работает
        log "Пробуем альтернативную ссылку..."
        wget "https://github.com/moodle/moodle/archive/refs/heads/MOODLE_500_STABLE.tar.gz" -O "moodle-${MOODLE_VERSION}.tgz"
    fi
    
    tar -xzf "moodle-${MOODLE_VERSION}.tgz"
    
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
    chown -R www-data:www-data "$MOODLE_DATA"
    chmod -R 755 "$MOODLE_ROOT"
    chmod -R 770 "$MOODLE_DATA"
    
    log "Moodle файлы установлены"
}

# Настройка Nginx для Moodle
configure_nginx() {
    log "Настройка Nginx для Moodle..."
    
    cat > "/etc/nginx/sites-available/moodle" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $MOODLE_ROOT;
    index index.php index.html;

    # Увеличиваем лимиты для больших файлов
    client_max_body_size 2048M;
    client_body_timeout 300s;
    client_header_timeout 300s;

    # Основные правила
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP обработка
    location ~ [^/]\.php(/|\$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        
        # Увеличенные буферы для Moodle 5.0
        fastcgi_buffer_size 256k;
        fastcgi_buffers 512 16k;
        fastcgi_busy_buffers_size 512k;
        fastcgi_temp_file_write_size 512k;
        fastcgi_read_timeout 900;
        fastcgi_send_timeout 900;
    }

    # Безопасность
    location ~ /\.ht {
        deny all;
    }
    
    location ~ /\. {
        deny all;
    }

    # Оптимизация статических файлов
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        access_log off;
    }

    # Gzip сжатие
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Логирование
    access_log /var/log/nginx/moodle_access.log;
    error_log /var/log/nginx/moodle_error.log;
}
EOF
    
    # Включаем сайт
    ln -sf /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
    
    # Проверяем конфигурацию
    nginx -t
    systemctl reload nginx
    
    log "Nginx настроен для Moodle"
}

# Настройка PHP для Moodle 5.0
configure_php() {
    log "Настройка PHP 8.2 для Moodle 5.0.2..."
    
    # Основные настройки PHP
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 2048M/' /etc/php/8.2/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 2048M/' /etc/php/8.2/fpm/php.ini
    sed -i 's/memory_limit = .*/memory_limit = 1024M/' /etc/php/8.2/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 600/' /etc/php/8.2/fpm/php.ini
    sed -i 's/max_input_vars = .*/max_input_vars = 10000/' /etc/php/8.2/fpm/php.ini
    sed -i 's/max_input_time = .*/max_input_time = 600/' /etc/php/8.2/fpm/php.ini
    
    # Настройки временной зоны
    sed -i 's/;date.timezone =.*/date.timezone = Asia\/Dushanbe/' /etc/php/8.2/fpm/php.ini
    
    # Настройки OPcache для лучшей производительности
    cat >> /etc/php/8.2/fpm/conf.d/10-opcache.ini << EOF
opcache.enable=1
opcache.memory_consumption=512
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
opcache.save_comments=1
opcache.fast_shutdown=1
EOF

    # Настройки Redis для сессий
    cat >> /etc/php/8.2/fpm/conf.d/50-redis-sessions.ini << EOF
session.save_handler = redis
session.save_path = "tcp://127.0.0.1:6379"
EOF
    
    # Настройка PHP-FPM pool
    cat > /etc/php/8.2/fpm/pool.d/moodle.conf << EOF
[moodle]
user = www-data
group = www-data

listen = /var/run/php/php8.2-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Process management для облачных серверов
pm = dynamic
pm.max_children = 100
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 1000

; Resource limits
pm.process_idle_timeout = 60s
request_terminate_timeout = 600

; Logging
access.log = /var/log/php8.2-fpm-moodle-access.log
slowlog = /var/log/php8.2-fpm-moodle-slow.log
request_slowlog_timeout = 30s

; Security
security.limit_extensions = .php
EOF
    
    # Удаляем стандартный pool
    rm -f /etc/php/8.2/fpm/pool.d/www.conf
    
    systemctl restart php8.2-fpm
    
    log "PHP 8.2 настроен"
}

# Установка SSL сертификата
install_ssl() {
    log "Установка SSL сертификата..."
    
    apt install -y certbot python3-certbot-nginx
    
    # Получаем сертификат
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@rtti.tj"
    
    # Настройка автообновления
    echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
    
    log "SSL сертификат установлен"
}

# Создание конфигурации Moodle
create_moodle_config() {
    log "Создание конфигурации Moodle..."
    
    if [[ "$USE_CLOUD_DB" == "true" ]]; then
        DB_PASSWORD="$CLOUD_DB_PASS"
    else
        DB_PASSWORD=$(grep "DB_PASSWORD=" /root/moodle-credentials.txt | cut -d'=' -f2)
    fi
    
    cat > "$MOODLE_ROOT/config.php" << EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

// Основные настройки
\$CFG->dbtype    = 'pgsql';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '$DB_HOST';
\$CFG->dbname    = '$DB_NAME';
\$CFG->dbuser    = '$DB_USER';
\$CFG->dbpass    = '$DB_PASSWORD';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => '',
    'dbsocket' => '',
    'dbcollation' => 'utf8_unicode_ci',
);

// Пути
\$CFG->wwwroot   = 'https://$DOMAIN';
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
\$CFG->session_redis_prefix = 'moodle_session:';

// Настройки безопасности для облачного развертывания
\$CFG->passwordsaltmain = '$(openssl rand -base64 32)';

// Отладка (отключить в продакшн)
\$CFG->debug = 0;
\$CFG->debugdisplay = 0;

// Настройки файлов
\$CFG->maxbytes = 2147483648; // 2GB

// Облачные настройки
\$CFG->forced_plugin_settings = array(
    'cachestore_redis' => array(
        'server' => '127.0.0.1:6379',
        'prefix' => 'moodle_cache:',
    ),
);

require_once(__DIR__ . '/lib/setup.php');
EOF
    
    chown www-data:www-data "$MOODLE_ROOT/config.php"
    chmod 644 "$MOODLE_ROOT/config.php"
    
    log "Конфигурация Moodle создана"
}

# Установка Moodle через CLI
install_moodle_cli() {
    log "Установка Moodle через командную строку..."
    
    cd "$MOODLE_ROOT"
    
    # Генерируем пароль администратора
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    
    sudo -u www-data php admin/cli/install.php \
        --non-interactive \
        --agree-license \
        --lang=en \
        --wwwroot="https://$DOMAIN" \
        --dataroot="$MOODLE_DATA" \
        --dbtype=pgsql \
        --dbhost="$DB_HOST" \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$(grep "DB_PASSWORD=" /root/moodle-credentials.txt | cut -d'=' -f2 2>/dev/null || echo "$CLOUD_DB_PASS")" \
        --prefix=mdl_ \
        --fullname="$SITE_NAME" \
        --shortname="RTTI-LMS" \
        --adminuser="$ADMIN_USER" \
        --adminpass="$ADMIN_PASSWORD" \
        --adminemail="admin@rtti.tj"
    
    # Сохраняем учетные данные
    echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> /root/moodle-credentials.txt
    echo "MOODLE_URL=https://$DOMAIN" >> /root/moodle-credentials.txt
    
    log "Moodle установлен через CLI"
}

# Настройка cron заданий
setup_cron() {
    log "Настройка cron заданий..."
    
    # Cron для Moodle
    echo "*/5 * * * * www-data /usr/bin/php $MOODLE_ROOT/admin/cli/cron.php >/dev/null 2>&1" >> /etc/crontab
    
    # Cron для очистки временных файлов
    echo "0 2 * * * root find /tmp -name 'sess_*' -mtime +1 -delete >/dev/null 2>&1" >> /etc/crontab
    
    systemctl restart cron
    
    log "Cron задания настроены"
}

# Настройка мониторинга для облака
setup_cloud_monitoring() {
    log "Настройка облачного мониторинга..."
    
    # Создаем скрипт мониторинга
    cat > /opt/moodle-monitor.sh << 'EOF'
#!/bin/bash
# Простой мониторинг для облачного развертывания

LOG_FILE="/var/log/moodle-monitor.log"

check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "[$(date)] OK: $service is running" >> "$LOG_FILE"
    else
        echo "[$(date)] ERROR: $service is not running" >> "$LOG_FILE"
        systemctl restart "$service"
    fi
}

check_disk_space() {
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -gt 85 ]; then
        echo "[$(date)] WARNING: Disk usage is ${usage}%" >> "$LOG_FILE"
    fi
}

# Основные проверки
check_service "nginx"
check_service "php8.2-fpm"
check_service "postgresql"
check_service "redis-server"
check_disk_space

# Проверка доступности Moodle
if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200\|301\|302"; then
    echo "[$(date)] ERROR: Moodle is not responding" >> "$LOG_FILE"
fi
EOF
    
    chmod +x /opt/moodle-monitor.sh
    
    # Добавляем в cron
    echo "*/15 * * * * root /opt/moodle-monitor.sh" >> /etc/crontab
    
    log "Мониторинг настроен"
}

# Создание файла с информацией об установке
create_info_file() {
    log "Создание информационного файла..."
    
    cat > /root/moodle-installation-info.txt << EOF
=== MOODLE 5.0.2 CLOUD INSTALLATION INFO ===
Installation Date: $(date)
Cloud Provider: $CLOUD_PROVIDER
Domain: https://$DOMAIN
Moodle Version: $MOODLE_VERSION

=== SYSTEM INFO ===
OS: $(lsb_release -d | cut -f2)
PHP Version: $(php -v | head -n1)
Database: PostgreSQL $(psql --version | awk '{print $3}' 2>/dev/null || echo "Cloud Database")
Redis: $(redis-server --version | awk '{print $3}')

=== PATHS ===
Moodle Root: $MOODLE_ROOT
Moodle Data: $MOODLE_DATA
Nginx Config: /etc/nginx/sites-available/moodle
PHP Config: /etc/php/8.2/fpm/php.ini

=== CREDENTIALS ===
Admin User: $ADMIN_USER
Admin URL: https://$DOMAIN/admin/
Database: $DB_NAME
DB User: $DB_USER

=== LOG FILES ===
Nginx Access: /var/log/nginx/moodle_access.log
Nginx Error: /var/log/nginx/moodle_error.log
PHP-FPM: /var/log/php8.2-fpm-moodle-slow.log
Moodle Monitor: /var/log/moodle-monitor.log

=== USEFUL COMMANDS ===
Moodle CLI: sudo -u www-data php $MOODLE_ROOT/admin/cli/
Update Moodle: sudo -u www-data php $MOODLE_ROOT/admin/cli/upgrade.php
Clear Cache: sudo -u www-data php $MOODLE_ROOT/admin/cli/purge_caches.php
Maintenance Mode: sudo -u www-data php $MOODLE_ROOT/admin/cli/maintenance.php

=== NEXT STEPS ===
1. Login to admin panel: https://$DOMAIN/admin/
2. Configure site settings
3. Install additional plugins
4. Create courses and users
5. Setup integrations

EOF
    
    if [[ -f /root/moodle-credentials.txt ]]; then
        echo "=== PASSWORDS (KEEP SECURE) ===" >> /root/moodle-installation-info.txt
        cat /root/moodle-credentials.txt >> /root/moodle-installation-info.txt
    fi
    
    chmod 600 /root/moodle-installation-info.txt
    
    log "Информационный файл создан: /root/moodle-installation-info.txt"
}

# Финальная проверка
final_check() {
    log "Выполнение финальной проверки..."
    
    # Проверка сервисов
    services=("nginx" "php8.2-fpm" "redis-server")
    if [[ "$USE_CLOUD_DB" != "true" ]]; then
        services+=("postgresql")
    fi
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✓ $service работает"
        else
            error "✗ $service не работает"
        fi
    done
    
    # Проверка доступности сайта
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200\|301\|302"; then
        log "✓ Moodle отвечает на запросы"
    else
        warning "⚠ Moodle может быть недоступен"
    fi
    
    log "Финальная проверка завершена"
}

# Функция полной очистки для переустановки
cleanup_previous_installation() {
    log "Очистка предыдущей установки Moodle..."
    
    read -p "Это удалит все данные Moodle! Продолжить? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Очистка отменена"
        return 0
    fi
    
    # Остановка сервисов
    systemctl stop nginx php8.2-fpm postgresql redis-server 2>/dev/null || true
    
    # Удаление файлов Moodle
    rm -rf "$MOODLE_ROOT" 2>/dev/null || true
    rm -rf "$MOODLE_DATA" 2>/dev/null || true
    
    # Удаление конфигураций Nginx
    rm -f /etc/nginx/sites-available/moodle 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/moodle 2>/dev/null || true
    
    # Удаление конфигураций PHP-FPM
    rm -f /etc/php/8.2/fpm/pool.d/moodle.conf 2>/dev/null || true
    
    # Удаление базы данных
    if systemctl is-active --quiet postgresql; then
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
        sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null || true
    fi
    
    # Удаление файлов логов и данных
    rm -f /root/moodle-credentials.txt 2>/dev/null || true
    rm -f /root/moodle-installation-info.txt 2>/dev/null || true
    rm -f /var/log/moodle-*.log 2>/dev/null || true
    
    # Очистка cron заданий
    crontab -l 2>/dev/null | grep -v moodle | crontab - 2>/dev/null || true
    
    # Перезапуск сервисов
    systemctl start postgresql redis-server 2>/dev/null || true
    
    log "Предыдущая установка очищена"
}

# Главная функция
main() {
    echo "========================================"
    echo "   Установка Moodle 5.0.2 (Облако)    "
    echo "========================================"
    
    check_root
    detect_cloud_provider
    setup_config
    
    log "Начинаем установку Moodle $MOODLE_VERSION на $CLOUD_PROVIDER"
    
    update_system
    install_php
    install_nginx
    install_database
    install_redis
    install_composer
    install_nodejs
    install_moodle
    configure_nginx
    configure_php
    create_moodle_config
    install_moodle_cli
    setup_cron
    setup_cloud_monitoring
    
    # SSL только если домен доступен
    if ping -c 1 "$DOMAIN" &> /dev/null; then
        install_ssl
    else
        warning "Домен $DOMAIN недоступен, SSL будет настроен позже"
    fi
    
    create_info_file
    final_check
    
    echo "========================================"
    log "Установка Moodle 5.0.2 завершена!"
    echo "========================================"
    log "Сайт: https://$DOMAIN"
    log "Админ панель: https://$DOMAIN/admin/"
    log "Информация об установке: /root/moodle-installation-info.txt"
    echo "========================================"
}

# Обработка параметров командной строки
case "${1:-install}" in
    "cleanup"|"clean")
        echo "========================================"
        echo "    Очистка установки Moodle 5.0+     "
        echo "========================================"
        check_root
        cleanup_previous_installation
        echo "========================================"
        log "Очистка завершена! Теперь можно установить заново:"
        log "./install-moodle-cloud.sh"
        echo "========================================"
        ;;
    "install"|*)
        main
        ;;
esac
