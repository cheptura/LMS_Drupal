#!/bin/bash

# RTTI Drupal Diagnostics Script
# Полная диагностика Drupal системы

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Drupal Diagnostics Script                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

echo "📅 Дата диагностики: $(date)"
echo "🖥️  Сервер: $(hostname)"
echo "🌐 IP адрес: $(hostname -I | awk '{print $1}')"
echo

# Переменные
DRUPAL_DIR="/var/www/html/drupal"
FILES_DIR="/var/drupaldata"

# Проверка существования Drupal
if [ ! -d "$DRUPAL_DIR" ]; then
    echo "❌ Drupal не найден в $DRUPAL_DIR"
    exit 1
fi

# Получение информации о Drupal
echo "📚 ИНФОРМАЦИЯ О DRUPAL"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ -f "$DRUPAL_DIR/core/lib/Drupal.php" ]; then
    cd $DRUPAL_DIR
    DRUPAL_VERSION=$(sudo -u www-data vendor/bin/drush status --field=drupal-version 2>/dev/null || echo "Неизвестно")
    DB_STATUS=$(sudo -u www-data vendor/bin/drush status --field=db-status 2>/dev/null || echo "Неизвестно")
    BOOTSTRAP=$(sudo -u www-data vendor/bin/drush status --field=bootstrap 2>/dev/null || echo "Неизвестно")
    
    echo "📋 Версия Drupal: $DRUPAL_VERSION"
    echo "🗄️  Статус БД: $DB_STATUS"
    echo "🚀 Загрузка: $BOOTSTRAP"
else
    echo "❌ Основные файлы Drupal не найдены"
fi

echo "📂 Директория Drupal: $DRUPAL_DIR"
echo "📁 Директория файлов: $FILES_DIR"
echo

# Проверка конфигурации
echo "⚙️  КОНФИГУРАЦИЯ DRUPAL"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ -f "$DRUPAL_DIR/sites/default/settings.php" ]; then
    echo "✅ Файл settings.php найден"
    
    # Извлечение настроек БД
    if grep -q "database.*=>" "$DRUPAL_DIR/sites/default/settings.php"; then
        DB_NAME=$(grep "database.*=>" "$DRUPAL_DIR/sites/default/settings.php" | head -1 | cut -d"'" -f2)
        DB_HOST=$(grep "host.*=>" "$DRUPAL_DIR/sites/default/settings.php" | head -1 | cut -d"'" -f2)
        DB_USER=$(grep "username.*=>" "$DRUPAL_DIR/sites/default/settings.php" | head -1 | cut -d"'" -f2)
        
        echo "🗄️  Имя БД: $DB_NAME"
        echo "🌐 Хост БД: $DB_HOST"
        echo "👤 Пользователь БД: $DB_USER"
    fi
    
    # Проверка trusted hosts
    if grep -q "trusted_host_patterns" "$DRUPAL_DIR/sites/default/settings.php"; then
        echo "✅ Trusted host patterns: Настроены"
    else
        echo "⚠️  Trusted host patterns: Не настроены"
    fi
else
    echo "❌ Файл settings.php не найден"
fi

# Проверка composer.json
if [ -f "$DRUPAL_DIR/composer.json" ]; then
    echo "✅ Composer.json найден"
    if [ -f "$DRUPAL_DIR/composer.lock" ]; then
        echo "✅ Composer.lock найден"
    else
        echo "⚠️  Composer.lock отсутствует"
    fi
else
    echo "❌ Composer.json не найден"
fi
echo

# Проверка прав доступа
echo "🔐 ПРАВА ДОСТУПА"
echo "═══════════════════════════════════════════════════════════════════════════════"

DRUPAL_OWNER=$(stat -c '%U:%G' $DRUPAL_DIR)
DRUPAL_PERMS=$(stat -c '%a' $DRUPAL_DIR)
echo "📂 Drupal директория: $DRUPAL_OWNER ($DRUPAL_PERMS)"

if [ -f "$DRUPAL_DIR/sites/default/settings.php" ]; then
    SETTINGS_OWNER=$(stat -c '%U:%G' "$DRUPAL_DIR/sites/default/settings.php")
    SETTINGS_PERMS=$(stat -c '%a' "$DRUPAL_DIR/sites/default/settings.php")
    echo "⚙️  Settings.php: $SETTINGS_OWNER ($SETTINGS_PERMS)"
fi

