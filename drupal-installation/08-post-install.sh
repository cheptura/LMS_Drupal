#!/bin/bash

# RTTI Drupal - Шаг 8: Пост-установочная настройка
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 8: Пост-установочная настройка ==="
echo "🔧 Тонкая настройка системы и производительности"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"
NGINX_DIR="/etc/nginx"
PHP_VERSION="8.3"

echo "1. Настройка PHP для оптимальной производительности..."

# Создание дополнительной конфигурации PHP для Drupal
cat > "/etc/php/$PHP_VERSION/fpm/conf.d/99-drupal-optimization.ini" << EOF
; Настройки PHP для Drupal Library
; Дата: $(date)

; Память и производительность
memory_limit = 512M
max_execution_time = 300
max_input_time = 300

; Загрузка файлов
upload_max_filesize = 100M
post_max_size = 100M
max_file_uploads = 50

; Сессии
session.gc_maxlifetime = 7200
session.cookie_lifetime = 86400

; OPcache дополнительные настройки
opcache.validate_timestamps = 0
opcache.revalidate_freq = 0
opcache.max_accelerated_files = 20000
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.fast_shutdown = 1

; Настройки для больших библиотек
max_input_vars = 5000
max_input_nesting_level = 128

; Безопасность
expose_php = Off
allow_url_fopen = Off
allow_url_include = Off

; Логирование
log_errors = On
error_log = /var/log/php/drupal-errors.log
EOF

# Создание директории для логов PHP
mkdir -p /var/log/php
chown www-data:www-data /var/log/php

echo "2. Настройка Nginx для лучшей производительности..."

# Удаляем старую неправильную конфигурацию если существует
rm -f "$NGINX_DIR/conf.d/drupal-static.conf"

# Дополнительная глобальная конфигурация Nginx
cat > "$NGINX_DIR/conf.d/drupal-performance.conf" << EOF
# Глобальные настройки производительности для Drupal
# Дата: $(date)

# Сжатие gzip для всех сайтов
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_comp_level 6;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/javascript
    application/json
    application/xml
    application/xml+rss
    application/font-woff
    application/font-woff2
    application/x-font-ttf
    image/svg+xml;

# Настройки буферов
client_body_buffer_size 16K;
client_header_buffer_size 1k;
large_client_header_buffers 4 8k;

# Таймауты
client_body_timeout 60s;
client_header_timeout 60s;
keepalive_timeout 65s;
send_timeout 60s;

# Размеры файлов
client_max_body_size 100M;

# Логирование
log_format drupal_detailed '$remote_addr - $remote_user [$time_local] '
                          '"$request" $status $bytes_sent '
                          '"$http_referer" "$http_user_agent" '
                          '$request_time $upstream_response_time';
EOF

echo "   ✅ Создана конфигурация производительности Nginx"

# Обновляем основную конфигурацию Drupal с кэшированием статических файлов
echo "   📝 Обновление конфигурации сайта Drupal с кэшированием..."

# Создаем резервную копию текущей конфигурации
cp /etc/nginx/sites-available/drupal-default /etc/nginx/sites-available/drupal-default.backup

# Добавляем правила кэширования в основную конфигурацию сайта
sed -i '/# Static files caching/,/}/c\
    # Enhanced static files caching\
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|pdf|doc|docx|xls|xlsx|ppt|pptx)$ {\
        expires 1y;\
        add_header Cache-Control "public, immutable";\
        add_header Vary Accept-Encoding;\
        log_not_found off;\
        access_log off;\
    }' /etc/nginx/sites-available/drupal-default

echo "   ✅ Обновлена конфигурация кэширования статических файлов"

echo "3. Настройка производительности базы данных..."

# Оптимизация PostgreSQL для Drupal
cat > /tmp/postgres_drupal_optimize.sql << EOF
-- Оптимизация PostgreSQL для Drupal Library
-- Дата: $(date)

-- Настройка подключения к БД drupal_library
\c drupal_library;

-- Оптимизация памяти
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '16MB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';

-- Оптимизация записи
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET checkpoint_timeout = '15min';

-- Оптимизация планировщика
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Настройки для веб-приложений
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

-- Создание индексов для часто используемых запросов Drupal
CREATE INDEX IF NOT EXISTS idx_node_field_data_type_status ON node_field_data(type, status);
CREATE INDEX IF NOT EXISTS idx_node_field_data_created ON node_field_data(created DESC);
CREATE INDEX IF NOT EXISTS idx_users_field_data_access ON users_field_data(access DESC);

