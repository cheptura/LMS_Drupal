#!/bin/bash
# Скрипт автоматической установки Drupal 11 для продакшн с NAS
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
DRUPAL_VERSION="11.0"
PHP_VERSION="8.3"
DRUPAL_DOMAIN=""
DRUPAL_ROOT="/var/www/drupal"
DRUPAL_FILES_NAS="/mnt/nas/drupal-files"
NAS_HOST=""
NAS_USER="drupaluser"
NAS_SHARE="drupal-files"
ADMIN_EMAIL=""
ADMIN_USER="admin"
ADMIN_PASS=""
SITE_NAME="RTTI Digital Library"
LOG_FILE="/var/log/drupal-production-install.log"

# Функция настройки параметров
setup_configuration() {
    echo "=== Настройка параметров установки Drupal Production ==="
    
    read -p "Домен для Drupal (например: library.rtti.tj): " DRUPAL_DOMAIN
    read -p "Email администратора: " ADMIN_EMAIL
    read -p "IP адрес NAS сервера: " NAS_HOST
    read -p "Пользователь NAS (по умолчанию: drupaluser): " nas_user_input
    NAS_USER=${nas_user_input:-$NAS_USER}
    
    read -p "Название сайта (по умолчанию: RTTI Digital Library): " site_name_input
    SITE_NAME=${site_name_input:-$SITE_NAME}
    
    # Генерация пароля администратора
    ADMIN_PASS=$(openssl rand -base64 16)
    
    log "Конфигурация настроена"
    log "Пароль администратора: $ADMIN_PASS (будет сохранен в /root/drupal-credentials.txt)"
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
    log "Установка необходимого ПО для Drupal 11..."
    
    apt install -y \
        nginx \
        php$PHP_VERSION-fpm php$PHP_VERSION-cli php$PHP_VERSION-mysql php$PHP_VERSION-pgsql \
        php$PHP_VERSION-xml php$PHP_VERSION-gd php$PHP_VERSION-zip php$PHP_VERSION-mbstring \
        php$PHP_VERSION-curl php$PHP_VERSION-intl php$PHP_VERSION-bcmath php$PHP_VERSION-opcache \
        php$PHP_VERSION-apcu php$PHP_VERSION-imagick php$PHP_VERSION-xsl php$PHP_VERSION-redis \
        postgresql-16 postgresql-client-16 \
        redis-server \
        nodejs npm \
        certbot python3-certbot-nginx \
        git curl wget unzip \
        cifs-utils nfs-common \
        fail2ban ufw \
        htop iotop nethogs \
        logrotate rsyslog
    
    # Установка Composer
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    
    # Установка Drush
    composer global require drush/drush:^12
    ln -sf /root/.config/composer/vendor/bin/drush /usr/local/bin/drush || \
    ln -sf /root/.composer/vendor/bin/drush /usr/local/bin/drush
    
    log "Необходимое ПО установлено"
}

# Настройка NAS подключения
setup_nas_connection() {
    log "Настройка подключения к NAS для Drupal файлов..."
    
    # Создание точки монтирования
    mkdir -p /mnt/nas
    mkdir -p "$DRUPAL_FILES_NAS"
    
    # Запрос пароля для NAS
    read -s -p "Пароль для пользователя NAS $NAS_USER: " nas_password
    echo
    
    # Создание файла с учетными данными
    cat > /etc/samba/nas-drupal-credentials << EOF
username=$NAS_USER
password=$nas_password
domain=rtti.local
EOF
    
    chmod 600 /etc/samba/nas-drupal-credentials
    
    # Добавление в fstab для автоматического монтирования
    echo "//$NAS_HOST/$NAS_SHARE /mnt/nas cifs credentials=/etc/samba/nas-drupal-credentials,uid=www-data,gid=www-data,file_mode=0664,dir_mode=0775,vers=3.0 0 0" >> /etc/fstab
    
    # Монтирование NAS
    mount -a
    
    if mountpoint -q /mnt/nas; then
        log "NAS подключен успешно"
        
        # Настройка прав доступа
        chown -R www-data:www-data /mnt/nas
        chmod -R 775 /mnt/nas
    else
        error "Не удалось подключиться к NAS"
    fi
}

