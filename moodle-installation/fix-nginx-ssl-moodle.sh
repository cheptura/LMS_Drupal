#!/bin/bash

# Fix Nginx SSL configuration for Moodle JavaScript and CSS loading
# Author: cheptura
# Version: 1.0

set -e

echo "🔧 Исправление SSL конфигурации Nginx для Moodle..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Этот скрипт должен запускаться с правами root (sudo)${NC}"
   exit 1
fi

# Detect Moodle installation path
MOODLE_PATH=""
if [ -d "/var/www/moodle" ] && [ -f "/var/www/moodle/config.php" ]; then
    MOODLE_PATH="/var/www/moodle"
elif [ -d "/var/www/html/moodle" ] && [ -f "/var/www/html/moodle/config.php" ]; then
    MOODLE_PATH="/var/www/html/moodle"
else
    echo -e "${RED}❌ Moodle не найден в стандартных директориях${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Moodle найден в: $MOODLE_PATH${NC}"

# Remove conflicting configurations
echo "🗑️ Удаление конфликтующих конфигураций..."
rm -f /etc/nginx/sites-enabled/moodle-ssl
rm -f /etc/nginx/sites-enabled/lms.rtti.tj

# Create unified SSL configuration
echo "📝 Создание объединенной SSL конфигурации..."
cat > /etc/nginx/sites-available/lms.rtti.tj << 'EOF'
# HTTP server (redirect to HTTPS)
server {
    listen 80;
    server_name lms.rtti.tj;

    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name lms.rtti.tj;
    root MOODLE_PATH_PLACEHOLDER;
    index index.php index.html index.htm;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/lms.rtti.tj/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lms.rtti.tj/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 100M;
    client_body_timeout 300s;
    fastcgi_read_timeout 300s;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Main location
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
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

    # PHP processing
    location ~ \.php$ {
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
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
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

# Replace placeholder with actual Moodle path
sed -i "s|MOODLE_PATH_PLACEHOLDER|$MOODLE_PATH|g" /etc/nginx/sites-available/lms.rtti.tj

# Enable the site
echo "🔗 Активация конфигурации сайта..."
ln -sf /etc/nginx/sites-available/lms.rtti.tj /etc/nginx/sites-enabled/lms.rtti.tj

# Test nginx configuration
echo "🧪 Проверка конфигурации Nginx..."
if nginx -t; then
    echo -e "${GREEN}✅ Конфигурация Nginx корректна${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации Nginx${NC}"
    exit 1
fi

# Reload nginx
echo "🔄 Перезагрузка Nginx..."
systemctl reload nginx

# Clear Moodle cache
echo "🧹 Очистка кэша Moodle..."
if [ -f "$MOODLE_PATH/admin/cli/purge_caches.php" ]; then
    sudo -u www-data php "$MOODLE_PATH/admin/cli/purge_caches.php" || echo -e "${YELLOW}⚠️ Предупреждение: не удалось очистить кэш Moodle${NC}"
fi

echo ""
echo -e "${GREEN}🎉 SSL КОНФИГУРАЦИЯ NGINX ДЛЯ MOODLE ИСПРАВЛЕНА!${NC}"
echo ""
echo "📋 Что было сделано:"
echo "   ✅ Удалены конфликтующие конфигурации"
echo "   ✅ Создана объединенная SSL конфигурация"
echo "   ✅ Добавлены обработчики для JavaScript и CSS с PATH_INFO"
echo "   ✅ Настроено перенаправление HTTP → HTTPS"
echo "   ✅ Добавлены заголовки безопасности"
echo "   ✅ Очищен кэш Moodle"
echo ""
echo "🌐 Теперь JavaScript и CSS должны загружаться корректно через HTTPS!"
echo "🔄 Попробуйте обновить страницу в браузере (Ctrl+F5)"
echo ""
