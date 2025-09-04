#!/bin/bash

# LMS_Drupal - Moodle Installation Script
# Шаг 2: Установка веб-сервера (Nginx + PHP 8.3)
# Сервер: lms.rtti.tj (92.242.60.172)
# Автор: cheptura (GitHub: https://github.com/cheptura/LMS_Drupal)
# Дата: $(date)

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
    php8.3-sodium \
    php8.3-xmlrpc \
    php8.3-ldap \
    php8.3-redis \
    php8.3-imagick \
    php8.3-bcmath \
    php8.3-exif \
    php8.3-imap

# Note: ctype, dom, iconv, json, pcre, simplexml, spl, tokenizer, openssl
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
cp $PHP_INI ${PHP_INI}.backup

# Настройки производительности для Moodle
sed -i 's/^max_execution_time = 30/max_execution_time = 300/' $PHP_INI
sed -i 's/^max_input_time = 60/max_input_time = 300/' $PHP_INI
sed -i 's/^memory_limit = 128M/memory_limit = 512M/' $PHP_INI
sed -i 's/^post_max_size = 8M/post_max_size = 100M/' $PHP_INI
sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 100M/' $PHP_INI
sed -i 's/^;max_input_vars = 1000/max_input_vars = 5000/' $PHP_INI
sed -i 's/^;opcache.enable=1/opcache.enable=1/' $PHP_INI
sed -i 's/^;opcache.memory_consumption=128/opcache.memory_consumption=256/' $PHP_INI

echo "9. Создание конфигурации Nginx для Moodle..."
cat > /etc/nginx/sites-available/lms.rtti.tj << 'EOF'
server {
    listen 80;
    server_name lms.rtti.tj;
    root /var/www/html/moodle;
    index index.php index.html index.htm;

    client_max_body_size 100M;
    client_body_timeout 300s;
    fastcgi_read_timeout 300s;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Moodle specific locations
    location ^~ /dataroot/ {
        internal;
        alias /var/moodledata/;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
    }

    # Block access to config files
    location ~ /config\.php {
        deny all;
    }

    # Block access to upgrade script
    location ~ /admin/tool/installaddon/ {
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
mkdir -p /var/www/html/moodle
chown -R www-data:www-data /var/www/html/moodle

echo "15. Создание тестовой страницы..."
cat > /var/www/html/moodle/info.php << 'EOF'
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
echo "📌 Проверьте: http://lms.rtti.tj/info.php"
echo "📌 Следующий шаг: ./03-install-database.sh"
echo
