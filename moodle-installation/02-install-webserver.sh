#!/bin/bash

# RTTI Moodle - Шаг 2: Установка веб-сервера
# Сервер: lms.rtti.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 2: Установка веб-сервера ==="
echo "🎓 Nginx + PHP 8.2 для Moodle"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Установка Nginx..."
apt install -y nginx

echo "2. Добавление репозитория PHP..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "3. Установка PHP 8.2 и расширений для Moodle..."
apt install -y \
    php8.2 \
    php8.2-fpm \
    php8.2-common \
    php8.2-pgsql \
    php8.2-mysql \
    php8.2-xml \
    php8.2-xmlrpc \
    php8.2-curl \
    php8.2-gd \
    php8.2-imagick \
    php8.2-cli \
    php8.2-dev \
    php8.2-imap \
    php8.2-mbstring \
    php8.2-opcache \
    php8.2-soap \
    php8.2-zip \
    php8.2-intl \
    php8.2-bcmath \
    php8.2-ldap \
    php8.2-redis \
    php8.2-fileinfo \
    php8.2-ctype \
    php8.2-tokenizer \
    php8.2-exif \
    php8.2-json \
    php8.2-dom

echo "4. Оптимизация настроек PHP для Moodle..."
PHP_INI="/etc/php/8.2/fpm/php.ini"
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

echo "5. Создание конфигурации Nginx для Moodle..."
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
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
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
}
EOF

echo "6. Активация сайта..."
ln -sf /etc/nginx/sites-available/lms.rtti.tj /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "7. Проверка конфигурации Nginx..."
if nginx -t; then
    echo "✅ Конфигурация Nginx корректна"
else
    echo "❌ Ошибка в конфигурации Nginx"
    exit 1
fi

echo "8. Запуск и включение автозапуска служб..."
systemctl start nginx
systemctl enable nginx
systemctl start php8.2-fpm
systemctl enable php8.2-fpm

echo "9. Настройка firewall..."
ufw allow 'Nginx Full'

echo "10. Создание директории для сайта..."
mkdir -p /var/www/html
chown -R www-data:www-data /var/www/html

echo "11. Создание тестовой страницы..."
cat > /var/www/html/index.php << 'EOF'
<?php
echo "<h1>RTTI Moodle Server Ready</h1>";
echo "<p>Server: lms.rtti.tj</p>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Time: " . date('Y-m-d H:i:s') . "</p>";
phpinfo();
?>
EOF

echo "12. Перезапуск служб..."
systemctl restart nginx
systemctl restart php8.2-fpm

echo "13. Проверка статуса..."
systemctl status nginx --no-pager -l
systemctl status php8.2-fpm --no-pager -l

echo
echo "✅ Шаг 2 завершен успешно!"
echo "📌 Nginx и PHP 8.2 установлены и настроены"
echo "📌 Проверьте: http://lms.rtti.tj"
echo "📌 Следующий шаг: ./03-install-database.sh"
echo
