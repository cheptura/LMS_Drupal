#!/bin/bash

# RTTI Moodle - Исправление конфигурации Nginx для Moodle
# Решает проблемы с загрузкой JavaScript и CSS файлов

echo "=== Исправление конфигурации Nginx для Moodle ==="
echo "🔧 Исправление проблем с JavaScript и CSS файлами"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Определение текущего пути Moodle..."
CURRENT_ROOT=""
if [ -f "/etc/nginx/sites-available/lms.rtti.tj" ]; then
    CURRENT_ROOT=$(grep "root " /etc/nginx/sites-available/lms.rtti.tj | head -1 | awk '{print $2}' | sed 's/;//')
    echo "ℹ️  Текущий root: $CURRENT_ROOT"
fi

# Определяем правильный путь к Moodle
MOODLE_PATH=""
if [ -d "/var/www/moodle" ] && [ -f "/var/www/moodle/config.php" ]; then
    MOODLE_PATH="/var/www/moodle"
elif [ -d "/var/www/html/moodle" ] && [ -f "/var/www/html/moodle/config.php" ]; then
    MOODLE_PATH="/var/www/html/moodle"
else
    echo "❌ Не найден каталог с установленным Moodle"
    echo "Проверьте что Moodle установлен в /var/www/moodle или /var/www/html/moodle"
    exit 1
fi

echo "✅ Найден Moodle в: $MOODLE_PATH"

echo "2. Создание улучшенной конфигурации Nginx для Moodle..."

# Создаем новую конфигурацию с правильной обработкой Moodle файлов
cat > /etc/nginx/sites-available/lms.rtti.tj << EOF
server {
    listen 80;
    server_name lms.rtti.tj;
    root $MOODLE_PATH;
    index index.php index.html index.htm;

    client_max_body_size 100M;
    client_body_timeout 300s;
    fastcgi_read_timeout 300s;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Main location
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP processing
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }

    # Moodle JavaScript and CSS combo handler
    location ~ ^/theme/yui_combo\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle JavaScript handler
    location ~ ^/lib/javascript\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle CSS handler
    location ~ ^/theme/styles\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Moodle pluginfile handler
    location ~ ^/pluginfile\.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
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
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        try_files \$uri =404;
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

echo "2. Тестирование конфигурации Nginx..."
if nginx -t; then
    echo "✅ Конфигурация Nginx корректна"
else
    echo "❌ Ошибка в конфигурации Nginx"
    exit 1
fi

echo "3. Перезапуск Nginx..."
systemctl reload nginx
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx успешно перезапущен"
else
    echo "❌ Ошибка при перезапуске Nginx"
    systemctl status nginx
    exit 1
fi

echo "4. Очистка кэша Moodle..."
if [ -f "$MOODLE_PATH/admin/cli/purge_caches.php" ]; then
    sudo -u www-data php $MOODLE_PATH/admin/cli/purge_caches.php
    echo "✅ Кэш Moodle очищен"
else
    echo "⚠️  Файл очистки кэша не найден"
fi

echo "5. Проверка путей к файлам..."
if [ -d "$MOODLE_PATH/lib" ]; then
    echo "✅ Каталог $MOODLE_PATH/lib существует"
else
    echo "❌ Каталог $MOODLE_PATH/lib не найден"
fi

if [ -d "$MOODLE_PATH/theme" ]; then
    echo "✅ Каталог $MOODLE_PATH/theme существует"
else
    echo "❌ Каталог $MOODLE_PATH/theme не найден"
fi

# Проверяем ключевые файлы Moodle
if [ -f "$MOODLE_PATH/lib/javascript.php" ]; then
    echo "✅ JavaScript обработчик найден"
else
    echo "❌ JavaScript обработчик отсутствует"
fi

if [ -f "$MOODLE_PATH/theme/styles.php" ]; then
    echo "✅ CSS обработчик найден"
else
    echo "❌ CSS обработчик отсутствует"
fi

echo
echo "🎉 ==============================================="
echo "🎉 КОНФИГУРАЦИЯ NGINX ДЛЯ MOODLE ОБНОВЛЕНА!"
echo "🎉 ==============================================="
echo
echo "📋 Что было исправлено:"
echo "  ✅ Добавлены специальные обработчики для JavaScript"
echo "  ✅ Добавлены специальные обработчики для CSS"
echo "  ✅ Настроено правильное кэширование"
echo "  ✅ Улучшены заголовки безопасности"
echo "  ✅ Добавлена защита внутренних путей Moodle"
echo
echo "🔄 Теперь перезагрузите страницу Moodle в браузере"
echo "   URL: https://lms.rtti.tj"
echo
echo "🧪 Если проблемы остались:"
echo "   1. Очистите кэш браузера (Ctrl+F5)"
echo "   2. Проверьте логи: sudo tail -f /var/log/nginx/error.log"
echo "   3. Запустите диагностику: sudo ./diagnose-moodle.sh"
echo
echo "✅ Исправление завершено!"