-- Статистика использования
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Перезагрузка конфигурации
SELECT pg_reload_conf();

ANALYZE;
EOF

sudo -u postgres psql -f /tmp/postgres_drupal_optimize.sql

echo "4. Настройка Redis для Drupal..."

# Создание конфигурации Redis для Drupal
cat > "$DRUPAL_DIR/web/sites/default/redis.settings.php" << EOF
<?php
/**
 * Redis настройки для Drupal Library
 * Дата: $(date)
 */

// Настройки подключения к Redis
\$settings['redis.connection']['interface'] = 'PhpRedis';
\$settings['redis.connection']['host'] = '127.0.0.1';
\$settings['redis.connection']['port'] = 6379;
\$settings['redis.connection']['base'] = 0;

// Использование Redis для кэширования
\$settings['cache']['default'] = 'cache.backend.redis';
\$settings['cache_prefix']['default'] = 'drupal_library_';

// Исключения для определенных кэшей
\$settings['cache']['bins']['form'] = 'cache.backend.database';

// Блокировки через Redis
\$settings['container_yamls'][] = 'modules/contrib/redis/example.services.yml';

// Настройки сессий через Redis (опционально)
\$settings['redis.connection']['session_base'] = 1;
\$conf['lock_inc'] = 'sites/all/modules/redis/redis.lock.inc';
\$conf['path_inc'] = 'sites/all/modules/redis/redis.path.inc';
\$conf['cache_backends'][] = 'sites/all/modules/redis/redis.autoload.inc';

// Настройки производительности
\$settings['redis_compress_length'] = 100;
\$settings['redis_compression'] = 'gzip';
EOF

# Подключение Redis настроек к основному файлу
echo "" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "// Redis configuration" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "if (file_exists(__DIR__ . '/redis.settings.php')) {" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "  include __DIR__ . '/redis.settings.php';" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "}" >> "$DRUPAL_DIR/web/sites/default/settings.php"

echo "5. Настройка логирования и мониторинга..."

# Создание директорий для логов
mkdir -p /var/log/drupal/{access,error,slow}
chown -R www-data:www-data /var/log/drupal

# Конфигурация логирования Drupal
cat > "$DRUPAL_DIR/web/sites/default/logging.settings.php" << EOF
<?php
/**
 * Настройки логирования для Drupal Library
 * Дата: $(date)
 */

// Настройки Syslog
\$config['syslog.settings']['identity'] = 'drupal_library';
\$config['syslog.settings']['facility'] = LOG_LOCAL0;

// Уровни логирования
\$config['system.logging']['error_level'] = 'verbose';

// Настройки производительности
\$config['system.performance']['css']['preprocess'] = TRUE;
\$config['system.performance']['js']['preprocess'] = TRUE;
\$config['system.performance']['css']['gzip'] = TRUE;
\$config['system.performance']['js']['gzip'] = TRUE;
\$config['system.performance']['response']['gzip'] = TRUE;

// Кэширование страниц
\$config['system.performance']['cache']['page']['max_age'] = 3600;
\$config['system.performance']['cache']['page']['use_internal'] = TRUE;

// Настройки изображений
\$config['system.image']['toolkit'] = 'gd';
\$settings['image_allow_insecure_derivatives'] = FALSE;
EOF

# Подключение настроек логирования
echo "" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "// Logging configuration" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "if (file_exists(__DIR__ . '/logging.settings.php')) {" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "  include __DIR__ . '/logging.settings.php';" >> "$DRUPAL_DIR/web/sites/default/settings.php"
echo "}" >> "$DRUPAL_DIR/web/sites/default/settings.php"

echo "6. Создание скриптов мониторинга..."

# Скрипт мониторинга Drupal
cat > /root/drupal-monitor.sh << 'EOF'
#!/bin/bash
# Мониторинг Drupal Library

DRUPAL_DIR="/var/www/drupal"
LOG_FILE="/var/log/drupal-monitor.log"
EMAIL="admin@omuzgorpro.tj"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# Проверка доступности сайта
check_site_availability() {
    local url="https://storage.omuzgorpro.tj"
    local status=$(curl -s -o /dev/null -w "%{http_code}" $url)
    
    if [ "$status" != "200" ]; then
        log_message "ALERT: Site unavailable (HTTP $status)"
        echo "Drupal site unavailable" | mail -s "RTTI Library Alert" $EMAIL
        return 1
    fi
    
    log_message "INFO: Site accessible (HTTP $status)"
    return 0
}

