#!/bin/bash
# Скрипт миграции LMS из облака в продакшн с NAS
# Поддерживает перенос Moodle 5.0.2 и Drupal 11 с сохранением данных

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
CLOUD_SOURCE_HOST=""
CLOUD_SSH_KEY=""
CLOUD_SSH_USER="root"

PROD_MOODLE_ROOT="/var/www/moodle"
PROD_DRUPAL_ROOT="/var/www/drupal"
PROD_MOODLE_DATA="/var/moodledata"

NEW_MOODLE_DOMAIN=""
NEW_DRUPAL_DOMAIN=""

NAS_HOST=""
NAS_USER="backup"
NAS_SHARE="lms-backups"
NAS_MOUNT="/mnt/nas"

MIGRATION_DIR="/opt/migration"
LOG_FILE="/var/log/cloud-to-production-migration.log"

# Функция настройки параметров
setup_migration_config() {
    echo "=== Настройка параметров миграции ==="
    
    read -p "IP адрес облачного сервера Moodle: " CLOUD_MOODLE_HOST
    read -p "IP адрес облачного сервера Drupal: " CLOUD_DRUPAL_HOST
    read -p "Путь к SSH ключу для доступа к облачным серверам: " CLOUD_SSH_KEY
    
    if [[ ! -f "$CLOUD_SSH_KEY" ]]; then
        error "SSH ключ не найден: $CLOUD_SSH_KEY"
    fi
    
    read -p "Новый домен для Moodle (например: lms.rtti.tj): " NEW_MOODLE_DOMAIN
    read -p "Новый домен для Drupal (например: library.rtti.tj): " NEW_DRUPAL_DOMAIN
    
    read -p "IP адрес NAS сервера: " NAS_HOST
    read -p "Пользователь NAS: " NAS_USER
    
    log "Конфигурация миграции настроена"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен запускаться с правами root"
    fi
}

# Создание директорий для миграции
create_migration_directories() {
    log "Создание директорий для миграции..."
    
    mkdir -p "$MIGRATION_DIR"/{moodle,drupal,databases,configs}
    mkdir -p "$NAS_MOUNT"
    
    log "Директории созданы"
}

# Настройка NAS подключения
setup_nas_connection() {
    log "Настройка подключения к NAS..."
    
    # Установка CIFS утилит
    apt update
    apt install -y cifs-utils
    
    # Создание файла с учетными данными
    read -s -p "Пароль для пользователя NAS $NAS_USER: " nas_password
    echo
    
    cat > /etc/samba/migration-credentials << EOF
username=$NAS_USER
password=$nas_password
domain=rtti.local
EOF
    
    chmod 600 /etc/samba/migration-credentials
    
    # Монтирование NAS
    mount -t cifs "//$NAS_HOST/$NAS_SHARE" "$NAS_MOUNT" \
        -o credentials=/etc/samba/migration-credentials,uid=root,gid=root
    
    if [ $? -eq 0 ]; then
        log "NAS подключен успешно"
    else
        error "Ошибка подключения к NAS"
    fi
}

