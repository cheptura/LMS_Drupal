#!/bin/bash

# LMS_Drupal - Moodle Installation Script
# Шаг 2: Установка веб-сервера (Nginx + PHP 8.3)
# Сервер: omuzgorpro.tj (92.242.60.172)
# Автор: cheptura (GitHub: https://github.com/cheptura/LMS_Drupal)
# Дата: $(date)
#
# ✅ ИНТЕГРИРОВАННЫЕ ИСПРАВЛЕНИЯ (2025-09-05):
# - Content Security Policy с 'unsafe-eval' для YUI framework
# - Обработчики font.php и image.php с PATH_INFO поддержкой
# - Все необходимые JavaScript/CSS handlers
# - Расширенная конфигурация PHP с OPcache оптимизацией
# - Автоматическая очистка старых версий PHP

set -e

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен от имени root"
   exit 1
fi

echo "🚀 LMS_Drupal - Установка веб-сервера для Moodle"
echo "================================================"
echo "Сервер: omuzgorpro.tj"
echo "Дата: $(date)"
echo

echo "1. Настройка часового пояса..."
# Настройка часового пояса для Таджикистана
timedatectl set-timezone Asia/Dushanbe
echo "   ✅ Часовой пояс установлен: $(timedatectl show --property=Timezone --value)"

echo "2. Установка Nginx..."
apt update
apt install -y nginx

echo "3. Удаление всех существующих версий PHP..."
# Сначала полностью очищаем систему от PHP
apt remove --purge -y php* 2>/dev/null || true
apt autoremove -y

echo "4. Добавление репозитория PHP..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "5. Установка ТОЛЬКО PHP 8.3 и всех необходимых расширений для Moodle..."
# Устанавливаем только конкретные пакеты PHP 8.3, БЕЗ метапакета php
# Список основан на официальных требованиях Moodle:

# REQUIRED extensions (обязательные):
apt install -y \
    php8.3-cli \
    php8.3-fpm \
    php8.3-common \
    php8.3-curl \
    php8.3-gd \
    php8.3-intl \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-zip \
    php8.3-pgsql \
    php8.3-mysql \
    php8.3-opcache

# RECOMMENDED extensions (рекомендуемые):
apt install -y \
    php8.3-soap \
    php8.3-xmlrpc \
    php8.3-ldap \
    php8.3-redis \
    php8.3-imagick \
    php8.3-bcmath \
    php8.3-exif \
    php8.3-imap

# Note: ctype, dom, iconv, json, pcre, simplexml, spl, tokenizer, openssl, sodium
# встроены в PHP 8.3 и не требуют отдельной установки

echo "6. Проверка и удаление случайно установленных других версий PHP..."
# Удаляем любые другие версии PHP, которые могли установиться как зависимости
apt remove --purge -y php8.0* php8.1* php8.2* php8.4* php7* 2>/dev/null || true
apt autoremove -y

echo "7. Установка PHP 8.3 как версии по умолчанию..."
update-alternatives --install /usr/bin/php php /usr/bin/php8.3 100
update-alternatives --set php /usr/bin/php8.3

echo "8. Закрепление PHP 8.3 от автоматических обновлений..."
# Закрепляем пакеты PHP 8.3, чтобы они не обновлялись автоматически до PHP 8.4
apt-mark hold php8.3-*

echo "9. Расширенная настройка PHP для Moodle..."
PHP_INI="/etc/php/8.3/fpm/php.ini"
PHP_CLI_INI="/etc/php/8.3/cli/php.ini"

# Создаем резервные копии с временной меткой
cp "$PHP_INI" "${PHP_INI}.backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
cp "$PHP_CLI_INI" "${PHP_CLI_INI}.backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true

