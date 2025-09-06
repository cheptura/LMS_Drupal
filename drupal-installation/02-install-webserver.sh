#!/bin/bash

# RTTI Drupal - Шаг 2: Установка веб-сервера
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 2: Установка Nginx и PHP 8.3 ==="
echo "🌐 Веб-сервер для Drupal 11"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

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

echo "5. Установка ТОЛЬКО PHP 8.3 и необходимых расширений для Drupal 11..."
# Устанавливаем только конкретные пакеты PHP 8.3, БЕЗ метапакета php
apt install -y \
    php8.3-cli \
    php8.3-fpm \
    php8.3-common \
    php8.3-pgsql \
    php8.3-mysql \
    php8.3-gd \
    php8.3-imagick \
    php8.3-curl \
    php8.3-zip \
    php8.3-xml \
    php8.3-mbstring \
    php8.3-intl \
    php8.3-bcmath \
    php8.3-opcache \
    php8.3-readline \
    php8.3-soap \
    php8.3-redis \
    php8.3-memcached \
    php8.3-apcu \
    php8.3-uploadprogress

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

echo "9. Установка Composer для управления зависимостями..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Проверка установки Composer
if composer --version >/dev/null 2>&1; then
    echo "✅ Composer установлен: $(composer --version --no-ansi | head -1)"
else
    echo "❌ Ошибка установки Composer"
    exit 1
fi

echo "10. Настройка PHP 8.3 для Drupal..."
PHP_INI="/etc/php/8.3/fpm/php.ini"
PHP_CLI_INI="/etc/php/8.3/cli/php.ini"

# Создание резервной копии
cp $PHP_INI ${PHP_INI}.backup
cp $PHP_CLI_INI ${PHP_CLI_INI}.backup

# Создаем директории conf.d если они не существуют
mkdir -p /etc/php/8.3/fpm/conf.d
mkdir -p /etc/php/8.3/cli/conf.d

# Оптимизация PHP для Drupal
cat > /etc/php/8.3/fpm/conf.d/99-drupal.ini << 'EOF'
; Drupal 11 PHP optimizations

; Memory and execution
memory_limit = 512M
max_execution_time = 300
max_input_time = 300

; File uploads
upload_max_filesize = 100M
post_max_size = 100M
max_file_uploads = 50

; Session handling
session.gc_maxlifetime = 3600
session.cookie_lifetime = 0
session.cookie_secure = 1
session.cookie_httponly = 1

; Security
expose_php = Off
allow_url_fopen = Off
allow_url_include = Off

; Error handling (production)
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php8.3-fpm-errors.log

; Performance
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1

; APCu settings
apc.enable_cli = 1
apc.shm_size = 128M

; Date settings
date.timezone = Asia/Dushanbe
EOF

# Копирование настроек для CLI
cp /etc/php/8.3/fpm/conf.d/99-drupal.ini /etc/php/8.3/cli/conf.d/99-drupal.ini

echo "11. Настройка PHP-FPM пула для Drupal..."
cat > /etc/php/8.3/fpm/pool.d/drupal.conf << 'EOF'
[drupal]
user = www-data
group = www-data

listen = /run/php/php8.3-fpm-drupal.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.max_requests = 1000

; Security
security.limit_extensions = .php

; Logging
catch_workers_output = yes
php_admin_value[error_log] = /var/log/php8.3-fpm-drupal.log
php_admin_flag[log_errors] = on

; Environment variables
env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

; PHP values for Drupal
php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 300
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[max_input_vars] = 3000
EOF

echo "12. Создание базовой конфигурации Nginx для Drupal..."
cat > /etc/nginx/sites-available/drupal-default << 'EOF'
server {
    listen 80;
    server_name storage.omuzgorpro.tj www.storage.omuzgorpro.tj;
    
    root /var/www/drupal/web;
    index index.php index.html;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # File upload size
    client_max_body_size 100M;
    
    # Drupal specific configurations
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    
    # Deny access to configuration files
    location ~ \..*/.*\.php$ {
        return 403;
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
    
    location / {
        try_files $uri /index.php?$query_string;
    }
    
    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }
    
    # PHP processing
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Drupal specific parameters
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
        fastcgi_param QUERY_STRING $query_string;
        fastcgi_param REQUEST_METHOD $request_method;
        fastcgi_param CONTENT_TYPE $content_type;
        fastcgi_param CONTENT_LENGTH $content_length;
        
        fastcgi_intercept_errors on;
        fastcgi_ignore_client_abort off;
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 180;
        fastcgi_read_timeout 180;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }
    
    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        log_not_found off;
    }
    
    # Deny access to vendor directory
    location ^~ /vendor/ {
        deny all;
        return 403;
    }
    
    # Deny access to composer files
    location ~* composer\.(json|lock)$ {
        deny all;
        return 403;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json
        application/xml
        application/xml+rss;
}
EOF