# Скачивание данных с облачного Moodle сервера
download_moodle_data() {
    log "Скачивание данных с облачного Moodle сервера..."
    
    # Создание backup на облачном сервере и скачивание
    ssh -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no "$CLOUD_SSH_USER@$CLOUD_MOODLE_HOST" << 'ENDSSH'
        # Включаем maintenance mode
        if [ -f /var/www/moodle/admin/cli/maintenance.php ]; then
            sudo -u www-data php /var/www/moodle/admin/cli/maintenance.php --enable
        fi
        
        # Создаем backup БД
        if systemctl is-active --quiet postgresql; then
            sudo -u postgres pg_dump moodle | gzip > /tmp/moodle_migration.sql.gz
        elif systemctl is-active --quiet mysql; then
            mysqldump --single-transaction moodle | gzip > /tmp/moodle_migration.sql.gz
        fi
        
        # Создаем backup файлов
        tar --exclude='*/cache/*' --exclude='*/temp/*' --exclude='*/sessions/*' \
            -czf /tmp/moodle_files.tar.gz /var/www/moodle /var/moodledata 2>/dev/null
        
        # Создаем backup конфигураций
        tar -czf /tmp/moodle_config.tar.gz \
            /etc/nginx/sites-available/moodle \
            /etc/php/8.2/fpm/pool.d/moodle.conf \
            /root/moodle-installation-info.txt \
            /root/moodle-credentials.txt 2>/dev/null
        
        # Отключаем maintenance mode
        if [ -f /var/www/moodle/admin/cli/maintenance.php ]; then
            sudo -u www-data php /var/www/moodle/admin/cli/maintenance.php --disable
        fi
ENDSSH
    
    # Скачиваем файлы
    scp -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no \
        "$CLOUD_SSH_USER@$CLOUD_MOODLE_HOST:/tmp/moodle_migration.sql.gz" \
        "$MIGRATION_DIR/databases/"
    
    scp -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no \
        "$CLOUD_SSH_USER@$CLOUD_MOODLE_HOST:/tmp/moodle_files.tar.gz" \
        "$MIGRATION_DIR/moodle/"
    
    scp -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no \
        "$CLOUD_SSH_USER@$CLOUD_MOODLE_HOST:/tmp/moodle_config.tar.gz" \
        "$MIGRATION_DIR/configs/"
    
    # Очищаем временные файлы на облачном сервере
    ssh -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no "$CLOUD_SSH_USER@$CLOUD_MOODLE_HOST" \
        "rm -f /tmp/moodle_*.tar.gz /tmp/moodle_migration.sql.gz"
    
    log "Данные Moodle скачаны"
}

# Скачивание данных с облачного Drupal сервера
download_drupal_data() {
    log "Скачивание данных с облачного Drupal сервера..."
    
    # Создание backup на облачном сервере и скачивание
    ssh -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no "$CLOUD_SSH_USER@$CLOUD_DRUPAL_HOST" << 'ENDSSH'
        cd /var/www/drupal
        
        # Включаем maintenance mode
        if command -v drush &> /dev/null; then
            sudo -u www-data drush state:set system.maintenance_mode 1
            sudo -u www-data drush cr
        fi
        
        # Создаем backup БД через Drush
        if command -v drush &> /dev/null; then
            sudo -u www-data drush sql:dump --gzip --result-file=/tmp/drupal_migration.sql.gz
        else
            # Fallback к прямому дампу
            if systemctl is-active --quiet postgresql; then
                sudo -u postgres pg_dump drupal_library | gzip > /tmp/drupal_migration.sql.gz
            elif systemctl is-active --quiet mysql; then
                mysqldump --single-transaction drupal_library | gzip > /tmp/drupal_migration.sql.gz
            fi
        fi
        
        # Создаем backup файлов
        tar --exclude='*/css/*' --exclude='*/js/*' --exclude='*/php/twig/*' \
            --exclude='*/tmp/*' --exclude='node_modules' --exclude='vendor' \
            -czf /tmp/drupal_files.tar.gz /var/www/drupal 2>/dev/null
        
        # Создаем backup конфигураций
        tar -czf /tmp/drupal_config.tar.gz \
            /etc/nginx/sites-available/drupal \
            /etc/php/8.3/fpm/pool.d/drupal.conf \
            /root/drupal-installation-info.txt \
            /root/drupal-credentials.txt 2>/dev/null
        
        # Отключаем maintenance mode
        if command -v drush &> /dev/null; then
            sudo -u www-data drush state:set system.maintenance_mode 0
            sudo -u www-data drush cr
        fi
ENDSSH
    
    # Скачиваем файлы
    scp -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no \
        "$CLOUD_SSH_USER@$CLOUD_DRUPAL_HOST:/tmp/drupal_migration.sql.gz" \
        "$MIGRATION_DIR/databases/"
    
    scp -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no \
        "$CLOUD_SSH_USER@$CLOUD_DRUPAL_HOST:/tmp/drupal_files.tar.gz" \
        "$MIGRATION_DIR/drupal/"
    
    scp -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no \
        "$CLOUD_SSH_USER@$CLOUD_DRUPAL_HOST:/tmp/drupal_config.tar.gz" \
        "$MIGRATION_DIR/configs/"
    
    # Очищаем временные файлы на облачном сервере
    ssh -i "$CLOUD_SSH_KEY" -o StrictHostKeyChecking=no "$CLOUD_SSH_USER@$CLOUD_DRUPAL_HOST" \
        "rm -f /tmp/drupal_*.tar.gz /tmp/drupal_migration.sql.gz"
    
    log "Данные Drupal скачаны"
}