# Настройка PostgreSQL
setup_postgresql() {
    log "Настройка PostgreSQL 16 для Drupal..."
    
    systemctl start postgresql
    systemctl enable postgresql
    
    # Создание базы данных и пользователя
    DB_PASSWORD=$(openssl rand -base64 32)
    
    sudo -u postgres psql -c "CREATE DATABASE drupal_library;"
    sudo -u postgres psql -c "CREATE USER drupaluser WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE drupal_library TO drupaluser;"
    sudo -u postgres psql -c "ALTER USER drupaluser CREATEDB;"
    sudo -u postgres psql -c "GRANT CREATE ON SCHEMA public TO drupaluser;"
    
    # Настройка PostgreSQL для производительности
    PG_VERSION="16"
    PG_CONFIG="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    
    # Оптимизация конфигурации для Drupal
    sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" "$PG_CONFIG"
    sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 1GB/" "$PG_CONFIG"
    sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 128MB/" "$PG_CONFIG"
    sed -i "s/#checkpoint_completion_target = 0.9/checkpoint_completion_target = 0.9/" "$PG_CONFIG"
    sed -i "s/#wal_buffers = -1/wal_buffers = 16MB/" "$PG_CONFIG"
    sed -i "s/#random_page_cost = 4.0/random_page_cost = 1.1/" "$PG_CONFIG"
    
    systemctl restart postgresql
    
    # Сохранение паролей
    cat > /root/drupal-db-credentials.txt << EOF
Database: drupal_library
Username: drupaluser
Password: $DB_PASSWORD
Host: localhost
Port: 5432
EOF
    chmod 600 /root/drupal-db-credentials.txt
    
    log "PostgreSQL настроен"
}

# Настройка Redis
setup_redis() {
    log "Настройка Redis для Drupal кэширования..."
    
    systemctl start redis-server
    systemctl enable redis-server
    
    # Оптимизация конфигурации Redis для Drupal
    cat >> /etc/redis/redis.conf << EOF

# Drupal optimization
maxmemory 256mb
maxmemory-policy allkeys-lru
tcp-keepalive 60
timeout 300
databases 16
EOF
    
    systemctl restart redis-server
    
    log "Redis настроен"
}

# Настройка PHP
configure_php() {
    log "Настройка PHP $PHP_VERSION для Drupal 11..."
    
    # Основные настройки PHP
    PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
    
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 1024M/' "$PHP_INI"
    sed -i 's/post_max_size = 8M/post_max_size = 1024M/' "$PHP_INI"
    sed -i 's/max_execution_time = 30/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/max_input_time = 60/max_input_time = 300/' "$PHP_INI"
    sed -i 's/memory_limit = 128M/memory_limit = 512M/' "$PHP_INI"
    sed -i 's/;max_input_vars = 1000/max_input_vars = 5000/' "$PHP_INI"
    
    # Настройка OPcache для Drupal
    cat >> "$PHP_INI" << EOF

; OPcache настройки для Drupal 11
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.save_comments=1
opcache.enable_cli=1
opcache.validate_timestamps=0
EOF
    
    # Настройка APCu
    cat >> "$PHP_INI" << EOF

; APCu настройки
apc.enabled=1
apc.shm_size=64M
apc.ttl=3600
apc.user_ttl=3600
apc.gc_ttl=3600
EOF
    
    # Настройка pool для Drupal
    cat > /etc/php/$PHP_VERSION/fpm/pool.d/drupal.conf << EOF
[drupal]
user = www-data
group = www-data
listen = /var/run/php/php$PHP_VERSION-fpm-drupal.sock
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
php_admin_value[upload_max_filesize] = 1024M
php_admin_value[post_max_size] = 1024M
php_admin_value[max_execution_time] = 300
EOF
    
    systemctl restart php$PHP_VERSION-fpm
    
    log "PHP настроен"
}

