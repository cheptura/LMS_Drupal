#!/bin/bash
# Скрипт установки Drupal 11 для облачного развертывания
# Поддержка: AWS, DigitalOcean, Google Cloud, Azure
# Usage: ./install-drupal-cloud.sh

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
DRUPAL_VERSION="11.0"
SITE_NAME="RTTI Digital Library"
DB_NAME="drupal_library"
DB_USER="drupaluser"
DB_HOST="localhost"
DRUPAL_ROOT="/var/www/drupal"
ADMIN_USER="admin"
DOMAIN="library.rtti.tj"  # Установлен конкретный домен
SERVER_IP="92.242.61.204"  # IP сервера библиотеки
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
    
    read -p "Введите домен для Drupal (например: library.example.com): " DOMAIN
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

# Установка PHP 8.3
install_php() {
    log "Установка PHP 8.3 для Drupal 11..."
    
    # Добавляем PPA для PHP
    add-apt-repository ppa:ondrej/php -y
    apt update
    
    # Установка PHP и расширений для Drupal 11
    apt install -y \
        php8.3 \
        php8.3-fpm \
        php8.3-cli \
        php8.3-mysql \
        php8.3-pgsql \
        php8.3-xml \
        php8.3-gd \
        php8.3-zip \
        php8.3-mbstring \
        php8.3-curl \
        php8.3-intl \
        php8.3-bcmath \
        php8.3-opcache \
        php8.3-apcu \
        php8.3-imagick \
        php8.3-uploadprogress \
        php8.3-xsl \
        php8.3-redis
    
    log "PHP 8.3 установлен"
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
    
    DB_PASSWORD=$(openssl rand -base64 32)
    
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;"
    
    # Сохраняем пароль
    echo "DB_PASSWORD=$DB_PASSWORD" >> /root/drupal-credentials.txt
    
    log "PostgreSQL настроен"
}

# Установка Redis
install_redis() {
    log "Установка Redis 7..."
    
    apt install -y redis-server
    
    # Настройка Redis для Drupal
    sed -i 's/^# maxmemory <bytes>/maxmemory 512mb/' /etc/redis/redis.conf
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

# Установка Node.js для сборки Drupal
install_nodejs() {
    log "Установка Node.js 20 для Drupal 11..."
    
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Проверяем версию
    node --version
    npm --version
    
    log "Node.js 20 установлен"
}

# Установка Drush
install_drush() {
    log "Установка Drush для Drupal 11..."
    
    # Устанавливаем Drush глобально
    composer global require drush/drush:^12
    
    # Добавляем в PATH
    echo 'export PATH="$HOME/.composer/vendor/bin:$PATH"' >> /root/.bashrc
    echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> /root/.bashrc
    
    # Создаем симлинк
    ln -sf /root/.config/composer/vendor/bin/drush /usr/local/bin/drush || \
    ln -sf /root/.composer/vendor/bin/drush /usr/local/bin/drush
    
    log "Drush установлен"
}

# Загрузка и установка Drupal
install_drupal() {
    log "Создание проекта Drupal $DRUPAL_VERSION..."
    
    # Создаем проект через Composer
    cd /var/www
    composer create-project drupal/recommended-project:^11 drupal --no-interaction
    
    cd drupal
    
    # Устанавливаем дополнительные модули
    composer require \
        drupal/admin_toolbar \
        drupal/pathauto \
        drupal/metatag \
        drupal/token \
        drupal/paragraphs \
        drupal/webform \
        drupal/search_api \
        drupal/facets \
        drupal/redis \
        drupal/backup_migrate \
        drupal/devel
    
    # Настройка прав доступа
    chown -R www-data:www-data /var/www/drupal
    chmod -R 755 /var/www/drupal
    
    # Создаем директории для файлов
    mkdir -p /var/www/drupal/web/sites/default/files
    chmod 777 /var/www/drupal/web/sites/default/files
    
    # Копируем настройки
    cp /var/www/drupal/web/sites/default/default.settings.php /var/www/drupal/web/sites/default/settings.php
    chmod 666 /var/www/drupal/web/sites/default/settings.php
    
    log "Drupal файлы установлены"
}

# Настройка Nginx для Drupal
configure_nginx() {
    log "Настройка Nginx для Drupal 11..."
    
    cat > "/etc/nginx/sites-available/drupal" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/drupal/web;
    index index.php index.html;

    client_max_body_size 1024M;

    # Основные правила Drupal
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP обработка
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

    # Drupal специфичные правила безопасности
    location ~ /\\.ht {
        deny all;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    location ~ ^/sites/[^/]+/files/.*\\.php\$ {
        deny all;
    }

    location ~* \\.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\\.php)?\$|xtmpl)\$|^(\\..*|Entries.*|Repository|Root|Tag|Template)\$|\\.php_ {
        deny all;
    }

    location ~ \\..*/.*\\.php\$ {
        return 403;
    }

    location ~ ^/sites/.*/files/styles/ {
        try_files \$uri @rewrite;
    }

    location ~ ^(/[a-z\\-]+)?/system/files/ {
        try_files \$uri /index.php?\$query_string;
    }

    location @rewrite {
        rewrite ^/(.*)\$ /index.php?q=\$1;
    }

    # Кэширование статических файлов
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|pdf)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
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
    access_log /var/log/nginx/drupal_access.log;
    error_log /var/log/nginx/drupal_error.log;
}
EOF
    
    # Включаем сайт
    ln -sf /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/
    
    # Проверяем конфигурацию
    nginx -t
    systemctl reload nginx
    
    log "Nginx настроен для Drupal"
}