# Установка и настройка продакшн сервера
setup_production_server() {
    log "Настройка продакшн сервера..."
    
    # Обновление системы
    export DEBIAN_FRONTEND=noninteractive
    apt update && apt upgrade -y
    
    # Установка необходимого ПО для обеих систем
    apt install -y \
        nginx \
        php8.2-fpm php8.2-cli php8.2-mysql php8.2-pgsql php8.2-xml php8.2-gd \
        php8.2-zip php8.2-mbstring php8.2-curl php8.2-intl php8.2-ldap \
        php8.2-soap php8.2-xmlrpc php8.2-opcache php8.2-redis php8.2-bcmath \
        php8.3-fpm php8.3-cli php8.3-mysql php8.3-pgsql php8.3-xml php8.3-gd \
        php8.3-zip php8.3-mbstring php8.3-curl php8.3-intl php8.3-bcmath \
        php8.3-opcache php8.3-apcu php8.3-imagick php8.3-xsl php8.3-redis \
        postgresql-16 postgresql-client-16 \
        redis-server \
        nodejs npm \
        git curl wget unzip
    
    # Установка Composer
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    
    # Установка Drush
    composer global require drush/drush:^12
    ln -sf /root/.config/composer/vendor/bin/drush /usr/local/bin/drush || \
    ln -sf /root/.composer/vendor/bin/drush /usr/local/bin/drush
    
    # Настройка временной зоны
    timedatectl set-timezone Asia/Dushanbe
    
    log "Продакшн сервер настроен"
}

# Настройка баз данных
setup_production_databases() {
    log "Настройка баз данных в продакшн..."
    
    systemctl start postgresql
    systemctl enable postgresql
    
    # Создание баз данных
    sudo -u postgres psql -c "CREATE DATABASE moodle;"
    sudo -u postgres psql -c "CREATE DATABASE drupal_library;"
    
    # Создание пользователей
    MOODLE_DB_PASS=$(openssl rand -base64 32)
    DRUPAL_DB_PASS=$(openssl rand -base64 32)
    
    sudo -u postgres psql -c "CREATE USER moodleuser WITH PASSWORD '$MOODLE_DB_PASS';"
    sudo -u postgres psql -c "CREATE USER drupaluser WITH PASSWORD '$DRUPAL_DB_PASS';"
    
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE moodle TO moodleuser;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE drupal_library TO drupaluser;"
    
    sudo -u postgres psql -c "ALTER USER moodleuser CREATEDB;"
    sudo -u postgres psql -c "ALTER USER drupaluser CREATEDB;"
    
    # Сохраняем пароли
    echo "MOODLE_DB_PASS=$MOODLE_DB_PASS" > /root/production-db-credentials.txt
    echo "DRUPAL_DB_PASS=$DRUPAL_DB_PASS" >> /root/production-db-credentials.txt
    chmod 600 /root/production-db-credentials.txt
    
    log "Базы данных настроены"
}

