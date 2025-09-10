#!/bin/bash

# RTTI Drupal - Исправление проблем после установки
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Исправление проблем после установки ==="
echo "🔧 Исправляем Nginx, PHP OPcache и конфигурацию"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Проверка установки PHP OPcache..."
if php -m | grep -q opcache; then
    echo "   ✅ OPcache уже установлен"
else
    echo "   📦 Установка PHP OPcache..."
    apt update
    apt install -y php8.3-opcache
fi

echo "2. Включение OPcache в PHP конфигурации..."
# Убеждаемся, что OPcache включен в php.ini
if ! grep -q "opcache.enable=1" /etc/php/8.3/fpm/php.ini; then
    echo "   🔧 Настройка OPcache в FPM..."
    cat >> /etc/php/8.3/fpm/php.ini << 'EOF'

; OPcache settings for Drupal
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.save_comments=1
opcache.enable_file_override=1
opcache.validate_timestamps=1
EOF
fi

if ! grep -q "opcache.enable=1" /etc/php/8.3/cli/php.ini; then
    echo "   🔧 Настройка OPcache в CLI..."
    cat >> /etc/php/8.3/cli/php.ini << 'EOF'

; OPcache settings for Drupal
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.save_comments=1
opcache.enable_file_override=1
opcache.validate_timestamps=1
EOF
fi

echo "3. Проверка конфигурации PHP-FPM пула..."
if [ ! -f "/etc/php/8.3/fpm/pool.d/drupal.conf" ]; then
    echo "   🔧 Создание PHP-FPM пула для Drupal..."
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
else
    echo "   ✅ PHP-FPM пул уже существует"
fi

echo "4. Проверка конфигурации Nginx..."
if [ ! -f "/etc/nginx/sites-available/drupal-default" ]; then
    echo "   🔧 Создание конфигурации Nginx для Drupal..."
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
    
    # PHP processing - упрощенный обработчик для всех PHP файлов
    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_index index.php;
        fastcgi_pass unix:/run/php/php8.3-fpm-drupal.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        
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
else
    echo "   ✅ Конфигурация Nginx уже существует"
fi

echo "5. Создание директории Drupal..."
mkdir -p /var/www/drupal/web
chown -R www-data:www-data /var/www/drupal

echo "6. Активация сайта Nginx..."
# Отключение сайта по умолчанию
if [ -L /etc/nginx/sites-enabled/default ]; then
    echo "   🔌 Отключение сайта по умолчанию..."
    unlink /etc/nginx/sites-enabled/default
fi

# Активация конфигурации Drupal
if [ ! -L /etc/nginx/sites-enabled/drupal-default ]; then
    echo "   🔗 Активация конфигурации Drupal..."
    ln -sf /etc/nginx/sites-available/drupal-default /etc/nginx/sites-enabled/
fi

echo "7. Проверка конфигурации Nginx..."
if nginx -t; then
    echo "   ✅ Конфигурация Nginx корректна"
else
    echo "   ❌ Ошибка в конфигурации Nginx"
    echo "   📋 Детали ошибки:"
    nginx -t
    exit 1
fi

echo "8. Перезапуск сервисов..."
echo "   🔄 Перезапуск PHP-FPM..."
systemctl restart php8.3-fpm
if systemctl is-active --quiet php8.3-fpm; then
    echo "   ✅ PHP-FPM активен"
    systemctl enable php8.3-fpm
else
    echo "   ❌ Ошибка запуска PHP-FPM"
    systemctl status php8.3-fpm --no-pager
    exit 1
fi

echo "   🔄 Перезапуск Nginx..."
systemctl restart nginx
if systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx активен"
    systemctl enable nginx
else
    echo "   ❌ Ошибка запуска Nginx"
    systemctl status nginx --no-pager
    exit 1
fi

echo "9. Проверка портов..."
echo "   🔍 Проверка открытых портов:"
if netstat -tlnp | grep ":80 "; then
    echo "   ✅ Порт 80 открыт"
else
    echo "   ⚠️  Порт 80 не открыт"
fi

if netstat -tlnp | grep ":443 "; then
    echo "   ✅ Порт 443 открыт"
else
    echo "   ⚠️  Порт 443 не открыт (потребуется SSL конфигурация)"
fi

echo "10. Проверка PHP модулей..."
echo "   📋 Установленные PHP модули:"
php -m | grep -E "(opcache|pgsql|gd|curl|zip|xml|mbstring)" | while read module; do
    echo "   ✅ $module"
done

echo "11. Создание тестовой страницы..."
cat > /var/www/drupal/web/phpinfo.php << 'EOF'
<?php
echo "<h1>RTTI Drupal - Проверка PHP</h1>";
echo "<h2>Версия PHP:</h2>";
echo "<p>" . phpversion() . "</p>";

echo "<h2>Важные модули:</h2>";
$modules = ['pgsql', 'gd', 'curl', 'zip', 'xml', 'mbstring', 'opcache'];
foreach ($modules as $module) {
    $status = extension_loaded($module) ? "✅ Установлен" : "❌ Не установлен";
    echo "<p><strong>$module:</strong> $status</p>";
}

echo "<h2>OPcache Status:</h2>";
if (extension_loaded('opcache')) {
    $opcache_status = opcache_get_status();
    if ($opcache_status !== false) {
        echo "<p>✅ OPcache активен</p>";
        echo "<p>Использовано памяти: " . round($opcache_status['memory_usage']['used_memory'] / 1024 / 1024, 2) . " MB</p>";
        echo "<p>Кэшированных файлов: " . $opcache_status['opcache_statistics']['num_cached_scripts'] . "</p>";
    } else {
        echo "<p>⚠️ OPcache установлен, но не активен</p>";
    }
} else {
    echo "<p>❌ OPcache не установлен</p>";
}

echo "<h2>Готовность к установке Drupal 11:</h2>";
$ready = extension_loaded('pgsql') && extension_loaded('gd') && extension_loaded('curl');
echo $ready ? "<p>✅ Готов</p>" : "<p>❌ Требуется настройка</p>";
?>
EOF

chown www-data:www-data /var/www/drupal/web/phpinfo.php

echo
echo "🎉 ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ УСПЕШНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "📊 Результаты исправлений:"
echo "   ✅ PHP OPcache: установлен и настроен"
echo "   ✅ PHP-FPM пул: создан и активен"
echo "   ✅ Nginx конфигурация: создана и проверена"
echo "   ✅ Сервисы: перезапущены и включены"
echo
echo "🔍 Проверка статуса:"
echo "   Nginx: $(systemctl is-active nginx)"
echo "   PHP-FPM: $(systemctl is-active php8.3-fpm)"
echo
echo "🌐 Тестирование:"
echo "   HTTP: http://storage.omuzgorpro.tj/phpinfo.php"
echo "   Если IP локальный: http://192.168.0.163/phpinfo.php"
echo
echo "🔧 Следующие шаги:"
echo "   1. Проверьте тестовую страницу в браузере"
echo "   2. Если нужен SSL, запустите: ./05-configure-ssl.sh"
echo "   3. Продолжите установку Drupal: ./06-install-drupal.sh"
echo
echo "✅ ИСПРАВЛЕНИЯ ЗАВЕРШЕНЫ!"