echo "13. Создание каталога для Drupal..."
mkdir -p /var/www/drupal
chown -R www-data:www-data /var/www/drupal

echo "14. Создание тестовой страницы PHP..."
cat > /var/www/drupal/phpinfo.php << 'EOF'
<?php
// Временная страница для проверки PHP
// УДАЛИТЬ ПОСЛЕ УСТАНОВКИ DRUPAL!
echo "<h1>RTTI Drupal Library - PHP Test</h1>";
echo "<p>Сервер: " . $_SERVER['SERVER_NAME'] . "</p>";
echo "<p>PHP версия: " . phpversion() . "</p>";
echo "<p>Время: " . date('Y-m-d H:i:s') . "</p>";

// Проверка расширений для Drupal
$extensions = ['pgsql', 'gd', 'curl', 'zip', 'xml', 'mbstring', 'intl', 'opcache', 'redis'];
echo "<h2>PHP Расширения для Drupal 11:</h2><ul>";
foreach ($extensions as $ext) {
    $status = extension_loaded($ext) ? "✅" : "❌";
    echo "<li>$ext: $status</li>";
}
echo "</ul>";

// Проверка Composer
$composer_version = shell_exec('composer --version 2>/dev/null');
echo "<h2>Composer:</h2>";
echo $composer_version ? "<p>✅ " . trim($composer_version) . "</p>" : "<p>❌ Не установлен</p>";

echo "<p><strong>Готовность к установке Drupal 11:</strong> ";
$ready = extension_loaded('pgsql') && extension_loaded('gd') && extension_loaded('curl') && $composer_version;
echo $ready ? "✅ Готов" : "❌ Требуется настройка";
echo "</p>";
?>
EOF

chown www-data:www-data /var/www/drupal/phpinfo.php

echo "15. Активация конфигурации Nginx..."
# Отключение сайта по умолчанию
if [ -L /etc/nginx/sites-enabled/default ]; then
    unlink /etc/nginx/sites-enabled/default
fi

# Активация конфигурации Drupal
ln -sf /etc/nginx/sites-available/drupal-default /etc/nginx/sites-enabled/

echo "16. Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Ошибка конфигурации Nginx"
    exit 1
fi

echo "17. Запуск и включение сервисов..."
systemctl start nginx
systemctl enable nginx
systemctl start php8.3-fpm
systemctl enable php8.3-fpm

echo "18. Проверка статуса сервисов..."
echo "Nginx статус:"
systemctl status nginx --no-pager -l | head -3

echo -e "\nPHP-FPM статус:"
systemctl status php8.3-fpm --no-pager -l | head -3

echo "19. Финальная проверка версии PHP..."
echo "📋 Установленная версия PHP:"
php -v
echo
echo "📋 Установленные пакеты PHP 8.3:"
dpkg -l | grep php8.3 | head -10
echo
echo "📋 Проверка на наличие других версий PHP:"
dpkg -l | grep -E "php[0-9]" | grep -v php8.3 || echo "✅ Других версий PHP не найдено"
echo
echo "📊 Текущие настройки PHP для Drupal:"
php -r "
echo 'memory_limit = ' . ini_get('memory_limit') . ' (требуется >= 512M)' . PHP_EOL;
echo 'max_execution_time = ' . ini_get('max_execution_time') . ' (требуется >= 300)' . PHP_EOL;
echo 'upload_max_filesize = ' . ini_get('upload_max_filesize') . ' (требуется >= 100M)' . PHP_EOL;
echo 'post_max_size = ' . ini_get('post_max_size') . ' (требуется >= 100M)' . PHP_EOL;
echo 'date.timezone = ' . ini_get('date.timezone') . ' (установлен)' . PHP_EOL;
echo 'opcache.enable = ' . (ini_get('opcache.enable') ? 'Включен' : 'Отключен') . PHP_EOL;
"