# Восстановление Moodle
restore_moodle() {
    log "Восстановление Moodle в продакшн..."
    
    # Создание директорий
    mkdir -p "$PROD_MOODLE_ROOT"
    mkdir -p "$PROD_MOODLE_DATA"
    
    # Распаковка файлов
    cd "$MIGRATION_DIR/moodle"
    tar -xzf moodle_files.tar.gz -C /
    
    # Восстановление БД
    MOODLE_DB_PASS=$(grep "MOODLE_DB_PASS=" /root/production-db-credentials.txt | cut -d'=' -f2)
    zcat "$MIGRATION_DIR/databases/moodle_migration.sql.gz" | \
        sudo -u postgres psql -d moodle
    
    # Обновление конфигурации Moodle
    cat > "$PROD_MOODLE_ROOT/config.php" << EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'pgsql';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'moodleuser';
\$CFG->dbpass    = '$MOODLE_DB_PASS';
\$CFG->prefix    = 'mdl_';

\$CFG->wwwroot   = 'https://$NEW_MOODLE_DOMAIN';
\$CFG->dataroot  = '$PROD_MOODLE_DATA';
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

\$CFG->passwordsaltmain = '$(openssl rand -base64 32)';

require_once(__DIR__ . '/lib/setup.php');
EOF
    
    # Настройка прав доступа
    chown -R www-data:www-data "$PROD_MOODLE_ROOT" "$PROD_MOODLE_DATA"
    chmod -R 755 "$PROD_MOODLE_ROOT"
    chmod -R 770 "$PROD_MOODLE_DATA"
    
    # Обновление URL в базе данных
    sudo -u postgres psql -d moodle -c "UPDATE mdl_config SET value = 'https://$NEW_MOODLE_DOMAIN' WHERE name = 'wwwroot';"
    
    log "Moodle восстановлен"
}

# Восстановление Drupal
restore_drupal() {
    log "Восстановление Drupal в продакшн..."
    
    # Создание директорий
    mkdir -p "$PROD_DRUPAL_ROOT"
    
    # Распаковка файлов
    cd "$MIGRATION_DIR/drupal"
    tar -xzf drupal_files.tar.gz -C /
    
    # Восстановление БД
    DRUPAL_DB_PASS=$(grep "DRUPAL_DB_PASS=" /root/production-db-credentials.txt | cut -d'=' -f2)
    zcat "$MIGRATION_DIR/databases/drupal_migration.sql.gz" | \
        sudo -u postgres psql -d drupal_library
    
    # Обновление конфигурации Drupal
    cd "$PROD_DRUPAL_ROOT"
    
    # Обновление settings.php
    cat >> web/sites/default/settings.php << EOF

// Продакшн настройки базы данных
\$databases['default']['default'] = [
  'database' => 'drupal_library',
  'username' => 'drupaluser',
  'password' => '$DRUPAL_DB_PASS',
  'prefix' => '',
  'host' => 'localhost',
  'port' => '5432',
  'namespace' => 'Drupal\\pgsql\\Driver\\Database\\pgsql',
  'driver' => 'pgsql',
  'autoload' => 'core/modules/pgsql/src/Driver/Database/pgsql/',
];

// Trusted host settings
\$settings['trusted_host_patterns'] = [
    '^$NEW_DRUPAL_DOMAIN\$',
    '^www\.$NEW_DRUPAL_DOMAIN\$',
];

// Hash salt
\$settings['hash_salt'] = '$(openssl rand -base64 55)';
EOF
    
    # Настройка прав доступа
    chown -R www-data:www-data "$PROD_DRUPAL_ROOT"
    chmod -R 755 "$PROD_DRUPAL_ROOT"
    chmod 777 "$PROD_DRUPAL_ROOT/web/sites/default/files"
    
    # Обновление базового URL через Drush
    sudo -u www-data drush --root="$PROD_DRUPAL_ROOT/web" \
        config:set system.site page.front /node/1
    
    sudo -u www-data drush --root="$PROD_DRUPAL_ROOT/web" cr
    
    log "Drupal восстановлен"
}

