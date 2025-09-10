#!/bin/bash

# RTTI Drupal - Комплексное исправление проблем после установки
# Исправляет: Nginx gzip дубликаты, OPcache, порты, сервисы
# Дата: $(date)

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║            RTTI Drupal - Комплексное исправление проблем                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./fix-all-issues.sh"
    exit 1
fi

LOG_FILE="/var/log/drupal-fix-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

echo "📋 Лог исправлений: $LOG_FILE"
echo

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

PHP_VERSION="8.3"
DOMAIN="storage.omuzgorpro.tj"
DRUPAL_DIR="/var/www/drupal"

print_header "1. Исправление проблемы с дублирующимися директивами gzip в Nginx"

# Проверяем проблему с gzip
if nginx -t 2>&1 | grep -q "gzip.*duplicate"; then
    print_error "Найдена проблема с дублирующимися директивами gzip"
    
    PERFORMANCE_CONF="/etc/nginx/conf.d/drupal-performance.conf"
    
    if [ -f "$PERFORMANCE_CONF" ]; then
        print_info "Исправляем файл: $PERFORMANCE_CONF"
        
        # Резервная копия
        cp "$PERFORMANCE_CONF" "$PERFORMANCE_CONF.backup.$(date +%Y%m%d-%H%M%S)"
        
        # Создаем исправленный файл без дублирующихся gzip директив
        cat > "$PERFORMANCE_CONF" << 'EOF'
# Drupal Performance Configuration - Fixed
client_max_body_size 100M;
client_body_timeout 60s;
client_header_timeout 60s;
keepalive_timeout 65s;
send_timeout 60s;

client_body_buffer_size 128k;
client_header_buffer_size 4k;
large_client_header_buffers 4 8k;
output_buffers 2 32k;

fastcgi_cache_path /var/cache/nginx/drupal levels=1:2 keys_zone=drupal:10m max_size=1g inactive=60m use_temp_path=off;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_use_stale error timeout invalid_header updating http_500 http_503;
fastcgi_cache_valid 200 301 302 1h;
fastcgi_cache_valid 404 1m;

add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;

location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
}

location ~ ^/sites/.*/files/styles/ {
    try_files $uri $uri/ @rewrite;
}

location ~ ^(/[a-z\-]+)?/system/files/ {
    try_files $uri $uri/ /index.php?$query_string;
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
EOF
        
        print_success "Файл $PERFORMANCE_CONF исправлен"
    fi
else
    print_success "Проблем с дублирующимися gzip директивами не найдено"
fi

print_header "2. Установка и настройка OPcache"

if ! php -m | grep -q "Zend OPcache"; then
    print_info "Устанавливаем OPcache..."
    apt update -qq
    apt install -y php${PHP_VERSION}-opcache
    
    if [ $? -eq 0 ]; then
        print_success "OPcache установлен"
    else
        print_error "Ошибка установки OPcache"
    fi
else
    print_success "OPcache уже установлен"
fi

# Настраиваем OPcache
OPCACHE_CONF="/etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini"
print_info "Настраиваем OPcache..."

cat > "$OPCACHE_CONF" << 'EOF'
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.max_wasted_percentage=5
opcache.validate_timestamps=1
opcache.revalidate_freq=2
opcache.save_comments=1
opcache.fast_shutdown=1
opcache.huge_code_pages=1
EOF

print_success "OPcache настроен"

print_header "3. Проверка и исправление PHP-FPM пула"

# Проверяем пул drupal
POOL_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/drupal.conf"
if [ ! -f "$POOL_CONF" ]; then
    print_warning "Пул drupal не найден, создаем..."
    
    cat > "$POOL_CONF" << EOF
[drupal]
user = www-data
group = www-data
listen = /run/php/php${PHP_VERSION}-fpm-drupal.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 1000
php_admin_value[error_log] = /var/log/php-fpm-drupal.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path] = /var/lib/php/sessions
php_value[soap.wsdl_cache_dir] = /var/lib/php/wsdlcache
EOF
    
    print_success "Пул drupal создан"
else
    print_success "Пул drupal существует"
fi

print_header "4. Проверка и создание директорий кеша"

# Создаем директорию для Nginx кеша
mkdir -p /var/cache/nginx/drupal
chown -R www-data:www-data /var/cache/nginx/drupal
chmod -R 755 /var/cache/nginx/drupal
print_success "Директория кеша Nginx создана"

