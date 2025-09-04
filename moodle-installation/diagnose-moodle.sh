#!/bin/bash

# RTTI Moodle Diagnostics Script
# Полная диагностика Moodle системы

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Moodle Diagnostics Script                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

echo "📅 Дата диагностики: $(date)"
echo "🖥️  Сервер: $(hostname)"
echo "🌐 IP адрес: $(hostname -I | awk '{print $1}')"
echo

# Переменные
MOODLE_DIR="/var/www/html/moodle"
DATA_DIR="/var/moodledata"

# Проверка существования Moodle
if [ ! -d "$MOODLE_DIR" ]; then
    echo "❌ Moodle не найден в $MOODLE_DIR"
    exit 1
fi

# Получение информации о Moodle
echo "🎓 ИНФОРМАЦИЯ О MOODLE"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ -f "$MOODLE_DIR/version.php" ]; then
    MOODLE_VERSION=$(grep '$release' $MOODLE_DIR/version.php | cut -d"'" -f2)
    MOODLE_BUILD=$(grep '$version' $MOODLE_DIR/version.php | head -1 | grep -o '[0-9]*')
    echo "📋 Версия Moodle: $MOODLE_VERSION"
    echo "🔢 Номер сборки: $MOODLE_BUILD"
else
    echo "❌ Файл version.php не найден"
fi

echo "📂 Директория Moodle: $MOODLE_DIR"
echo "📁 Директория данных: $DATA_DIR"
echo

# Проверка конфигурации
echo "⚙️  КОНФИГУРАЦИЯ MOODLE"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ -f "$MOODLE_DIR/config.php" ]; then
    echo "✅ Файл config.php найден"
    
    # Извлечение настроек БД
    DB_TYPE=$(grep 'dbtype' $MOODLE_DIR/config.php | cut -d"'" -f2)
    DB_HOST=$(grep 'dbhost' $MOODLE_DIR/config.php | cut -d"'" -f2)
    DB_NAME=$(grep 'dbname' $MOODLE_DIR/config.php | cut -d"'" -f2)
    DB_USER=$(grep 'dbuser' $MOODLE_DIR/config.php | cut -d"'" -f2)
    WWW_ROOT=$(grep 'wwwroot' $MOODLE_DIR/config.php | cut -d"'" -f2)
    
    echo "🗄️  Тип БД: $DB_TYPE"
    echo "🌐 Хост БД: $DB_HOST"
    echo "📊 Имя БД: $DB_NAME"
    echo "👤 Пользователь БД: $DB_USER"
    echo "🌍 WWW Root: $WWW_ROOT"
else
    echo "❌ Файл config.php не найден"
fi
echo

# Проверка прав доступа
echo "🔐 ПРАВА ДОСТУПА"
echo "═══════════════════════════════════════════════════════════════════════════════"

MOODLE_OWNER=$(stat -c '%U:%G' $MOODLE_DIR)
MOODLE_PERMS=$(stat -c '%a' $MOODLE_DIR)
echo "📂 Moodle директория: $MOODLE_OWNER ($MOODLE_PERMS)"

if [ -d "$DATA_DIR" ]; then
    DATA_OWNER=$(stat -c '%U:%G' $DATA_DIR)
    DATA_PERMS=$(stat -c '%a' $DATA_DIR)
    echo "📁 Данные Moodle: $DATA_OWNER ($DATA_PERMS)"
else
    echo "❌ Директория данных не найдена: $DATA_DIR"
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
        
        # Проверка основных таблиц Moodle
        CORE_TABLES=("mdl_config" "mdl_user" "mdl_course" "mdl_modules")
        for table in "${CORE_TABLES[@]}"; do
            if sudo -u postgres psql -d "$DB_NAME" -c "\dt $table" | grep -q "$table"; then
                echo "✅ Таблица $table: Найдена"
            else
                echo "❌ Таблица $table: Не найдена"
            fi
        done
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
    if [ -f "/etc/nginx/sites-enabled/moodle" ]; then
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

if systemctl is-active --quiet php8.2-fpm; then
    echo "✅ PHP-FPM: Активен"
else
    echo "❌ PHP-FPM: Не активен"
fi
echo