# Настройка PHP для Drupal 11
configure_php() {
    log "Настройка PHP 8.3 для Drupal 11..."
    
    # Основные настройки PHP
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 1024M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 1024M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.3/fpm/php.ini
    sed -i 's/max_input_vars = .*/max_input_vars = 5000/' /etc/php/8.3/fpm/php.ini
    
    # Настройки временной зоны
    sed -i 's/;date.timezone =.*/date.timezone = Asia\/Dushanbe/' /etc/php/8.3/fpm/php.ini
    
    # Настройки OPcache
    cat >> /etc/php/8.3/fpm/conf.d/10-opcache.ini << EOF
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.validate_timestamps=0
opcache.save_comments=1
EOF

    # Настройки APCu
    cat >> /etc/php/8.3/fpm/conf.d/20-apcu.ini << EOF
apc.enabled=1
apc.shm_size=64M
apc.ttl=7200
apc.enable_cli=1
EOF
    
    # Настройка PHP-FPM pool для Drupal
    cat > /etc/php/8.3/fpm/pool.d/drupal.conf << EOF
[drupal]
user = www-data
group = www-data

listen = /var/run/php/php8.3-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Process management для облачных серверов
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 1000

; Resource limits
pm.process_idle_timeout = 60s
request_terminate_timeout = 300

; Logging
access.log = /var/log/php8.3-fpm-drupal-access.log
slowlog = /var/log/php8.3-fpm-drupal-slow.log
request_slowlog_timeout = 10s

; Security
security.limit_extensions = .php
EOF
    
    # Удаляем стандартный pool
    rm -f /etc/php/8.3/fpm/pool.d/www.conf
    
    systemctl restart php8.3-fpm
    
    log "PHP 8.3 настроен"
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

# Установка Drupal через Drush
install_drupal_site() {
    log "Установка Drupal сайта через Drush..."
    
    cd /var/www/drupal
    
    if [[ "$USE_CLOUD_DB" == "true" ]]; then
        DB_PASSWORD="$CLOUD_DB_PASS"
    else
        DB_PASSWORD=$(grep "DB_PASSWORD=" /root/drupal-credentials.txt | cut -d'=' -f2)
    fi
    
    # Генерируем пароль администратора
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    
    # Устанавливаем Drupal
    sudo -u www-data drush site:install standard \
        --db-url="pgsql://$DB_USER:$DB_PASSWORD@$DB_HOST/$DB_NAME" \
        --site-name="$SITE_NAME" \
        --account-name="$ADMIN_USER" \
        --account-pass="$ADMIN_PASSWORD" \
        --account-mail="admin@rtti.tj" \
        --yes
    
    # Сохраняем учетные данные
    echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> /root/drupal-credentials.txt
    echo "DRUPAL_URL=https://$DOMAIN" >> /root/drupal-credentials.txt
    
    log "Drupal сайт установлен"
}

# Настройка Drupal модулей и конфигурации
configure_drupal() {
    log "Настройка Drupal модулей..."
    
    cd /var/www/drupal
    
    # Включаем необходимые модули
    sudo -u www-data drush en -y \
        admin_toolbar \
        admin_toolbar_tools \
        pathauto \
        metatag \
        token \
        paragraphs \
        webform \
        search_api \
        facets \
        redis \
        devel
    
    # Настройка Redis кэширования
    cat >> /var/www/drupal/web/sites/default/settings.php << EOF

// Redis configuration
\$settings['redis.connection']['interface'] = 'PhpRedis';
\$settings['redis.connection']['host'] = '127.0.0.1';
\$settings['redis.connection']['port'] = 6379;
\$settings['redis.connection']['base'] = 1;
\$settings['cache']['default'] = 'cache.backend.redis';
\$settings['cache']['bins']['bootstrap'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['discovery'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['config'] = 'cache.backend.chainedfast';

// Trusted host settings для облачного развертывания
\$settings['trusted_host_patterns'] = [
    '^$DOMAIN\$',
    '^www\.$DOMAIN\$',
];

// File system settings
\$settings['file_scan_ignore_directories'] = [
    'node_modules',
    'bower_components',
];

// Конфигурация для облачного развертывания
\$config['system.performance']['cache']['page']['max_age'] = 3600;
\$config['system.performance']['css']['preprocess'] = TRUE;
\$config['system.performance']['js']['preprocess'] = TRUE;
EOF

    # Создаем типы контента для библиотеки
    sudo -u www-data drush php-eval "
// Создание словарей таксономии
\$vocabulary = \Drupal\taxonomy\Entity\Vocabulary::create([
  'vid' => 'book_categories',
  'name' => 'Book Categories',
  'description' => 'Categories for digital books',
]);
\$vocabulary->save();

\$vocabulary = \Drupal\taxonomy\Entity\Vocabulary::create([
  'vid' => 'book_subjects',  
  'name' => 'Book Subjects',
  'description' => 'Subject areas for digital books',
]);
\$vocabulary->save();

// Создание типа контента для книг
\$node_type = \Drupal\node\Entity\NodeType::create([
  'type' => 'digital_book',
  'name' => 'Digital Book',
  'description' => 'Content type for digital books in the library',
]);
\$node_type->save();
"
    
    # Очищаем кэш
    sudo -u www-data drush cr
    
    log "Drupal модули настроены"
}

# Настройка cron заданий
setup_cron() {
    log "Настройка cron заданий..."
    
    # Cron для Drupal
    echo "0 */3 * * * www-data /usr/local/bin/drush --root=/var/www/drupal/web cron >/dev/null 2>&1" >> /etc/crontab
    
    systemctl restart cron
    
    log "Cron задания настроены"
}

# Настройка мониторинга для облака
setup_cloud_monitoring() {
    log "Настройка облачного мониторинга..."
    
    # Создаем скрипт мониторинга
    cat > /opt/drupal-monitor.sh << 'EOF'
#!/bin/bash
# Простой мониторинг для облачного развертывания Drupal

LOG_FILE="/var/log/drupal-monitor.log"

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
check_service "php8.3-fpm"
check_service "postgresql"
check_service "redis-server"
check_disk_space

# Проверка доступности Drupal
if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200\|301\|302"; then
    echo "[$(date)] ERROR: Drupal is not responding" >> "$LOG_FILE"
fi
EOF
    
    chmod +x /opt/drupal-monitor.sh
    
    # Добавляем в cron
    echo "*/15 * * * * root /opt/drupal-monitor.sh" >> /etc/crontab
    
    log "Мониторинг настроен"
}

# Создание файла с информацией об установке
create_info_file() {
    log "Создание информационного файла..."
    
    cat > /root/drupal-installation-info.txt << EOF
=== DRUPAL 11 CLOUD INSTALLATION INFO ===
Installation Date: $(date)
Cloud Provider: $CLOUD_PROVIDER
Domain: https://$DOMAIN
Drupal Version: $DRUPAL_VERSION

=== SYSTEM INFO ===
OS: $(lsb_release -d | cut -f2)
PHP Version: $(php -v | head -n1)
Database: PostgreSQL $(psql --version | awk '{print $3}' 2>/dev/null || echo "Cloud Database")
Redis: $(redis-server --version | awk '{print $3}')
Node.js: $(node --version)

=== PATHS ===
Drupal Root: /var/www/drupal/web
Drupal Config: /var/www/drupal/web/sites/default/settings.php
Nginx Config: /etc/nginx/sites-available/drupal
PHP Config: /etc/php/8.3/fpm/php.ini

=== CREDENTIALS ===
Admin User: $ADMIN_USER
Admin URL: https://$DOMAIN/admin/
Database: $DB_NAME
DB User: $DB_USER

=== LOG FILES ===
Nginx Access: /var/log/nginx/drupal_access.log
Nginx Error: /var/log/nginx/drupal_error.log
PHP-FPM: /var/log/php8.3-fpm-drupal-slow.log
Drupal Monitor: /var/log/drupal-monitor.log

=== USEFUL COMMANDS ===
Drush: /usr/local/bin/drush --root=/var/www/drupal/web
Clear Cache: drush --root=/var/www/drupal/web cr
Update Database: drush --root=/var/www/drupal/web updb
Export Config: drush --root=/var/www/drupal/web cex
Import Config: drush --root=/var/www/drupal/web cim

=== DRUPAL MODULES ===
Core: Drupal 11 with Symfony 7
Installed Modules:
- Admin Toolbar
- Pathauto
- Metatag
- Token
- Paragraphs
- Webform
- Search API
- Facets
- Redis
- Devel

=== NEXT STEPS ===
1. Login to admin panel: https://$DOMAIN/user/login
2. Configure content types for digital books
3. Set up fields for book metadata
4. Configure search and facets
5. Import book content
6. Setup Moodle integration

EOF
    
    if [[ -f /root/drupal-credentials.txt ]]; then
        echo "=== PASSWORDS (KEEP SECURE) ===" >> /root/drupal-installation-info.txt
        cat /root/drupal-credentials.txt >> /root/drupal-installation-info.txt
    fi
    
    chmod 600 /root/drupal-installation-info.txt
    
    log "Информационный файл создан: /root/drupal-installation-info.txt"
}

# Финальная проверка
final_check() {
    log "Выполнение финальной проверки..."
    
    # Проверка сервисов
    services=("nginx" "php8.3-fpm" "redis-server")
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
        log "✓ Drupal отвечает на запросы"
    else
        warning "⚠ Drupal может быть недоступен"
    fi
    
    # Проверка Drush
    if sudo -u www-data /usr/local/bin/drush --root=/var/www/drupal/web status >/dev/null 2>&1; then
        log "✓ Drush работает корректно"
    else
        warning "⚠ Проблемы с Drush"
    fi
    
    log "Финальная проверка завершена"
}

# Главная функция
main() {
    echo "========================================"
    echo "   Установка Drupal 11 (Облако)       "
    echo "========================================"
    
    check_root
    detect_cloud_provider
    setup_config
    
    log "Начинаем установку Drupal $DRUPAL_VERSION на $CLOUD_PROVIDER"
    
    update_system
    install_php
    install_nginx
    install_database
    install_redis
    install_composer
    install_nodejs
    install_drush
    install_drupal
    configure_nginx
    configure_php
    install_drupal_site
    configure_drupal
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
    log "Установка Drupal 11 завершена!"
    echo "========================================"
    log "Сайт: https://$DOMAIN"
    log "Админ панель: https://$DOMAIN/user/login"
    log "Информация об установке: /root/drupal-installation-info.txt"
    echo "========================================"
}

# Запуск установки
main "$@"
