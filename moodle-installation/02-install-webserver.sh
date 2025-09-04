#!/bin/bash

# LMS_Drupal - Moodle Installation Script
# Шаг 2: Установка веб-сервера (Nginx + PHP 8.3)
# Сервер: lms.rtti.tj (92.242.60.172)
# Автор: cheptura (GitHub: https://github.com/cheptura/LMS_Drupal)
# Дата: $(date)
#
# ✅ ИНТЕГРИРОВАННЫЕ ИСПРАВЛЕНИЯ (2025-01-02):
# - Content Security Policy с 'unsafe-eval' для YUI framework
# - Обработчики font.php и image.php с PATH_INFO поддержкой
# - Все необходимые JavaScript/CSS handlers

set -e

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен от имени root"
   exit 1
fi

echo "🚀 LMS_Drupal - Установка веб-сервера для Moodle"
echo "================================================"
echo "Сервер: lms.rtti.tj"
echo "Дата: $(date)"
echo

echo "1. Установка Nginx..."
apt update
apt install -y nginx

echo "2. Удаление всех существующих версий PHP..."
# Сначала полностью очищаем систему от PHP
apt remove --purge -y php* 2>/dev/null || true
apt autoremove -y

echo "3. Добавление репозитория PHP..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "4. Установка ТОЛЬКО PHP 8.3 и всех необходимых расширений для Moodle..."
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

echo "5. Проверка и удаление случайно установленных других версий PHP..."
# Удаляем любые другие версии PHP, которые могли установиться как зависимости
apt remove --purge -y php8.0* php8.1* php8.2* php8.4* php7* 2>/dev/null || true
apt autoremove -y

echo "6. Установка PHP 8.3 как версии по умолчанию..."
update-alternatives --install /usr/bin/php php /usr/bin/php8.3 100
update-alternatives --set php /usr/bin/php8.3

echo "7. Закрепление PHP 8.3 от автоматических обновлений..."
# Закрепляем пакеты PHP 8.3, чтобы они не обновлялись автоматически до PHP 8.4
apt-mark hold php8.3-*

echo "8. Оптимизация настроек PHP для Moodle..."
PHP_INI="/etc/php/8.3/fpm/php.ini"
PHP_CLI_INI="/etc/php/8.3/cli/php.ini"

# Создаем резервные копии
cp $PHP_INI ${PHP_INI}.backup
cp $PHP_CLI_INI ${PHP_CLI_INI}.backup

# Функция для настройки PHP INI файла
configure_php_ini() {
    local ini_file=$1
    echo "Настройка $ini_file..."
    
    # Настройки производительности для Moodle
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' $ini_file
    sed -i 's/^max_input_time = .*/max_input_time = 300/' $ini_file
    sed -i 's/^memory_limit = .*/memory_limit = 512M/' $ini_file
    sed -i 's/^post_max_size = .*/post_max_size = 100M/' $ini_file
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 100M/' $ini_file
    
    # Обрабатываем max_input_vars (может быть закомментирован или уже установлен)
    if grep -q "^max_input_vars" $ini_file; then
        sed -i 's/^max_input_vars = .*/max_input_vars = 5000/' $ini_file
    elif grep -q "^;max_input_vars" $ini_file; then
        sed -i 's/^;max_input_vars = .*/max_input_vars = 5000/' $ini_file
    else
        echo "max_input_vars = 5000" >> $ini_file
    fi
    
    # Настройки OPcache
    if grep -q "^opcache.enable" $ini_file; then
        sed -i 's/^opcache.enable=.*/opcache.enable=1/' $ini_file
    elif grep -q "^;opcache.enable" $ini_file; then
        sed -i 's/^;opcache.enable=.*/opcache.enable=1/' $ini_file
    else
        echo "opcache.enable=1" >> $ini_file
    fi
    
    if grep -q "^opcache.memory_consumption" $ini_file; then
        sed -i 's/^opcache.memory_consumption=.*/opcache.memory_consumption=256/' $ini_file
    elif grep -q "^;opcache.memory_consumption" $ini_file; then
        sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=256/' $ini_file
    else
        echo "opcache.memory_consumption=256" >> $ini_file
    fi
}