# Создаем директории для PHP сессий
mkdir -p /var/lib/php/sessions
mkdir -p /var/lib/php/wsdlcache
chown -R www-data:www-data /var/lib/php/sessions /var/lib/php/wsdlcache
chmod -R 733 /var/lib/php/sessions
chmod -R 755 /var/lib/php/wsdlcache
print_success "Директории PHP сессий созданы"

print_header "5. Настройка файрвола"

# Проверяем UFW
if command -v ufw >/dev/null 2>&1; then
    print_info "Настраиваем файрвол..."
    
    # Разрешаем основные порты
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Разрешаем локальные соединения для баз данных
    ufw allow from 127.0.0.1 to any port 5432 comment 'PostgreSQL local'
    ufw allow from 127.0.0.1 to any port 6379 comment 'Redis local'
    
    print_success "Файрвол настроен"
else
    print_warning "UFW не установлен"
fi

print_header "6. Перезапуск сервисов"

# Перезапускаем сервисы в правильном порядке
SERVICES=("php${PHP_VERSION}-fpm" "nginx" "postgresql" "redis")

for service in "${SERVICES[@]}"; do
    print_info "Перезапускаем $service..."
    
    if systemctl restart "$service"; then
        if systemctl is-active --quiet "$service"; then
            print_success "$service: перезапущен и активен"
        else
            print_error "$service: перезапущен, но не активен"
            systemctl status "$service" --no-pager -l
        fi
    else
        print_error "$service: ошибка перезапуска"
        systemctl status "$service" --no-pager -l
    fi
done

print_header "7. Финальная проверка"

# Тестируем конфигурацию Nginx
if nginx -t; then
    print_success "Конфигурация Nginx корректна"
else
    print_error "Ошибки в конфигурации Nginx"
    nginx -t
fi

# Проверяем OPcache
if php -r "exit(extension_loaded('Zend OPcache') ? 0 : 1);"; then
    print_success "OPcache загружен"
else
    print_error "OPcache не загружен"
fi

# Проверяем порты
print_info "Проверяем открытые порты:"
netstat -tlnp | grep ':80\|:443\|:5432\|:6379' | while read line; do
    port=$(echo $line | awk '{print $4}' | cut -d: -f2)
    case $port in
        80) print_success "HTTP (80): открыт" ;;
        443) print_success "HTTPS (443): открыт" ;;
        5432) print_success "PostgreSQL (5432): открыт" ;;
        6379) print_success "Redis (6379): открыт" ;;
    esac
done

# Проверяем статус сервисов
print_info "Статус сервисов:"
for service in nginx php${PHP_VERSION}-fpm postgresql redis; do
    if systemctl is-active --quiet $service; then
        print_success "$service: активен"
    else
        print_error "$service: не активен"
    fi
done

print_header "8. Тестирование веб-сервера"

# Тест HTTP соединения
if curl -s -I http://localhost | grep -q "HTTP"; then
    print_success "HTTP сервер отвечает"
else
    print_warning "HTTP сервер не отвечает"
fi

# Тест HTTPS соединения (если есть сертификат)
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    if curl -s -I -k https://localhost | grep -q "HTTP"; then
        print_success "HTTPS сервер отвечает"
    else
        print_warning "HTTPS сервер не отвечает"
    fi
fi

print_header "Результаты исправления"

echo
print_success "Все исправления применены!"
echo
print_info "Проверьте Drupal сайт:"
echo "   - HTTP: http://$DOMAIN"
echo "   - HTTPS: https://$DOMAIN"
echo
print_info "Логи для диагностики:"
echo "   - Nginx: /var/log/nginx/error.log"
echo "   - PHP-FPM: /var/log/php${PHP_VERSION}-fpm.log"
echo "   - Drupal: $DRUPAL_DIR/web/sites/default/files/logs/"
echo "   - Этот лог: $LOG_FILE"
echo
print_info "Команды для проверки:"
echo "   - Статус сервисов: systemctl status nginx php${PHP_VERSION}-fpm"
echo "   - Конфигурация Nginx: nginx -t"
echo "   - OPcache статус: php -r 'var_dump(opcache_get_status());'"
echo "   - Открытые порты: netstat -tlnp | grep ':80\\|:443'"
echo
print_success "Исправление завершено успешно!"