# Настройка Nginx для продакшн
configure_production_nginx() {
    log "Настройка Nginx для продакшн..."
    
    # Конфигурация Moodle
    cat > /etc/nginx/sites-available/moodle << EOF
server {
    listen 80;
    server_name $NEW_MOODLE_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $NEW_MOODLE_DOMAIN;
    
    root $PROD_MOODLE_ROOT;
    index index.php index.html;

    client_max_body_size 2048M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ [^/]\.php(/|\$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
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
    
    # SSL будет настроен позже
    # ssl_certificate /path/to/cert;
    # ssl_certificate_key /path/to/key;
}
EOF

    # Конфигурация Drupal
    cat > /etc/nginx/sites-available/drupal << EOF
server {
    listen 80;
    server_name $NEW_DRUPAL_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $NEW_DRUPAL_DOMAIN;
    
    root $PROD_DRUPAL_ROOT/web;
    index index.php index.html;

    client_max_body_size 1024M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
        fastcgi_read_timeout 300;
    }

    # Drupal специфичные правила
    location ~ /\.ht { deny all; }
    location ~ ^/sites/.*/private/ { return 403; }
    location ~ ^/sites/[^/]+/files/.*\.php\$ { deny all; }

    # SSL будет настроен позже
    # ssl_certificate /path/to/cert;
    # ssl_certificate_key /path/to/key;
}
EOF
    
    # Включение сайтов
    ln -sf /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
    ln -sf /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t
    systemctl restart nginx
    
    log "Nginx настроен"
}