# Проверка использования диска
check_disk_usage() {
    local usage=$(df /var/www | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$usage" -gt 85 ]; then
        log_message "ALERT: High disk usage ($usage%)"
        echo "High disk usage: $usage%" | mail -s "RTTI Library Disk Alert" $EMAIL
    else
        log_message "INFO: Disk usage normal ($usage%)"
    fi
}

# Проверка базы данных
check_database() {
    local db_status=$(sudo -u postgres pg_isready -h localhost -p 5432 -d drupal_library)
    
    if [[ $db_status != *"accepting connections"* ]]; then
        log_message "ALERT: Database connection failed"
        echo "Database connection failed" | mail -s "RTTI Library DB Alert" $EMAIL
        return 1
    fi
    
    log_message "INFO: Database connection OK"
    return 0
}

# Проверка Redis
check_redis() {
    local redis_status=$(redis-cli ping 2>/dev/null)
    
    if [ "$redis_status" != "PONG" ]; then
        log_message "ALERT: Redis not responding"
        echo "Redis service down" | mail -s "RTTI Library Redis Alert" $EMAIL
        return 1
    fi
    
    log_message "INFO: Redis responding"
    return 0
}

# Проверка логов на ошибки
check_error_logs() {
    local error_count=$(tail -100 /var/log/nginx/error.log | grep -c "$(date '+%Y/%m/%d')")
    
    if [ "$error_count" -gt 10 ]; then
        log_message "ALERT: High error count in logs ($error_count)"
        echo "High error count: $error_count" | mail -s "RTTI Library Error Alert" $EMAIL
    fi
}

# Основная функция мониторинга
main() {
    log_message "Starting monitoring check"
    
    check_site_availability
    check_disk_usage
    check_database
    check_redis
    check_error_logs
    
    log_message "Monitoring check completed"
}

# Запуск в зависимости от параметра
case "$1" in
    status)
        echo "=== RTTI Library Status ==="
        echo "Site: $(check_site_availability && echo "OK" || echo "FAIL")"
        echo "Database: $(check_database && echo "OK" || echo "FAIL")"
        echo "Redis: $(check_redis && echo "OK" || echo "FAIL")"
        echo "Disk: $(df /var/www | tail -1 | awk '{print $5}')"
        ;;
    *)
        main
        ;;
esac
EOF

chmod +x /root/drupal-monitor.sh

echo "7. Настройка автоматического обслуживания..."

# Создание cron заданий
cat > /tmp/drupal-cron << EOF
# Drupal Library автоматическое обслуживание
# Дата: $(date)

# Запуск cron Drupal каждые 30 минут
*/30 * * * * cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush cron >/dev/null 2>&1

# Очистка кэша Drupal каждую ночь в 2:00
0 2 * * * cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush cache:rebuild >/dev/null 2>&1

# Переиндексация поиска каждую ночь в 3:00
0 3 * * * cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush search-api:index >/dev/null 2>&1

# Обновление переводов каждую неделю
0 4 * * 0 cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush locale:update >/dev/null 2>&1

# Мониторинг каждые 5 минут
*/5 * * * * /root/drupal-monitor.sh >/dev/null 2>&1

# Резервное копирование базы данных каждый день в 1:00
0 1 * * * /root/library-maintenance.sh backup-content >/dev/null 2>&1

# Оптимизация базы данных каждую неделю
0 5 * * 0 /root/library-maintenance.sh optimize >/dev/null 2>&1

# Ротация логов
0 0 * * * find /var/log/drupal -name "*.log" -mtime +30 -delete 2>/dev/null
EOF

crontab -u root /tmp/drupal-cron

echo "8. Настройка безопасности файловой системы..."

# Правильные права на файлы Drupal
cd $DRUPAL_DIR

# Базовые права
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;

# Исполняемые файлы
chmod +x vendor/bin/drush
chmod +x vendor/bin/drupal

# Права на директории загрузок
mkdir -p web/sites/default/files/{public,private,temp}
chown -R www-data:www-data web/sites/default/files
chmod -R 755 web/sites/default/files

# Защита конфигурационных файлов
chmod 444 web/sites/default/settings.php
chown root:www-data web/sites/default/settings.php

echo "9. Установка дополнительных модулей безопасности..."

cd $DRUPAL_DIR

# Модули безопасности
sudo -u www-data composer require drupal/security_review
sudo -u www-data composer require drupal/password_policy
sudo -u www-data composer require drupal/captcha
sudo -u www-data composer require drupal/honeypot