# Функция для настройки PHP INI файла
configure_php_ini() {
    local ini_file=$1
    local file_type=$2
    echo "   🔧 Настройка $file_type: $ini_file"
    
    # Функция для установки или обновления параметра
    set_php_setting() {
        local setting=$1
        local value=$2
        local file=$3
        
        # Удаляем существующие настройки (закомментированные и активные)
        sed -i "/^;*\s*$setting\s*=/d" "$file"
        # Добавляем новую настройку
        echo "$setting = $value" >> "$file"
    }
    
    # Критические настройки для Moodle
    set_php_setting "max_execution_time" "300" "$ini_file"
    set_php_setting "max_input_time" "300" "$ini_file"
    set_php_setting "memory_limit" "512M" "$ini_file"
    set_php_setting "post_max_size" "100M" "$ini_file"
    set_php_setting "upload_max_filesize" "100M" "$ini_file"
    set_php_setting "max_input_vars" "5000" "$ini_file"
    
    # Настройка часового пояса
    set_php_setting "date.timezone" "Asia/Dushanbe" "$ini_file"
    
    # Настройки OPcache для производительности
    set_php_setting "opcache.enable" "1" "$ini_file"
    set_php_setting "opcache.memory_consumption" "256" "$ini_file"
    set_php_setting "opcache.max_accelerated_files" "10000" "$ini_file"
    set_php_setting "opcache.revalidate_freq" "2" "$ini_file"
    set_php_setting "opcache.save_comments" "1" "$ini_file"
    set_php_setting "opcache.enable_file_override" "1" "$ini_file"
    
    echo "   ✅ $file_type настроен"
}

# Настраиваем оба INI файла
configure_php_ini "$PHP_INI" "PHP-FPM"
configure_php_ini "$PHP_CLI_INI" "PHP CLI"

# Создаем директории conf.d если они не существуют
mkdir -p /etc/php/8.3/fpm/conf.d
mkdir -p /etc/php/8.3/cli/conf.d
mkdir -p /etc/php/8.3/conf.d

# Проверяем, что директория создана
if [ ! -d "/etc/php/8.3/conf.d" ]; then
    echo "❌ Не удалось создать директорию /etc/php/8.3/conf.d"
    exit 1
fi

# Дополнительная настройка через отдельный конфиг файл для гарантии
cat > /etc/php/8.3/conf.d/99-moodle-settings.ini << 'EOF'
; Moodle specific PHP settings
max_input_vars = 5000
max_execution_time = 300
memory_limit = 512M
post_max_size = 100M
upload_max_filesize = 100M

; Timezone setting for Tajikistan
date.timezone = Asia/Dushanbe

; OPcache settings for Moodle
opcache.enable = 1
opcache.memory_consumption = 256
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.save_comments = 1
opcache.enable_file_override = 1
EOF

# Создаем симлинки в FPM и CLI директориях для обеспечения единообразия
ln -sf /etc/php/8.3/conf.d/99-moodle-settings.ini /etc/php/8.3/fpm/conf.d/99-moodle-settings.ini 2>/dev/null || true
ln -sf /etc/php/8.3/conf.d/99-moodle-settings.ini /etc/php/8.3/cli/conf.d/99-moodle-settings.ini 2>/dev/null || true

echo "✅ Расширенные настройки PHP применены для FPM и CLI"

echo "10. Создание конфигурации Nginx для Moodle (с CSP и обработчиками font.php/image.php)..."
cat > /etc/nginx/sites-available/omuzgorpro.tj << 'NGINX_CONFIG'
server {
    listen 80;
    server_name omuzgorpro.tj;
    root /var/www/moodle;
    index index.php index.html index.htm;

    client_max_body_size 100M;
    client_body_timeout 300s;
    fastcgi_read_timeout 300s;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Main location
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP processing - ЕДИНЫЙ обработчик для всех PHP файлов включая Moodle handlers
    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        try_files $uri =404;
    }

    # Moodle dataroot protection
    location ^~ /dataroot/ {
        internal;
        alias /var/moodledata/;
    }

    # Security - deny access
    location ~ /\. {
        deny all;
    }

    location ~ /config\.php {
        deny all;
    }

    location ~ ^/(backup|local/temp|local/cache)/ {
        deny all;
    }
}
NGINX_CONFIG

echo "11. Активация сайта..."
ln -sf /etc/nginx/sites-available/omuzgorpro.tj /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "12. Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Ошибка в конфигурации Nginx!"
    exit 1
fi

