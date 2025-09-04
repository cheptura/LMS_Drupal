#!/bin/bash

# RTTI Moodle Fix Permissions Script
# Исправление прав доступа для Moodle

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                      Moodle Fix Permissions Script                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./fix-permissions.sh"
    exit 1
fi

# Переменные
MOODLE_DIR="/var/www/html/moodle"
DATA_DIR="/var/moodledata"
WEB_USER="www-data"
WEB_GROUP="www-data"

echo "🔧 Исправление прав доступа для Moodle..."
echo "📅 Дата: $(date)"
echo "📂 Moodle директория: $MOODLE_DIR"
echo "📁 Данные директория: $DATA_DIR"
echo "👤 Веб-пользователь: $WEB_USER:$WEB_GROUP"
echo

# Проверка существования директорий
if [ ! -d "$MOODLE_DIR" ]; then
    echo "❌ Moodle директория не найдена: $MOODLE_DIR"
    exit 1
fi

if [ ! -d "$DATA_DIR" ]; then
    echo "❌ Директория данных не найдена: $DATA_DIR"
    exit 1
fi

# Остановка веб-сервера для безопасности
echo "🛑 Остановка веб-сервера..."
systemctl stop nginx

# Исправление владельца файлов Moodle
echo "👤 Установка владельца для файлов Moodle..."
chown -R $WEB_USER:$WEB_GROUP $MOODLE_DIR
echo "✅ Владелец установлен: $WEB_USER:$WEB_GROUP"

# Исправление прав для файлов Moodle
echo "🔐 Установка прав доступа для файлов Moodle..."
find $MOODLE_DIR -type f -exec chmod 644 {} \;
find $MOODLE_DIR -type d -exec chmod 755 {} \;
echo "✅ Права установлены: файлы 644, директории 755"

# Специальные права для config.php
if [ -f "$MOODLE_DIR/config.php" ]; then
    echo "⚙️  Установка специальных прав для config.php..."
    chmod 640 "$MOODLE_DIR/config.php"
    echo "✅ config.php: 640"
fi

# Исправление владельца для данных Moodle
echo "👤 Установка владельца для данных Moodle..."
chown -R $WEB_USER:$WEB_GROUP $DATA_DIR
echo "✅ Владелец данных установлен: $WEB_USER:$WEB_GROUP"

# Исправление прав для данных Moodle
echo "🔐 Установка прав доступа для данных Moodle..."
find $DATA_DIR -type f -exec chmod 644 {} \;
find $DATA_DIR -type d -exec chmod 755 {} \;
echo "✅ Права данных установлены: файлы 644, директории 755"

# Специальные права для важных директорий
echo "🔒 Установка специальных прав для критических директорий..."

# Директория cache должна быть записываемой
if [ -d "$DATA_DIR/cache" ]; then
    chmod 777 "$DATA_DIR/cache"
    echo "✅ cache: 777"
fi

# Директория sessions должна быть записываемой
if [ -d "$DATA_DIR/sessions" ]; then
    chmod 777 "$DATA_DIR/sessions"
    echo "✅ sessions: 777"
fi

# Директория temp должна быть записываемой
if [ -d "$DATA_DIR/temp" ]; then
    chmod 777 "$DATA_DIR/temp"
    echo "✅ temp: 777"
fi

# Директория localcache должна быть записываемой
if [ -d "$DATA_DIR/localcache" ]; then
    chmod 777 "$DATA_DIR/localcache"
    echo "✅ localcache: 777"
fi

# Исправление прав для логов
echo "📋 Установка прав для логов..."
if [ -d "/var/log/nginx" ]; then
    chown -R www-data:adm /var/log/nginx
    chmod 755 /var/log/nginx
    echo "✅ Логи Nginx исправлены"
fi

if [ -d "/var/log/php8.3-fpm" ]; then
    chown -R www-data:adm /var/log/php8.3-fpm
    chmod 755 /var/log/php8.3-fpm
    echo "✅ Логи PHP-FPM исправлены"
fi

# Исправление прав для Unix socket
echo "🔌 Проверка Unix socket..."
if [ -S "/run/php/php8.3-fpm.sock" ]; then
    chown www-data:www-data /run/php/php8.3-fpm.sock
    chmod 660 /run/php/php8.3-fpm.sock
    echo "✅ PHP-FPM socket исправлен"
fi

# Исправление SELinux контекстов (если SELinux включен)
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
    echo "🛡️  Установка SELinux контекстов..."
    
    # Контексты для веб-контента
    setsebool -P httpd_can_network_connect 1
    setsebool -P httpd_execmem 1
    semanage fcontext -a -t httpd_exec_t "$MOODLE_DIR(/.*)?"
    semanage fcontext -a -t httpd_rw_content_t "$DATA_DIR(/.*)?"
    restorecon -R $MOODLE_DIR
    restorecon -R $DATA_DIR
    
    echo "✅ SELinux контексты установлены"
else
    echo "ℹ️  SELinux отключен или не установлен"
fi

# Перезапуск сервисов
echo "🔄 Перезапуск сервисов..."
systemctl restart php8.3-fpm
systemctl restart nginx

# Проверка статуса сервисов
echo "🔍 Проверка статуса сервисов..."
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx: Активен"
else
    echo "❌ Nginx: Проблема"
fi

if systemctl is-active --quiet php8.3-fpm; then
    echo "✅ PHP-FPM: Активен"
else
    echo "❌ PHP-FPM: Проблема"
fi

# Тестирование веб-доступа
echo "🌐 Тестирование веб-доступа..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
    echo "✅ Веб-сервер отвечает корректно"
else
    echo "⚠️  Веб-сервер может иметь проблемы"
fi

# Отображение итоговых прав
echo
echo "📊 ИТОГОВЫЕ ПРАВА ДОСТУПА"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "📂 Moodle директория:"
ls -la $MOODLE_DIR | head -5

echo
echo "📁 Данные Moodle:"
ls -la $DATA_DIR | head -5

# Создание отчета
REPORT_FILE="/tmp/moodle_permissions_$(date +%Y%m%d_%H%M%S).txt"
echo "📄 Создание отчета: $REPORT_FILE"

cat > $REPORT_FILE << EOF
Moodle Permissions Fix Report
============================
Date: $(date)
Server: $(hostname)

Moodle Directory: $MOODLE_DIR
Data Directory: $DATA_DIR
Web User: $WEB_USER:$WEB_GROUP

Applied Permissions:
- Moodle files: 644
- Moodle directories: 755
- Data files: 644
- Data directories: 755
- config.php: 640
- Special dirs (cache, sessions, temp): 777

Services Status:
- Nginx: $(systemctl is-active nginx)
- PHP-FPM: $(systemctl is-active php8.3-fpm)

Critical Directories:
$(ls -la $MOODLE_DIR | head -5)

Data Directories:
$(ls -la $DATA_DIR | head -5)
EOF

echo "✅ Отчет сохранен в: $REPORT_FILE"
echo

echo "🎉 Исправление прав доступа завершено успешно!"
echo
echo "📋 Рекомендации:"
echo "   1. Проверьте сайт: https://lms.rtti.tj"
echo "   2. Просмотрите логи: tail -f /var/log/nginx/error.log"
echo "   3. Если проблемы остались, выполните: ./diagnose-moodle.sh"
echo
echo "💡 Для регулярного поддержания прав запускайте этот скрипт еженедельно"