# Создание проекта Drupal
create_drupal_project() {
    log "Создание проекта Drupal 11..."
    
    # Создание директории проекта
    mkdir -p "$DRUPAL_ROOT"
    cd "$DRUPAL_ROOT"
    
    # Создание проекта через Composer
    composer create-project drupal/recommended-project . --no-interaction
    
    # Установка дополнительных модулей для библиотеки
    composer require \
        drupal/admin_toolbar \
        drupal/pathauto \
        drupal/token \
        drupal/views_bulk_operations \
        drupal/webform \
        drupal/metatag \
        drupal/redirect \
        drupal/backup_migrate \
        drupal/bootstrap_barrio \
        drupal/entity_reference_revisions \
        drupal/paragraphs \
        drupal/field_group \
        drupal/media_entity_download \
        drupal/search_api \
        drupal/facets \
        drupal/redis
    
    # Установка модулей для интеграции с Moodle
    composer require \
        drupal/external_auth \
        drupal/simplesamlphp_auth \
        drupal/ldap
    
    # Настройка прав доступа
    chown -R www-data:www-data "$DRUPAL_ROOT"
    chmod -R 755 "$DRUPAL_ROOT"
    
    log "Проект Drupal создан"
}

# Настройка Drupal
configure_drupal() {
    log "Настройка Drupal..."
    
    DB_PASSWORD=$(grep "Password:" /root/drupal-db-credentials.txt | cut -d' ' -f2)
    
    # Создание директории files и связывание с NAS
    mkdir -p "$DRUPAL_ROOT/web/sites/default/files"
    
    # Если NAS подключен, используем его для файлов
    if mountpoint -q /mnt/nas; then
        # Перемещаем существующие файлы в NAS (если есть)
        if [ "$(ls -A $DRUPAL_ROOT/web/sites/default/files)" ]; then
            cp -r "$DRUPAL_ROOT/web/sites/default/files"/* "$DRUPAL_FILES_NAS/" 2>/dev/null || true
        fi
        
        # Создаем символическую ссылку
        rm -rf "$DRUPAL_ROOT/web/sites/default/files"
        ln -sf "$DRUPAL_FILES_NAS" "$DRUPAL_ROOT/web/sites/default/files"
    fi
    
    # Создание settings.php
    cp "$DRUPAL_ROOT/web/sites/default/default.settings.php" "$DRUPAL_ROOT/web/sites/default/settings.php"
    
    # Базовые настройки в settings.php
    cat >> "$DRUPAL_ROOT/web/sites/default/settings.php" << EOF

// Database settings
\$databases['default']['default'] = [
  'database' => 'drupal_library',
  'username' => 'drupaluser',
  'password' => '$DB_PASSWORD',
  'prefix' => '',
  'host' => 'localhost',
  'port' => '5432',
  'namespace' => 'Drupal\\pgsql\\Driver\\Database\\pgsql',
  'driver' => 'pgsql',
  'autoload' => 'core/modules/pgsql/src/Driver/Database/pgsql/',
];

// Trusted host settings
\$settings['trusted_host_patterns'] = [
    '^$DRUPAL_DOMAIN\$',
    '^www\.$DRUPAL_DOMAIN\$',
];

// Hash salt
\$settings['hash_salt'] = '$(openssl rand -base64 55)';

// Redis cache configuration
\$settings['redis.connection']['interface'] = 'PhpRedis';
\$settings['redis.connection']['host'] = '127.0.0.1';
\$settings['redis.connection']['port'] = 6379;
\$settings['redis.connection']['base'] = 1;
\$settings['cache']['default'] = 'cache.backend.redis';
\$settings['cache']['bins']['bootstrap'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['discovery'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['config'] = 'cache.backend.chainedfast';

// File system paths
\$settings['file_public_path'] = 'sites/default/files';
\$settings['file_private_path'] = '/var/drupal-private';

// Performance settings
\$config['system.performance']['css']['preprocess'] = TRUE;
\$config['system.performance']['js']['preprocess'] = TRUE;

// Security settings
\$settings['omit_vary_cookie'] = TRUE;
\$settings['class_loader_auto_detect'] = FALSE;

// Environment indicator
\$config['environment_indicator.indicator']['bg_color'] = '#006600';
\$config['environment_indicator.indicator']['fg_color'] = '#ffffff';
\$config['environment_indicator.indicator']['name'] = 'Production';
EOF
    
    # Создание приватной директории
    mkdir -p /var/drupal-private
    chown www-data:www-data /var/drupal-private
    chmod 750 /var/drupal-private
    
    # Настройка прав доступа
    chown -R www-data:www-data "$DRUPAL_ROOT"
    chmod 644 "$DRUPAL_ROOT/web/sites/default/settings.php"
    
    log "Конфигурация Drupal создана"
}

# Установка Drupal через Drush
install_drupal_cli() {
    log "Установка Drupal через Drush..."
    
    cd "$DRUPAL_ROOT"
    
    sudo -u www-data drush site:install standard \
        --db-url="pgsql://drupaluser:$(grep "Password:" /root/drupal-db-credentials.txt | cut -d' ' -f2)@localhost:5432/drupal_library" \
        --site-name="$SITE_NAME" \
        --account-name="$ADMIN_USER" \
        --account-pass="$ADMIN_PASS" \
        --account-mail="$ADMIN_EMAIL" \
        --locale=ru \
        --yes
    
    # Включение необходимых модулей
    sudo -u www-data drush en -y \
        admin_toolbar admin_toolbar_tools \
        pathauto token views_bulk_operations \
        webform metatag redirect \
        bootstrap_barrio \
        paragraphs field_group \
        search_api facets \
        redis
    
    # Настройка темы
    sudo -u www-data drush theme:enable bootstrap_barrio
    sudo -u www-data drush config:set system.theme default bootstrap_barrio -y
    
    # Очистка кэша
    sudo -u www-data drush cr
    
    log "Drupal установлен через Drush"
}

# Настройка Nginx
configure_nginx() {
    log "Настройка Nginx для Drupal..."
    
    cat > /etc/nginx/sites-available/drupal << EOF
# Rate limiting
limit_req_zone \$binary_remote_addr zone=drupal:10m rate=10r/m;

server {
    listen 80;
    server_name $DRUPAL_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DRUPAL_DOMAIN;
    
    root $DRUPAL_ROOT/web;
    index index.php index.html;

    # SSL сертификаты (будут настроены автоматически)
    ssl_certificate /etc/letsencrypt/live/$DRUPAL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DRUPAL_DOMAIN/privkey.pem;
    
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
    client_max_body_size 1024M;
    
    # Rate limiting
    limit_req zone=drupal burst=20 nodelay;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm-drupal.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        
        # Продакшн настройки FastCGI
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_connect_timeout 300;
    }

    # Drupal специфичные правила
    location ~ /\.ht { deny all; }
    location ~ ^/sites/.*/private/ { return 403; }
    location ~ ^/sites/[^/]+/files/.*\.php\$ { deny all; }
    location ~* ^/.well-known/ { try_files \$uri =404; }
    location ~ ^/sites/.*/files/styles/ { try_files \$uri =404; }

    # Статические файлы
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    # Gzip сжатие
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Логирование
    access_log /var/log/nginx/drupal_access.log;
    error_log /var/log/nginx/drupal_error.log;
}
EOF
    
    # Включение сайта
    ln -sf /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/
    
    # Проверка конфигурации
    nginx -t
    systemctl restart nginx
    
    log "Nginx настроен"
}

