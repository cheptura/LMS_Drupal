#!/bin/bash

# Fix Moodle CSP and Missing Handlers
# Author: cheptura
# Version: 1.0

set -e

echo "🔧 Исправление CSP и недостающих обработчиков для Moodle..."

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

# Check if configuration exists
if [ ! -f "/etc/nginx/sites-available/lms.rtti.tj" ]; then
    echo -e "${RED}❌ Конфигурация /etc/nginx/sites-available/lms.rtti.tj не найдена${NC}"
    exit 1
fi

echo "📝 Исправление Content Security Policy..."
# Fix CSP to allow unsafe-eval for YUI
sed -i 's/default-src '\''self'\'' http: https: data: blob: '\''unsafe-inline'\''/default-src '\''self'\'' http: https: data: blob: '\''unsafe-inline'\'' '\''unsafe-eval'\''/g' /etc/nginx/sites-available/lms.rtti.tj

echo "📝 Добавление обработчиков для font.php и image.php..."

# Add font.php handler after yui_combo.php handler
if ! grep -q "theme/font\.php" /etc/nginx/sites-available/lms.rtti.tj; then
    # Find the line after yui_combo.php block and add font.php handler
    sed -i '/location ~ \^(\/theme\/yui_combo\\\.php)(\/.*)?\$.*{/,/}/ {
        /}/ a\
\
    # Moodle font handler with path info\
    location ~ ^(/theme/font\.php)(/.*)?$ {\
        include snippets/fastcgi-php.conf;\
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;\
        fastcgi_param SCRIPT_FILENAME $document_root$1;\
        fastcgi_param PATH_INFO $2;\
        include fastcgi_params;\
        fastcgi_read_timeout 300;\
        expires 1y;\
        add_header Cache-Control "public, immutable";\
    }
    }' /etc/nginx/sites-available/lms.rtti.tj
fi

# Add image.php handler after font.php handler
if ! grep -q "theme/image\.php" /etc/nginx/sites-available/lms.rtti.tj; then
    # Find the line after font.php block and add image.php handler
    sed -i '/location ~ \^(\/theme\/font\\\.php)(\/.*)?\$.*{/,/}/ {
        /}/ a\
\
    # Moodle image handler with path info\
    location ~ ^(/theme/image\.php)(/.*)?$ {\
        include snippets/fastcgi-php.conf;\
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;\
        fastcgi_param SCRIPT_FILENAME $document_root$1;\
        fastcgi_param PATH_INFO $2;\
        include fastcgi_params;\
        fastcgi_read_timeout 300;\
        expires 1y;\
        add_header Cache-Control "public, immutable";\
    }
    }' /etc/nginx/sites-available/lms.rtti.tj
fi

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
MOODLE_PATH=""
if [ -d "/var/www/moodle" ] && [ -f "/var/www/moodle/config.php" ]; then
    MOODLE_PATH="/var/www/moodle"
elif [ -d "/var/www/html/moodle" ] && [ -f "/var/www/html/moodle/config.php" ]; then
    MOODLE_PATH="/var/www/html/moodle"
fi

if [ -n "$MOODLE_PATH" ] && [ -f "$MOODLE_PATH/admin/cli/purge_caches.php" ]; then
    sudo -u www-data php "$MOODLE_PATH/admin/cli/purge_caches.php" || echo -e "${YELLOW}⚠️ Предупреждение: не удалось очистить кэш Moodle${NC}"
fi

echo ""
echo -e "${GREEN}🎉 ИСПРАВЛЕНИЕ CSP И ОБРАБОТЧИКОВ ЗАВЕРШЕНО!${NC}"
echo ""
echo "📋 Что было исправлено:"
echo "   ✅ Добавлен 'unsafe-eval' в Content Security Policy для YUI"
echo "   ✅ Добавлен обработчик для /theme/font.php"
echo "   ✅ Добавлен обработчик для /theme/image.php"
echo "   ✅ Очищен кэш Moodle"
echo ""
echo "🔄 Попробуйте обновить страницу в браузере (Ctrl+F5)"
echo "⚠️  Если ошибки остались, проверьте логи: sudo tail /var/log/nginx/error.log"
echo ""