# Копирование в NAS
copy_to_nas() {
    log "Копирование данных миграции в NAS..."
    
    # Создаем директорию для миграции в NAS
    mkdir -p "$NAS_MOUNT/migration-$(date +%Y%m%d)"
    
    # Копируем все файлы миграции
    cp -r "$MIGRATION_DIR"/* "$NAS_MOUNT/migration-$(date +%Y%m%d)/"
    
    # Создаем информационный файл
    cat > "$NAS_MOUNT/migration-$(date +%Y%m%d)/migration-info.txt" << EOF
=== MIGRATION INFO ===
Migration Date: $(date)
Source Moodle: $CLOUD_MOODLE_HOST
Source Drupal: $CLOUD_DRUPAL_HOST
Target Moodle Domain: $NEW_MOODLE_DOMAIN
Target Drupal Domain: $NEW_DRUPAL_DOMAIN
Migration Directory: $MIGRATION_DIR
NAS Location: $NAS_MOUNT/migration-$(date +%Y%m%d)

=== FILES MIGRATED ===
$(ls -la "$MIGRATION_DIR")

=== NEXT STEPS ===
1. Configure SSL certificates
2. Update DNS records
3. Test functionality
4. Setup backup schedule
5. Update monitoring
EOF
    
    log "Данные миграции скопированы в NAS"
}

# Настройка продакшн бэкапа с NAS
setup_production_backup() {
    log "Настройка продакшн системы резервного копирования..."
    
    # Копируем скрипт продакшн бэкапа
    if [ -f "../production-deployment/nas-backup.sh" ]; then
        cp "../production-deployment/nas-backup.sh" /opt/
        chmod +x /opt/nas-backup.sh
        
        # Настраиваем cron для бэкапа
        cat >> /etc/crontab << EOF
# LMS Production Backup Schedule
0 2 * * * root /opt/nas-backup.sh daily >> /var/log/lms-backup.log 2>&1
0 3 * * 0 root /opt/nas-backup.sh weekly >> /var/log/lms-backup.log 2>&1
0 4 1 * * root /opt/nas-backup.sh monthly >> /var/log/lms-backup.log 2>&1
EOF
        
        systemctl restart cron
        log "Система резервного копирования настроена"
    else
        warning "Скрипт продакшн бэкапа не найден"
    fi
}

# Финальная проверка
final_migration_check() {
    log "Выполнение финальной проверки миграции..."
    
    # Проверка сервисов
    services=("nginx" "php8.2-fpm" "php8.3-fpm" "postgresql" "redis-server")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✓ $service работает"
        else
            error "✗ $service не работает"
        fi
    done
    
    # Проверка доступности сайтов
    if curl -s -o /dev/null "http://localhost" -H "Host: $NEW_MOODLE_DOMAIN"; then
        log "✓ Moodle отвечает на запросы"
    else
        warning "⚠ Moodle может быть недоступен"
    fi
    
    if curl -s -o /dev/null "http://localhost" -H "Host: $NEW_DRUPAL_DOMAIN"; then
        log "✓ Drupal отвечает на запросы"
    else
        warning "⚠ Drupal может быть недоступен"
    fi
    
    # Проверка NAS подключения
    if mountpoint -q "$NAS_MOUNT"; then
        log "✓ NAS подключен"
    else
        warning "⚠ Проблемы с NAS подключением"
    fi
    
    log "Финальная проверка завершена"
}

# Создание отчета о миграции
create_migration_report() {
    log "Создание отчета о миграции..."
    
    cat > /root/migration-report.txt << EOF
=== LMS CLOUD TO PRODUCTION MIGRATION REPORT ===
Migration Date: $(date)
Migration Status: COMPLETED

=== SOURCE SYSTEMS ===
Moodle Cloud Server: $CLOUD_MOODLE_HOST
Drupal Cloud Server: $CLOUD_DRUPAL_HOST

=== TARGET SYSTEMS ===
Moodle Production Domain: $NEW_MOODLE_DOMAIN
Drupal Production Domain: $NEW_DRUPAL_DOMAIN
Production Server: $(hostname -I | awk '{print $1}')

=== MIGRATED DATA ===
Moodle Database: $(du -h "$MIGRATION_DIR/databases/moodle_migration.sql.gz" | cut -f1)
Drupal Database: $(du -h "$MIGRATION_DIR/databases/drupal_migration.sql.gz" | cut -f1)
Moodle Files: $(du -h "$MIGRATION_DIR/moodle/moodle_files.tar.gz" | cut -f1)
Drupal Files: $(du -h "$MIGRATION_DIR/drupal/drupal_files.tar.gz" | cut -f1)

=== SYSTEM STATUS ===
$(systemctl is-active nginx) - Nginx
$(systemctl is-active php8.2-fpm) - PHP 8.2 FPM (Moodle)
$(systemctl is-active php8.3-fpm) - PHP 8.3 FPM (Drupal)
$(systemctl is-active postgresql) - PostgreSQL
$(systemctl is-active redis-server) - Redis

=== NAS BACKUP LOCATION ===
$NAS_MOUNT/migration-$(date +%Y%m%d)

=== IMMEDIATE TASKS ===
1. Configure SSL certificates for both domains
2. Update DNS records to point to production server
3. Test all functionality thoroughly
4. Setup monitoring and alerting
5. Train administrators on new environment

=== CREDENTIALS ===
See /root/production-db-credentials.txt for database passwords
Original cloud credentials backed up in migration data

=== SUPPORT INFO ===
Migration Log: $LOG_FILE
Migration Data: $MIGRATION_DIR
Configuration Backups: $MIGRATION_DIR/configs/
EOF
    
    chmod 600 /root/migration-report.txt
    
    log "Отчет о миграции создан: /root/migration-report.txt"
}

# Главная функция
main() {
    echo "========================================"
    echo "   Миграция LMS: Облако → Продакшн     "
    echo "========================================"
    
    check_root
    setup_migration_config
    create_migration_directories
    setup_nas_connection
    
    log "Начинаем миграцию из облака в продакшн..."
    
    download_moodle_data
    download_drupal_data
    setup_production_server
    setup_production_databases
    restore_moodle
    restore_drupal
    configure_production_nginx
    copy_to_nas
    setup_production_backup
    final_migration_check
    create_migration_report
    
    echo "========================================"
    log "Миграция LMS завершена!"
    echo "========================================"
    log "Moodle: http://$NEW_MOODLE_DOMAIN (настройте SSL)"
    log "Drupal: http://$NEW_DRUPAL_DOMAIN (настройте SSL)"
    log "Отчет: /root/migration-report.txt"
    log "NAS backup: $NAS_MOUNT/migration-$(date +%Y%m%d)"
    echo "========================================"
    warning "ВАЖНО: Настройте SSL сертификаты и обновите DNS записи"
}

# Запуск миграции
main "$@"