echo "13. Запуск и включение автозапуска служб..."
systemctl enable nginx php8.3-fpm
systemctl start nginx php8.3-fpm

echo "14. Настройка firewall..."
ufw allow 'Nginx Full'

echo "15. Создание директории для сайта..."
mkdir -p /var/www/moodle
chown -R www-data:www-data /var/www/moodle

echo "16. Создание тестовой страницы..."
cat > /var/www/moodle/info.php << 'EOF'
<?php
echo "<h1>Moodle Server Status</h1>";
echo "<p><strong>Server:</strong> omuzgorpro.tj</p>";
echo "<p><strong>PHP Version:</strong> " . phpversion() . "</p>";
echo "<p><strong>Date:</strong> " . date('Y-m-d H:i:s') . "</p>";

// Check PHP extensions required for Moodle
$required_extensions = ['pgsql', 'xml', 'curl', 'gd', 'mbstring', 'zip', 'intl'];
echo "<h2>Required PHP Extensions:</h2>";
foreach ($required_extensions as $ext) {
    $status = extension_loaded($ext) ? "✅" : "❌";
    echo "<p>$status $ext</p>";
}
?>
EOF

echo "17. Перезапуск служб..."
systemctl restart nginx php8.3-fpm

echo "18. Проверка статуса..."
systemctl status nginx --no-pager -l
systemctl status php8.3-fpm --no-pager -l

echo "19. Финальная проверка версии PHP..."
echo "📋 Установленная версия PHP:"
php -v
echo
echo "📋 Установленные пакеты PHP 8.3:"
dpkg -l | grep php8.3 | head -10
echo
echo "📋 Проверка на наличие других версий PHP:"
dpkg -l | grep -E "php[0-9]" | grep -v php8.3 || echo "✅ Других версий PHP не найдено"

echo "20. Проверка критических настроек PHP для Moodle..."
echo "📊 Текущие настройки PHP:"
php -r "
echo 'max_execution_time = ' . ini_get('max_execution_time') . ' (требуется >= 300)' . PHP_EOL;
echo 'memory_limit = ' . ini_get('memory_limit') . ' (требуется >= 512M)' . PHP_EOL;
echo 'max_input_vars = ' . ini_get('max_input_vars') . ' (требуется >= 5000)' . PHP_EOL;
echo 'post_max_size = ' . ini_get('post_max_size') . ' (требуется >= 100M)' . PHP_EOL;
echo 'upload_max_filesize = ' . ini_get('upload_max_filesize') . ' (требуется >= 100M)' . PHP_EOL;
echo 'date.timezone = ' . ini_get('date.timezone') . ' (установлен)' . PHP_EOL;
echo 'opcache.enable = ' . (ini_get('opcache.enable') ? 'Включен' : 'Отключен') . PHP_EOL;
"

# Проверяем конкретно max_input_vars
MAX_INPUT_VARS=$(php -r "echo ini_get('max_input_vars');")
if [ "$MAX_INPUT_VARS" -ge 5000 ]; then
    echo "✅ max_input_vars = $MAX_INPUT_VARS (соответствует требованиям Moodle)"
else
    echo "❌ max_input_vars = $MAX_INPUT_VARS (недостаточно для Moodle, требуется >= 5000)"
fi

echo "21. Сохранение информации о PHP версии..."
cat > /root/moodle-php-info.txt << EOF
# Информация о PHP для Moodle
# Дата установки: $(date)
PHP_VERSION=8.3
PHP_FPM_SERVICE=php8.3-fpm
PHP_INI_PATH=/etc/php/8.3/fpm/php.ini
PHP_SOCKET_PATH=/var/run/php/php8.3-fpm.sock
EOF

echo "✅ Информация о PHP сохранена в /root/moodle-php-info.txt"

echo
echo "✅ Шаг 2 завершен успешно!"
echo "📌 Nginx и PHP 8.3 установлены и настроены"
echo "📌 Включены: CSP для YUI, обработчики font.php/image.php, расширенная PHP конфигурация"
echo "📌 Проверьте: http://omuzgorpro.tj/info.php"
echo "📌 Следующий шаг: ./03-install-database.sh"
echo
