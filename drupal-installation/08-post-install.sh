#!/bin/bash

# RTTI Drupal - Шаг 8: Базовая пост-установка
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 8: Пост-установочная настройка ==="
echo "🔧 Оптимизация системы"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"
PHP_VERSION="8.3"

echo "1. Настройка PHP для Drupal..."

# Базовая оптимизация PHP
cat > "/etc/php/$PHP_VERSION/fpm/conf.d/99-drupal.ini" << EOF
; Drupal оптимизация
memory_limit = 512M
max_execution_time = 300
upload_max_filesize = 100M
post_max_size = 100M
max_file_uploads = 50
EOF

echo "2. Создание директорий..."

# Создание директории для кэша
mkdir -p /var/cache/nginx/drupal
chown -R www-data:www-data /var/cache/nginx/

# Создание директории для логов
mkdir -p /var/log/drupal
chown -R www-data:www-data /var/log/drupal

echo "3. Оптимизация PostgreSQL..."

# Базовая оптимизация PostgreSQL
cat > /tmp/postgres_optimize.sql << EOF
\c drupal_library;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '16MB';
SELECT pg_reload_conf();
ANALYZE;
EOF

sudo -u postgres psql -f /tmp/postgres_optimize.sql >/dev/null 2>&1

echo "4. Настройка cron..."

# Простой cron для Drupal
(crontab -l 2>/dev/null; echo "*/30 * * * * cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush cron >/dev/null 2>&1") | crontab -

echo "5. Настройка прав доступа..."

# Правильные права на файлы
cd $DRUPAL_DIR
chown -R www-data:www-data .
chmod -R 755 .
chmod -R 777 web/sites/default/files

echo "6. Мягкий перезапуск сервисов..."

# Проверка статуса сайта
SITE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")

if [ "$SITE_STATUS" = "200" ] || [ "$SITE_STATUS" = "301" ] || [ "$SITE_STATUS" = "302" ]; then
    echo "   ⚠️  Сайт работает (HTTP $SITE_STATUS), мягкий перезапуск..."
    systemctl reload php$PHP_VERSION-fpm
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx
    fi
    systemctl reload postgresql
else
    echo "   ℹ️  Полный перезапуск сервисов..."
    systemctl restart php$PHP_VERSION-fpm
    systemctl restart nginx
    systemctl restart postgresql
fi

echo "7. Очистка кэша..."

cd $DRUPAL_DIR
sudo -u www-data vendor/bin/drush cache:rebuild

echo "8. Очистка временных файлов..."
rm -f /tmp/postgres_optimize.sql

echo
echo "✅ Шаг 8 завершен успешно!"
echo "📈 Базовая оптимизация применена"
echo "🔧 Права доступа настроены"
echo "⚙️ Автоматизация настроена"
echo "📌 Следующий шаг: ./09-security.sh"
echo