if [ -d "$DRUPAL_DIR/sites/default/files" ]; then
    FILES_OWNER=$(stat -c '%U:%G' "$DRUPAL_DIR/sites/default/files")
    FILES_PERMS=$(stat -c '%a' "$DRUPAL_DIR/sites/default/files")
    echo "📁 Files директория: $FILES_OWNER ($FILES_PERMS)"
fi

if [ -d "$FILES_DIR" ]; then
    DATA_OWNER=$(stat -c '%U:%G' $FILES_DIR)
    DATA_PERMS=$(stat -c '%a' $FILES_DIR)
    echo "📁 Данные Drupal: $DATA_OWNER ($DATA_PERMS)"
else
    echo "ℹ️  Внешняя директория файлов не найдена"
fi
echo

# Проверка модулей
echo "🧩 МОДУЛИ DRUPAL"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ -d "$DRUPAL_DIR" ]; then
    cd $DRUPAL_DIR
    
    # Количество модулей
    ENABLED_MODULES=$(sudo -u www-data vendor/bin/drush pml --status=enabled --no-core --format=list 2>/dev/null | wc -l)
    echo "✅ Включенных модулей: $ENABLED_MODULES"
    
    # Проверка критических модулей
    CRITICAL_MODULES=("node" "user" "system" "field" "text")
    for module in "${CRITICAL_MODULES[@]}"; do
        if sudo -u www-data vendor/bin/drush pml --status=enabled --format=list 2>/dev/null | grep -q "^$module$"; then
            echo "✅ Модуль $module: Включен"
        else
            echo "❌ Модуль $module: Не включен"
        fi
    done
    
    # Проверка обновлений
    UPDATES=$(sudo -u www-data vendor/bin/drush ups --format=list 2>/dev/null | wc -l)
    if [ $UPDATES -gt 0 ]; then
        echo "📦 Доступно обновлений: $UPDATES"
    else
        echo "✅ Все модули актуальны"
    fi
fi
echo