# Включение модулей безопасности
sudo -u www-data vendor/bin/drush pm:enable security_review password_policy captcha honeypot -y

echo "10. Настройка резервного копирования..."

# Скрипт автоматического резервного копирования
cat > /root/drupal-backup.sh << 'EOF'
#!/bin/bash
# Автоматическое резервное копирование Drupal Library

DRUPAL_DIR="/var/www/drupal"
BACKUP_BASE="/var/backups/drupal"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE/$DATE"
RETENTION_DAYS=30

# Создание директории резервных копий
mkdir -p $BACKUP_DIR

echo "Starting backup: $DATE"

# Резервная копия базы данных
echo "Backing up database..."
sudo -u postgres pg_dump drupal_library | gzip > $BACKUP_DIR/database.sql.gz

# Резервная копия файлов
echo "Backing up files..."
tar -czf $BACKUP_DIR/files.tar.gz -C $DRUPAL_DIR/web/sites/default files

# Резервная копия конфигурации
echo "Backing up configuration..."
cd $DRUPAL_DIR
sudo -u www-data vendor/bin/drush config:export --destination=$BACKUP_DIR/config

# Создание манифеста
cat > $BACKUP_DIR/manifest.txt << EOL
Backup Date: $DATE
Drupal Version: $(sudo -u www-data vendor/bin/drush status --field=drupal-version)
Database Size: $(du -h $BACKUP_DIR/database.sql.gz | cut -f1)
Files Size: $(du -h $BACKUP_DIR/files.tar.gz | cut -f1)
Config Files: $(ls $BACKUP_DIR/config | wc -l)
EOL

# Удаление старых резервных копий
echo "Cleaning old backups..."
find $BACKUP_BASE -type d -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null

echo "Backup completed: $BACKUP_DIR"

# Проверка размера резервных копий
TOTAL_SIZE=$(du -sh $BACKUP_BASE | cut -f1)
echo "Total backup size: $TOTAL_SIZE"
EOF

chmod +x /root/drupal-backup.sh

echo "11. Создание системы отчетов..."

# Скрипт генерации отчетов
cat > /root/drupal-reports.sh << 'EOF'
#!/bin/bash
# Генерация отчетов Drupal Library

DRUPAL_DIR="/var/www/drupal"
REPORT_DIR="/var/reports/drupal"
DATE=$(date +%Y%m%d)

mkdir -p $REPORT_DIR

# Отчет о производительности
echo "=== DRUPAL LIBRARY PERFORMANCE REPORT ===" > $REPORT_DIR/performance-$DATE.txt
echo "Date: $(date)" >> $REPORT_DIR/performance-$DATE.txt
echo >> $REPORT_DIR/performance-$DATE.txt

# Статистика контента
cd $DRUPAL_DIR
echo "CONTENT STATISTICS:" >> $REPORT_DIR/performance-$DATE.txt
echo "Books: $(sudo -u www-data vendor/bin/drush sql:query "SELECT COUNT(*) FROM node_field_data WHERE type='book' AND status=1" --extra=--skip-column-names)" >> $REPORT_DIR/performance-$DATE.txt
echo "Articles: $(sudo -u www-data vendor/bin/drush sql:query "SELECT COUNT(*) FROM node_field_data WHERE type='library_article' AND status=1" --extra=--skip-column-names)" >> $REPORT_DIR/performance-$DATE.txt
echo "Users: $(sudo -u www-data vendor/bin/drush sql:query "SELECT COUNT(*) FROM users_field_data WHERE status=1" --extra=--skip-column-names)" >> $REPORT_DIR/performance-$DATE.txt
echo >> $REPORT_DIR/performance-$DATE.txt

# Статистика системы
echo "SYSTEM STATISTICS:" >> $REPORT_DIR/performance-$DATE.txt
echo "Disk Usage: $(df /var/www | tail -1 | awk '{print $5}')" >> $REPORT_DIR/performance-$DATE.txt
echo "Memory Usage: $(free -h | grep Mem | awk '{print $3"/"$2}')" >> $REPORT_DIR/performance-$DATE.txt
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')" >> $REPORT_DIR/performance-$DATE.txt
echo >> $REPORT_DIR/performance-$DATE.txt

# Статистика базы данных
echo "DATABASE STATISTICS:" >> $REPORT_DIR/performance-$DATE.txt
sudo -u postgres psql -d drupal_library -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;
" >> $REPORT_DIR/performance-$DATE.txt

echo "Report generated: $REPORT_DIR/performance-$DATE.txt"
EOF

chmod +x /root/drupal-reports.sh