echo "20. Создание скрипта мониторинга веб-сервера..."
cat > /root/drupal-webserver-monitor.sh << 'EOF'
#!/bin/bash
echo "=== Drupal Web Server Monitor ==="
echo "Время: $(date)"
echo

echo "1. Статус сервисов:"
echo -n "Nginx: "; systemctl is-active nginx
echo -n "PHP-FPM: "; systemctl is-active php8.3-fpm

echo -e "\n2. Процессы PHP-FPM:"
ps aux | grep php-fpm | grep -v grep | wc -l

echo -e "\n3. Использование памяти PHP:"
ps aux | grep php-fpm | awk '{sum+=$6} END {print "PHP processes: " sum/1024 " MB"}'

echo -e "\n4. Активные соединения Nginx:"
ss -tuln | grep -E ":80|:443"

echo -e "\n5. Логи ошибок (последние 5):"
echo "Nginx:"
tail -5 /var/log/nginx/error.log 2>/dev/null || echo "Нет ошибок"
echo -e "\nPHP-FPM:"
tail -5 /var/log/php8.3-fpm.log 2>/dev/null || echo "Нет ошибок"

echo -e "\n6. Дисковое пространство:"
df -h /var/www

echo -e "\n7. PHP версия:"
php --version | head -1
EOF

chmod +x /root/drupal-webserver-monitor.sh

echo "20. Создание информационного файла..."
cat > /root/drupal-webserver-info.txt << EOF
# Информация о веб-сервере для Drupal
# Дата установки: $(date)
# Сервер: storage.omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===
Веб-сервер: Nginx $(nginx -v 2>&1 | awk '{print $3}')
PHP: $(php --version | head -1 | awk '{print $2}')
Composer: $(composer --version --no-ansi | head -1 | awk '{print $3}')

=== КОНФИГУРАЦИЯ ===
Nginx конфигурация: /etc/nginx/sites-available/drupal-default
PHP конфигурация: /etc/php/8.3/fpm/conf.d/99-drupal.ini
PHP-FPM пул: /etc/php/8.3/fpm/pool.d/drupal.conf
Каталог сайта: /var/www/drupal

=== PHP РАСШИРЕНИЯ ===
$(php -m | grep -E "(pgsql|gd|curl|zip|xml|mbstring|intl|opcache|redis)" | sed 's/^/✅ /')

=== ТЕСТИРОВАНИЕ ===
Тест PHP: http://storage.omuzgorpro.tj/phpinfo.php (УДАЛИТЬ ПОСЛЕ УСТАНОВКИ!)

=== КОМАНДЫ УПРАВЛЕНИЯ ===
Перезапуск Nginx: systemctl restart nginx
Перезапуск PHP-FPM: systemctl restart php8.3-fpm
Проверка конфигурации: nginx -t
Мониторинг: /root/drupal-webserver-monitor.sh

=== ЛОГИ ===
Nginx доступ: /var/log/nginx/access.log
Nginx ошибки: /var/log/nginx/error.log
PHP-FPM: /var/log/php8.3-fpm.log
PHP ошибки: /var/log/php8.3-fpm-errors.log

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Запустите: ./03-install-database.sh
2. Проверьте: http://storage.omuzgorpro.tj/phpinfo.php
3. Убедитесь что все расширения PHP установлены
EOF

echo
echo "✅ Шаг 2 завершен успешно!"
echo "📌 Nginx установлен и настроен"
echo "📌 PHP 8.3 с расширениями для Drupal 11"
echo "📌 Composer установлен"
echo "📌 Конфигурация оптимизирована"
echo "📌 Тест: http://storage.omuzgorpro.tj/phpinfo.php"
echo "📌 Мониторинг: /root/drupal-webserver-monitor.sh"
echo "📌 Информация: /root/drupal-webserver-info.txt"
echo "📌 Следующий шаг: ./03-install-database.sh"
echo