# Проверка базы данных
echo "🗄️  БАЗА ДАННЫХ"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ ! -z "$DB_NAME" ] && [ ! -z "$DB_USER" ]; then
    # Проверка подключения к БД
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "✅ База данных '$DB_NAME' существует"
        
        # Размер БД
        DB_SIZE=$(sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" -t | xargs)
        echo "📊 Размер БД: $DB_SIZE"
        
        # Количество таблиц
        TABLE_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" -t | xargs)
        echo "📋 Количество таблиц: $TABLE_COUNT"
        
        # Проверка основных таблиц Drupal
        CORE_TABLES=("config" "users" "node" "cache_default")
        for table in "${CORE_TABLES[@]}"; do
            if sudo -u postgres psql -d "$DB_NAME" -c "\dt $table" | grep -q "$table"; then
                echo "✅ Таблица $table: Найдена"
            else
                echo "❌ Таблица $table: Не найдена"
            fi
        done
        
        # Проверка состояния через Drush
        if [ -d "$DRUPAL_DIR" ]; then
            cd $DRUPAL_DIR
            DB_UPDATES=$(sudo -u www-data vendor/bin/drush updatedb --no-cache-clear --dry-run 2>/dev/null | grep "No pending updates" && echo "0" || echo "Есть")
            echo "🔄 Обновления БД: $DB_UPDATES"
        fi
    else
        echo "❌ База данных '$DB_NAME' не найдена"
    fi
else
    echo "❌ Параметры БД не определены"
fi
echo

# Проверка веб-сервера
echo "🌐 ВЕБ-СЕРВЕР"
echo "═══════════════════════════════════════════════════════════════════════════════"

if systemctl is-active --quiet nginx; then
    echo "✅ Nginx: Активен"
    
    # Проверка конфигурации Nginx
    if nginx -t &>/dev/null; then
        echo "✅ Конфигурация Nginx: Корректная"
    else
        echo "❌ Конфигурация Nginx: Ошибки найдены"
    fi
    
    # Проверка виртуального хоста
    if [ -f "/etc/nginx/sites-enabled/drupal" ] || [ -f "/etc/nginx/sites-enabled/library" ]; then
        echo "✅ Виртуальный хост: Настроен"
    else
        echo "❌ Виртуальный хост: Не найден"
    fi
else
    echo "❌ Nginx: Не активен"
fi

# Проверка PHP
PHP_VERSION=$(php -v | head -1 | awk '{print $2}')
echo "🐘 PHP версия: $PHP_VERSION"

if systemctl is-active --quiet php8.3-fpm; then
    echo "✅ PHP-FPM: Активен"
else
    echo "❌ PHP-FPM: Не активен"
fi

# Проверка необходимых расширений PHP
REQUIRED_EXTENSIONS=("pdo" "pdo_pgsql" "gd" "curl" "mbstring" "xml" "zip" "opcache")
echo "🔌 PHP расширения:"
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -q "$ext"; then
        echo "   ✅ $ext"
    else
        echo "   ❌ $ext"
    fi
done
echo

# Проверка производительности
echo "⚡ ПРОИЗВОДИТЕЛЬНОСТЬ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Использование диска
DISK_USAGE=$(df $DRUPAL_DIR | awk 'NR==2 {print $5}')
echo "💽 Использование диска: $DISK_USAGE"

# Размер директории Drupal
DRUPAL_SIZE=$(du -sh $DRUPAL_DIR | awk '{print $1}')
echo "📂 Размер Drupal: $DRUPAL_SIZE"

if [ -d "$DRUPAL_DIR/sites/default/files" ]; then
    FILES_SIZE=$(du -sh $DRUPAL_DIR/sites/default/files | awk '{print $1}')
    echo "📁 Размер файлов: $FILES_SIZE"
fi

# Проверка кэша
if [ -d "$DRUPAL_DIR" ]; then
    cd $DRUPAL_DIR
    CACHE_STATUS=$(sudo -u www-data vendor/bin/drush status --field=theme 2>/dev/null || echo "Неизвестно")
    echo "🗄️  Статус кэша: $CACHE_STATUS"
fi
echo

# Проверка безопасности
echo "🛡️  БЕЗОПАСНОСТЬ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Проверка статуса обслуживания
if [ -d "$DRUPAL_DIR" ]; then
    cd $DRUPAL_DIR
    MAINTENANCE=$(sudo -u www-data vendor/bin/drush state:get system.maintenance_mode 2>/dev/null || echo "0")
    if [ "$MAINTENANCE" = "1" ]; then
        echo "⚠️  Режим обслуживания: Включен"
    else
        echo "✅ Режим обслуживания: Выключен"
    fi
fi

# Проверка прав на settings.php
if [ -f "$DRUPAL_DIR/sites/default/settings.php" ]; then
    SETTINGS_PERMS=$(stat -c '%a' "$DRUPAL_DIR/sites/default/settings.php")
    if [ "$SETTINGS_PERMS" = "444" ] || [ "$SETTINGS_PERMS" = "644" ]; then
        echo "✅ Права settings.php: Безопасные ($SETTINGS_PERMS)"
    else
        echo "⚠️  Права settings.php: Небезопасные ($SETTINGS_PERMS)"
    fi
fi

# Проверка SSL
SITE_URL=$(grep "base_url" "$DRUPAL_DIR/sites/default/settings.php" 2>/dev/null | cut -d"'" -f2 || echo "")
if [[ "$SITE_URL" == https://* ]]; then
    DOMAIN=$(echo "$SITE_URL" | sed 's|https://||' | sed 's|/.*||')
    if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
        echo "✅ SSL сертификат: Найден для $DOMAIN"
    else
        echo "❌ SSL сертификат: Не найден для $DOMAIN"
    fi
else
    echo "ℹ️  SSL: Не настроен"
fi
echo

# Рекомендации
echo "💡 РЕКОМЕНДАЦИИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ -d "$DRUPAL_DIR" ]; then
    cd $DRUPAL_DIR
    
    # Проверка обновлений безопасности
    SECURITY_UPDATES=$(sudo -u www-data vendor/bin/drush ups --security-only --format=list 2>/dev/null | wc -l)
    if [ $SECURITY_UPDATES -gt 0 ]; then
        echo "🚨 Критично: Доступно $SECURITY_UPDATES обновлений безопасности"
        echo "   Выполните: vendor/bin/drush ups --security-only"
    fi
    
    # Проверка кэша
    echo "🧹 Рекомендуется очистка кэша:"
    echo "   vendor/bin/drush cache:rebuild"
    
    # Проверка cron
    CRON_LAST=$(sudo -u www-data vendor/bin/drush state:get system.cron_last 2>/dev/null || echo "0")
    if [ "$CRON_LAST" != "0" ]; then
        CRON_AGE=$(($(date +%s) - $CRON_LAST))
        if [ $CRON_AGE -gt 86400 ]; then
            echo "⚠️  Cron не запускался больше суток"
            echo "   Выполните: vendor/bin/drush cron"
        fi
    fi
fi

echo
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                           Диагностика завершена                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "📋 Для углубленной диагностики используйте:"
echo "   cd $DRUPAL_DIR"
echo "   sudo -u www-data vendor/bin/drush status"
echo "   sudo -u www-data vendor/bin/drush requirements"