# Проверка SSL
echo "🔒 SSL СЕРТИФИКАТЫ"
echo "═══════════════════════════════════════════════════════════════════════════════"

if [ ! -z "$WWW_ROOT" ] && [[ "$WWW_ROOT" == https://* ]]; then
    DOMAIN=$(echo "$WWW_ROOT" | sed 's|https://||' | sed 's|/.*||')
    
    if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
        echo "✅ SSL сертификат найден для $DOMAIN"
        
        # Проверка срока действия
        CERT_EXPIRY=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" | cut -d= -f2)
        echo "📅 Действует до: $CERT_EXPIRY"
        
        # Проверка оставшихся дней
        DAYS_LEFT=$(openssl x509 -checkend 0 -noout -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" && echo "Valid" || echo "Expired")
        echo "⏰ Статус: $DAYS_LEFT"
    else
        echo "❌ SSL сертификат не найден для $DOMAIN"
    fi
else
    echo "ℹ️  SSL не настроен (HTTP сайт)"
fi
echo

# Проверка производительности
echo "⚡ ПРОИЗВОДИТЕЛЬНОСТЬ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Использование диска
DISK_USAGE=$(df $MOODLE_DIR | awk 'NR==2 {print $5}')
echo "💽 Использование диска: $DISK_USAGE"

# Размер директории Moodle
MOODLE_SIZE=$(du -sh $MOODLE_DIR | awk '{print $1}')
echo "📂 Размер Moodle: $MOODLE_SIZE"

if [ -d "$DATA_DIR" ]; then
    DATA_SIZE=$(du -sh $DATA_DIR | awk '{print $1}')
    echo "📁 Размер данных: $DATA_SIZE"
fi

# Проверка кэша
if [ -d "$DATA_DIR/cache" ]; then
    CACHE_SIZE=$(du -sh $DATA_DIR/cache | awk '{print $1}')
    echo "🗄️  Размер кэша: $CACHE_SIZE"
fi
echo

# Проверка логов
echo "📋 ЛОГИ И ОШИБКИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Логи Nginx
if [ -f "/var/log/nginx/error.log" ]; then
    NGINX_ERRORS=$(tail -100 /var/log/nginx/error.log | grep "$(date +%Y/%m/%d)" | wc -l)
    echo "🌐 Ошибки Nginx сегодня: $NGINX_ERRORS"
fi

# Логи PHP
if [ -f "/var/log/php8.2-fpm.log" ]; then
    PHP_ERRORS=$(tail -100 /var/log/php8.2-fpm.log | grep "$(date +%Y-%m-%d)" | wc -l)
    echo "🐘 Ошибки PHP сегодня: $PHP_ERRORS"
fi

# Логи установки
if [ -d "/var/log/rtti-installation" ]; then
    echo "✅ Логи установки найдены"
    LATEST_LOG=$(ls -t /var/log/rtti-installation/moodle-install-*.log 2>/dev/null | head -1)
    if [ ! -z "$LATEST_LOG" ]; then
        echo "📄 Последний лог: $(basename $LATEST_LOG)"
    fi
else
    echo "ℹ️  Логи установки не найдены"
fi
echo

# Рекомендации
echo "💡 РЕКОМЕНДАЦИИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Проверка обновлений
if [ -f "$MOODLE_DIR/admin/cli/check_database_schema.php" ]; then
    echo "🔍 Проверка схемы БД..."
    cd $MOODLE_DIR
    sudo -u www-data php admin/cli/check_database_schema.php --help >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Схема БД актуальна"
    else
        echo "⚠️  Возможны проблемы со схемой БД"
    fi
fi

# Проверка кэша
if [ -d "$DATA_DIR/cache" ]; then
    CACHE_FILES=$(find $DATA_DIR/cache -type f | wc -l)
    if [ $CACHE_FILES -gt 10000 ]; then
        echo "⚠️  Большое количество файлов кэша ($CACHE_FILES) - рекомендуется очистка"
        echo "   Выполните: php admin/cli/purge_caches.php"
    fi
fi

echo
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                           Диагностика завершена                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "📋 Для углубленной диагностики используйте:"
echo "   cd $MOODLE_DIR"
echo "   sudo -u www-data php admin/cli/check_database_schema.php"
echo "   sudo -u www-data php admin/environment.xml"