# Настраиваем оба INI файла
configure_php_ini $PHP_INI
configure_php_ini $PHP_CLI_INI

echo "✅ Настройки PHP применены для FPM и CLI"

echo "9. Создание конфигурации Nginx для Moodle (с CSP и обработчиками font.php/image.php)..."
cat > /etc/nginx/sites-available/lms.rtti.tj << 'EOF'
server {
    listen 80;
    server_name lms.rtti.tj;
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

    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }

        # Moodle JavaScript handler with path info
    location ~ ^(/lib/javascript\.php)(/.*)?$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$1;
        fastcgi_param PATH_INFO \$2;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle CSS handler with path info
    location ~ ^(/theme/styles\.php)(/.*)?$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$1;
        fastcgi_param PATH_INFO \$2;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle YUI combo handler with path info  
    location ~ ^(/theme/yui_combo\.php)(/.*)?$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$1;
        fastcgi_param PATH_INFO \$2;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle pluginfile handler
    location ~ ^/pluginfile\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Moodle font.php handler
    location ~ ^/font\.php/(.+)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root/font.php;
        fastcgi_param PATH_INFO $1;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Moodle image.php handler  
    location ~ ^/image\.php/(.+)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root/image.php;
        fastcgi_param PATH_INFO $1;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Moodle dataroot protection
    location ^~ /dataroot/ {
        internal;
        alias /var/moodledata/;
    }

    # Static files caching (real static files)
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        try_files $uri =404;
    }

    # Block access to config files
    location ~ /config\.php {
        deny all;
    }

    # Block access to upgrade script during normal operation
    location ~ /admin/tool/installaddon/ {
        deny all;
    }

    # Block access to various Moodle internal paths
    location ~ ^/(backup|local/temp|local/cache)/ {
        deny all;
    }

    # Allow .htaccess for Apache compatibility (though we're using Nginx)
    location ~ /\.htaccess {
        deny all;
    }
}
EOF

echo "10. Активация сайта..."
ln -sf /etc/nginx/sites-available/lms.rtti.tj /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "11. Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Ошибка в конфигурации Nginx!"
    exit 1
fi

echo "12. Запуск и включение автозапуска служб..."
systemctl enable nginx php8.3-fpm
systemctl start nginx php8.3-fpm

echo "13. Настройка firewall..."
ufw allow 'Nginx Full'

echo "14. Создание директории для сайта..."
mkdir -p /var/www/moodle
chown -R www-data:www-data /var/www/moodle

echo "15. Создание тестовой страницы..."
cat > /var/www/moodle/info.php << 'EOF'
<?php
echo "<h1>Moodle Server Status</h1>";
echo "<p><strong>Server:</strong> lms.rtti.tj</p>";
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

echo "16. Перезапуск служб..."
systemctl restart nginx php8.3-fpm

echo "17. Проверка статуса..."
systemctl status nginx --no-pager -l
systemctl status php8.3-fpm --no-pager -l

echo "18. Финальная проверка версии PHP..."
echo "📋 Установленная версия PHP:"
php -v
echo
echo "📋 Установленные пакеты PHP 8.3:"
dpkg -l | grep php8.3 | head -10
echo
echo "📋 Проверка на наличие других версий PHP:"
dpkg -l | grep -E "php[0-9]" | grep -v php8.3 || echo "✅ Других версий PHP не найдено"

echo "19. Сохранение информации о PHP версии..."
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
echo "📌 Включены: CSP для YUI, обработчики font.php/image.php"
echo "📌 Проверьте: http://lms.rtti.tj/info.php"
echo "📌 Следующий шаг: ./03-install-database.sh"
echo