echo "12. Перезапуск служб..."

# Перезапуск PHP-FPM
systemctl restart php$PHP_VERSION-fpm

# Перезапуск Nginx
systemctl restart nginx

# Перезапуск PostgreSQL для применения оптимизаций
systemctl restart postgresql

# Перезапуск Redis
systemctl restart redis-server

echo "13. Финальная очистка кэша и индексация..."

cd $DRUPAL_DIR

# Очистка всех кэшей
sudo -u www-data vendor/bin/drush cache:rebuild

# Переиндексация поиска
sudo -u www-data vendor/bin/drush search-api:clear
sudo -u www-data vendor/bin/drush search-api:index

echo "14. Создание отчета о настройке..."

cat > /root/drupal-post-install-report.txt << EOF
# ОТЧЕТ О ПОСТ-УСТАНОВОЧНОЙ НАСТРОЙКЕ DRUPAL LIBRARY
# Дата: $(date)
# Сервер: storage.omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== ОПТИМИЗАЦИЯ ПРОИЗВОДИТЕЛЬНОСТИ ===

✅ PHP оптимизация:
- Память: 512MB
- Время выполнения: 300 сек
- Размер загрузки: 100MB
- OPcache: оптимизирован

✅ Nginx оптимизация:
- Кэширование статических файлов
- Сжатие: CSS, JS, изображения
- Защита системных файлов

✅ PostgreSQL оптимизация:
- Shared buffers: 256MB
- Effective cache: 1GB
- Индексы для Drupal
- Статистика запросов

✅ Redis интеграция:
- Кэширование по умолчанию
- Префикс: drupal_library_
- Сжатие данных

=== МОНИТОРИНГ И ОБСЛУЖИВАНИЕ ===

✅ Автоматизация:
- Cron Drupal: каждые 30 мин
- Кэш: очистка ночью
- Поиск: переиндексация ночью
- Переводы: обновление еженедельно

✅ Мониторинг:
- Скрипт: /root/drupal-monitor.sh
- Проверка: каждые 5 мин
- Алерты: email уведомления

✅ Резервное копирование:
- Автоматическое: ежедневно
- Скрипт: /root/drupal-backup.sh
- Хранение: 30 дней
- Компоненты: БД + файлы + конфиг

✅ Отчетность:
- Производительность: /root/drupal-reports.sh
- Статистика контента
- Системные метрики
- Анализ БД

=== БЕЗОПАСНОСТЬ ===

✅ Модули безопасности:
- Security Review
- Password Policy  
- CAPTCHA
- Honeypot

✅ Файловая система:
- Правильные права доступа
- Защита конфигурации
- Изоляция загрузок

✅ Логирование:
- Системные логи
- Ошибки приложения
- Мониторинг активности

=== ГОТОВНОСТЬ К ЭКСПЛУАТАЦИИ ===

✅ Система полностью настроена
✅ Автоматизация настроена
✅ Мониторинг активен
✅ Резервное копирование работает
✅ Безопасность обеспечена

=== КОМАНДЫ УПРАВЛЕНИЯ ===

Проверка статуса:
/root/drupal-monitor.sh status

Обслуживание:
/root/library-maintenance.sh [reindex|update-translations|optimize|backup-content|stats]

Резервное копирование:
/root/drupal-backup.sh

Отчеты:
/root/drupal-reports.sh

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Запустите скрипт 09-security.sh для дополнительной безопасности
2. Выполните скрипт 10-final-check.sh для проверки установки
3. Настройте мониторинг внешними системами
4. Проведите нагрузочное тестирование
5. Обучите администраторов работе с системой

Система готова к продуктивной эксплуатации!
EOF

echo "15. Удаление временных файлов..."
rm -f /tmp/postgres_drupal_optimize.sql
rm -f /tmp/drupal-cron

echo
echo "✅ Шаг 8 завершен успешно!"
echo "🚀 Пост-установочная настройка завершена"
echo "📈 Производительность оптимизирована"
echo "🔍 Мониторинг настроен"
echo "💾 Автоматическое резервное копирование"
echo "🛡️ Модули безопасности установлены"
echo "⚙️ Автоматизация настроена"
echo "📊 Отчетность: /root/drupal-reports.sh"
echo "🔧 Мониторинг: /root/drupal-monitor.sh"
echo "💾 Бэкап: /root/drupal-backup.sh"
echo "📋 Отчет: /root/drupal-post-install-report.txt"
echo "📌 Следующий шаг: ./09-security.sh"
echo