# Получение SSL сертификата
setup_ssl() {
    log "Получение SSL сертификата Let's Encrypt..."
    
    # Временная конфигурация для получения сертификата
    cat > /etc/nginx/sites-available/drupal-temp << EOF
server {
    listen 80;
    server_name $DRUPAL_DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/drupal-temp /etc/nginx/sites-enabled/drupal
    systemctl reload nginx
    
    # Получение сертификата
    certbot certonly --nginx -d "$DRUPAL_DOMAIN" --non-interactive --agree-tos --email "$ADMIN_EMAIL"
    
    if [ $? -eq 0 ]; then
        log "SSL сертификат получен"
        # Восстановление основной конфигурации
        ln -sf /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/drupal
        systemctl reload nginx
        
        # Настройка автообновления сертификата
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'") | crontab -
    else
        warning "Не удалось получить SSL сертификат. Настройте его вручную."
        # Конфигурация без SSL
        cat > /etc/nginx/sites-available/drupal << EOF
server {
    listen 80;
    server_name $DRUPAL_DOMAIN;
    
    root $DRUPAL_ROOT/web;
    index index.php index.html;

    client_max_body_size 1024M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm-drupal.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht { deny all; }
    location ~ ^/sites/.*/private/ { return 403; }
    location ~ ^/sites/[^/]+/files/.*\.php\$ { deny all; }
}
EOF
        ln -sf /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/drupal
        systemctl reload nginx
    fi
}

# Настройка безопасности
setup_security() {
    log "Настройка безопасности системы..."
    
    # Настройка UFW (если еще не настроен)
    if ! ufw status | grep -q "Status: active"; then
        ufw --force enable
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow http
        ufw allow https
    fi
    
    # Настройка Fail2Ban для Drupal
    cat > /etc/fail2ban/jail.d/drupal.conf << EOF
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

[drupal-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/drupal_access.log
failregex = ^<HOST> .* "POST /user/login HTTP/.*" 200
maxretry = 5
bantime = 1800
findtime = 600
EOF
    
    systemctl restart fail2ban
    
    log "Безопасность настроена"
}

# Настройка мониторинга
setup_monitoring() {
    log "Настройка мониторинга Drupal..."
    
    # Создание скрипта мониторинга
    cat > /opt/drupal-monitor.sh << 'EOF'
#!/bin/bash
# Скрипт мониторинга Drupal

# Проверка сервисов
services=("nginx" "php8.3-fpm" "postgresql" "redis-server")
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "ALERT: $service is not running" | logger -t drupal-monitor
        systemctl restart "$service"
    fi
done

# Проверка доступности сайта
if ! curl -s -f http://localhost > /dev/null; then
    echo "ALERT: Drupal website is not responding" | logger -t drupal-monitor
fi

# Проверка места на диске
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    echo "ALERT: Disk usage is $disk_usage%" | logger -t drupal-monitor
fi

# Проверка NAS подключения
if ! mountpoint -q /mnt/nas; then
    echo "ALERT: NAS is not mounted" | logger -t drupal-monitor
    mount -a
fi

# Проверка Drupal статуса
cd /var/www/drupal
if ! sudo -u www-data drush status | grep -q "Connected"; then
    echo "WARNING: Drupal database connection issue" | logger -t drupal-monitor
fi
EOF
    
    chmod +x /opt/drupal-monitor.sh
    
    # Добавление в cron (если еще не добавлен)
    if ! crontab -l 2>/dev/null | grep -q "drupal-monitor"; then
        (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/drupal-monitor.sh") | crontab -
    fi
    
    log "Мониторинг настроен"
}

# Создание информационного файла
create_info_file() {
    log "Создание информационного файла..."
    
    cat > /root/drupal-production-info.txt << EOF
=== DRUPAL $DRUPAL_VERSION PRODUCTION INSTALLATION ===
Installation Date: $(date)
Server: $(hostname -I | awk '{print $1}')
Domain: $DRUPAL_DOMAIN

=== SYSTEM INFO ===
OS: $(lsb_release -d | cut -f2)
PHP Version: $PHP_VERSION
PostgreSQL: $(sudo -u postgres psql -c "SELECT version();" | head -3 | tail -1)
Nginx: $(nginx -v 2>&1)

=== PATHS ===
Drupal Root: $DRUPAL_ROOT
Drupal Files: $DRUPAL_ROOT/web/sites/default/files (NAS: $DRUPAL_FILES_NAS)
Private Files: /var/drupal-private
Configuration: $DRUPAL_ROOT/web/sites/default/settings.php
Logs: /var/log/nginx/drupal_*.log

=== CREDENTIALS ===
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASS
Admin Email: $ADMIN_EMAIL
Database Credentials: /root/drupal-db-credentials.txt

=== NAS INFO ===
NAS Host: $NAS_HOST
NAS Share: $NAS_SHARE
Mount Point: /mnt/nas
Files Location: $DRUPAL_FILES_NAS

=== SERVICES ===
$(systemctl is-active nginx) - Nginx
$(systemctl is-active php$PHP_VERSION-fpm) - PHP-FPM
$(systemctl is-active postgresql) - PostgreSQL
$(systemctl is-active redis-server) - Redis

=== SSL CERTIFICATE ===
$(if [ -f "/etc/letsencrypt/live/$DRUPAL_DOMAIN/fullchain.pem" ]; then echo "✓ SSL configured"; else echo "⚠ SSL not configured"; fi)

=== DRUPAL MODULES ===
$(cd "$DRUPAL_ROOT" && sudo -u www-data drush pm:list --type=module --status=enabled --format=list 2>/dev/null | head -10)

=== NEXT STEPS ===
1. Войдите в Drupal: https://$DRUPAL_DOMAIN/user/login
2. Настройте контент типы для библиотеки
3. Создайте таксономии и поля
4. Настройте поиск и фасеты
5. Настройте интеграцию с Moodle
6. Импортируйте контент

=== SUPPORT COMMANDS ===
Service Status: systemctl status nginx php$PHP_VERSION-fpm postgresql redis-server
Logs: tail -f /var/log/nginx/drupal_error.log
NAS Status: mountpoint /mnt/nas
Drupal CLI: cd $DRUPAL_ROOT && sudo -u www-data drush
Clear Cache: sudo -u www-data drush cr
Module Status: sudo -u www-data drush pm:list
EOF
    
    chmod 600 /root/drupal-production-info.txt
    
    # Сохранение учетных данных
    cat > /root/drupal-credentials.txt << EOF
=== DRUPAL CREDENTIALS ===
Admin URL: https://$DRUPAL_DOMAIN/user/login
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASS
Admin Email: $ADMIN_EMAIL

Database Connection:
Host: localhost
Database: drupal_library
User: drupaluser
Password: $(grep "Password:" /root/drupal-db-credentials.txt | cut -d' ' -f2)

NAS Connection:
Host: $NAS_HOST
Share: $NAS_SHARE
User: $NAS_USER
Mount: /mnt/nas

Drush Commands:
Status: drush status
Clear Cache: drush cr
Update Database: drush updb
List Modules: drush pm:list
EOF
    
    chmod 600 /root/drupal-credentials.txt
    
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
        log "✓ Drupal отвечает на запросы"
    else
        warning "⚠ Drupal может быть недоступен"
    fi
    
    # Проверка NAS
    if mountpoint -q /mnt/nas; then
        log "✓ NAS подключен"
    else
        warning "⚠ Проблемы с NAS подключением"
    fi
    
    # Проверка SSL
    if [ -f "/etc/letsencrypt/live/$DRUPAL_DOMAIN/fullchain.pem" ]; then
        log "✓ SSL сертификат установлен"
    else
        warning "⚠ SSL сертификат не установлен"
    fi
    
    # Проверка Drupal статуса
    cd "$DRUPAL_ROOT"
    if sudo -u www-data drush status | grep -q "Connected"; then
        log "✓ Drupal база данных подключена"
    else
        warning "⚠ Проблемы с подключением к базе данных"
    fi
    
    log "Финальная проверка завершена"
}

# Главная функция
main() {
    echo "========================================="
    echo "   Установка Drupal $DRUPAL_VERSION для RTTI (Production)"
    echo "========================================="
    
    check_root
    setup_configuration
    
    log "Начинаем установку Drupal для продакшн..."
    
    update_system
    install_software
    setup_nas_connection
    setup_postgresql
    setup_redis
    configure_php
    create_drupal_project
    configure_drupal
    install_drupal_cli
    configure_nginx
    setup_ssl
    setup_security
    setup_monitoring
    create_info_file
    final_check
    
    echo "========================================="
    log "Установка Drupal завершена!"
    echo "========================================="
    log "URL: https://$DRUPAL_DOMAIN"
    log "Администратор: $ADMIN_USER"
    log "Пароль: $ADMIN_PASS"
    log "Информация: /root/drupal-production-info.txt"
    log "Учетные данные: /root/drupal-credentials.txt"
    echo "========================================="
}

# Запуск установки
main "$@" 2>&1 | tee "$LOG_FILE"
