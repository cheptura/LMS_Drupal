#!/bin/bash

# RTTI Moodle - Шаг 7: Конфигурация Moodle
# Сервер: omuzgorpro.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 7: Конфигурация Moodle ==="
echo "⚙️  Настройка config.php и параметров"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

MOODLE_DIR="/var/www/moodle"
CONFIG_FILE="$MOODLE_DIR/config.php"

# Проверка существования необходимых файлов
if [ ! -d "$MOODLE_DIR" ]; then
    echo "❌ Каталог Moodle не найден: $MOODLE_DIR"
    exit 1
fi

if [ ! -f "/root/moodle-db-credentials.txt" ]; then
    echo "❌ Файл с данными БД не найден: /root/moodle-db-credentials.txt"
    exit 1
fi

if [ ! -f "/root/moodle-redis-credentials.txt" ]; then
    echo "❌ Файл с данными Redis не найден: /root/moodle-redis-credentials.txt"
    exit 1
fi

echo "1. Чтение данных подключения к базе данных..."
DB_PASSWORD=$(grep "Пароль:" /root/moodle-db-credentials.txt | awk '{print $2}')
if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Не удалось получить пароль базы данных"
    exit 1
fi

echo "2. Чтение данных подключения к Redis..."
REDIS_PASSWORD=$(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print $2}')
if [ -z "$REDIS_PASSWORD" ]; then
    echo "❌ Не удалось получить пароль Redis"
    exit 1
fi

echo "3. Создание резервной копии существующего config.php..."
if [ -f "$CONFIG_FILE" ]; then
    cp $CONFIG_FILE ${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)
fi

echo "4. Создание полной конфигурации Moodle..."
cat > $CONFIG_FILE << EOF
<?php  
// Moodle configuration file
// Generated: $(date)
// Server: omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

//=========================================================================
// 1. DATABASE SETUP
//=========================================================================
\$CFG->dbtype    = 'pgsql';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'moodleuser';
\$CFG->dbpass    = '$DB_PASSWORD';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => 5432,
    'dbsocket' => '',
);

//=========================================================================
// 2. WEB ADDRESSES
//=========================================================================
\$CFG->wwwroot   = 'https://omuzgorpro.tj';

//=========================================================================
// 3. DATA DIRECTORIES
//=========================================================================
\$CFG->dataroot  = '/var/moodledata';
\$CFG->tempdir = '/var/cache/moodle';
\$CFG->cachedir = '/var/cache/moodle';

//=========================================================================
// 4. ADMIN DIRECTORY
//=========================================================================
\$CFG->admin     = 'admin';

// Whether the Moodle router is fully configured (required for Moodle 4.5+)
\$CFG->routerconfigured = false;

//=========================================================================
// 5. SECURITY
//=========================================================================
\$CFG->directorypermissions = 0755;
\$CFG->forcelogin = false;
\$CFG->forceloginforprofiles = true;
\$CFG->opentogoogle = false;
\$CFG->protectusernames = true;

// SSL/HTTPS принудительно
\$CFG->forcessl = true;

// Защита от CSRF
\$CFG->cookiesecure = true;
\$CFG->cookiehttponly = true;

//=========================================================================
// 6. PERFORMANCE - CACHING
//=========================================================================
// Redis для сессий
\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '127.0.0.1';
\$CFG->session_redis_port = 6379;
\$CFG->session_redis_auth = '$REDIS_PASSWORD';
\$CFG->session_redis_database = 0;
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;

// Кэширование в Redis
\$CFG->cache_stores = array(
    'redis_cache' => array(
        'plugin' => 'redis',
        'configuration' => array(
            'server' => '127.0.0.1:6379',
            'password' => '$REDIS_PASSWORD',
            'prefix' => 'mdl_',
            'serializer' => Redis::SERIALIZER_PHP,
            'compressor' => Redis::COMPRESSION_NONE,
        ),
        'features' => Redis::SERIALIZER_PHP,
    ),
);

//=========================================================================
// 7. PERFORMANCE - GENERAL
//=========================================================================
\$CFG->enablecompletion = true;
\$CFG->completiondefault = true;

// Сжатие
\$CFG->enablegzip = true;
\$CFG->jsrev = 1;
\$CFG->cssrev = 1;

// Производительность
\$CFG->cachetemplates = true;
\$CFG->cachejs = true;

//=========================================================================
// 8. FILE UPLOADS
//=========================================================================
\$CFG->maxbytes = 104857600; // 100MB

//=========================================================================
// 9. EMAIL SETTINGS
//=========================================================================
\$CFG->smtphosts = 'localhost';
\$CFG->smtpuser = '';
\$CFG->smtppass = '';
\$CFG->smtpsecure = '';
\$CFG->smtpautotls = false;
\$CFG->noreplyaddress = 'noreply@omuzgorpro.tj';
\$CFG->supportemail = 'support@omuzgorpro.tj';

//=========================================================================
// 10. LOGGING
//=========================================================================
\$CFG->log_manager = '\core\log\manager';
\$CFG->log_stores = array(
    '\core\log\sql_reader' => array(
        'logformat' => 'standard',
        'buffersize' => 50,
        'logguests' => 1,
        'jsonformat' => 0,
    )
);

//=========================================================================
// 11. BACKUP SETTINGS
//=========================================================================
\$CFG->backup_auto_active = true;
\$CFG->backup_auto_weekdays = '0111110'; // Monday to Friday
\$CFG->backup_auto_hour = 2;
\$CFG->backup_auto_minute = 0;
\$CFG->backup_auto_storage = 0; // Course backup area
\$CFG->backup_auto_destination = '/var/moodledata/backup';
\$CFG->backup_auto_keep = 2;

//=========================================================================
// 12. LOCALIZATION
//=========================================================================
\$CFG->lang = 'ru';
\$CFG->timezone = 'Asia/Dushanbe';
\$CFG->country = 'TJ';

//=========================================================================
// 13. DEBUGGING (for production set to 0)
//=========================================================================
\$CFG->debug = 0;
\$CFG->debugdisplay = 0;
\$CFG->debugdeveloper = false;

//=========================================================================
// 14. MAINTENANCE
//=========================================================================
// \$CFG->maintenance_enabled = true;
// \$CFG->maintenance_message = 'Система находится на техническом обслуживании.';

//=========================================================================
// 15. CUSTOM SETTINGS
//=========================================================================
// Настройки для RTTI
\$CFG->theme = 'boost';
\$CFG->enableblogs = false;
\$CFG->enablerssfeeds = false;
\$CFG->enablewebservices = true;

// Ограничения безопасности
\$CFG->passwordpolicy = true;
\$CFG->minpasswordlength = 8;
\$CFG->minpassworddigits = 1;
\$CFG->minpasswordlower = 1;
\$CFG->minpasswordupper = 1;
\$CFG->minpasswordnonalphanum = 1;

//=========================================================================
// LOAD MOODLE
//=========================================================================
require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF

echo "5. Настройка прав доступа для config.php..."
chown www-data:www-data $CONFIG_FILE
chmod 644 $CONFIG_FILE

echo "6. Создание каталога для резервных копий..."
mkdir -p /var/moodledata/backup
chown -R www-data:www-data /var/moodledata/backup
chmod -R 755 /var/moodledata/backup

echo "7. Проверка подключения к базе данных..."
# Простая проверка подключения к PostgreSQL
sudo -u postgres psql -d moodle -c "SELECT version();" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Подключение к базе данных: OK"
else
    echo "❌ Подключение к базе данных: FAILED"
    echo "Проверьте:"
    echo "1. Запущен ли PostgreSQL: systemctl status postgresql"
    echo "2. Существует ли база moodle: sudo -u postgres psql -l | grep moodle"
    echo "3. Существует ли пользователь moodleuser"
    # Не завершаем скрипт, так как база может быть создана позже
fi

echo "8. Проверка подключения к Redis..."
# Простая проверка подключения к Redis
redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Подключение к Redis: OK"
else
    echo "❌ Подключение к Redis: FAILED"
    echo "Проверьте:"
    echo "1. Запущен ли Redis: systemctl status redis-server"
    echo "2. Правильный ли пароль в файле /root/moodle-redis-credentials.txt"
    echo "3. Конфигурацию Redis: /etc/redis/redis.conf"
    # Не завершаем скрипт, так как Redis может быть настроен позже
fi

echo "9. Проверка конфигурации PHP для Moodle..."
# Базовая проверка PHP без подключения к Moodle config
echo "PHP версия: $(php --version | head -1)"
echo "Доступные PHP модули для Moodle:"
php -m | grep -E "(pgsql|redis|curl|xml|mbstring|json|zip|gd|intl)" | head -10

echo "10. Создание скрипта диагностики..."
cat > /root/moodle-diagnostics.sh << EOF
#!/bin/bash
echo "=== Moodle Diagnostics ==="
echo "Дата: \$(date)"
echo

echo "1. PHP версия:"
php --version | head -1

echo -e "\n2. Статус веб-сервера:"
systemctl status nginx --no-pager -l | head -3

echo -e "\n3. Статус PHP-FPM:"
systemctl status php8.3-fpm --no-pager -l | head -3

echo -e "\n4. Статус PostgreSQL:"
systemctl status postgresql --no-pager -l | head -3

echo -e "\n5. Статус Redis:"
systemctl status redis-server --no-pager -l | head -3

echo -e "\n6. Подключение к БД:"
sudo -u www-data php -r "
try {
    \\\$pdo = new PDO('pgsql:host=localhost;dbname=moodle', 'moodleuser', '$DB_PASSWORD');
    echo 'Database: OK\n';
} catch (Exception \\\$e) {
    echo 'Database: FAILED\n';
}
"

echo -e "\n7. Подключение к Redis:"
sudo -u www-data php -r "
try {
    \\\$redis = new Redis();
    \\\$redis->connect('127.0.0.1', 6379);
    \\\$redis->auth('$REDIS_PASSWORD');
    echo 'Redis: OK\n';
} catch (Exception \\\$e) {
    echo 'Redis: FAILED\n';
}
"

echo -e "\n8. Права доступа:"
ls -la $MOODLE_DIR/ | head -5
echo "..."
ls -la /var/moodledata/ | head -5

echo -e "\n9. Дисковое пространство:"
df -h | grep -E "(Filesystem|/var|/)"

echo -e "\n10. SSL сертификат:"
openssl x509 -in /etc/letsencrypt/live/omuzgorpro.tj/fullchain.pem -noout -dates 2>/dev/null || echo "SSL: Не настроен"
EOF

chmod +x /root/moodle-diagnostics.sh

echo "11. Создание файла с параметрами конфигурации..."
cat > /root/moodle-config-summary.txt << EOF
# Сводка конфигурации Moodle
# Дата: $(date)
# Сервер: omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== ОСНОВНЫЕ ПАРАМЕТРЫ ===
URL: https://omuzgorpro.tj
Каталог: $MOODLE_DIR
Данные: /var/moodledata
Конфигурация: $CONFIG_FILE

=== БАЗА ДАННЫХ ===
Тип: PostgreSQL 16
База: moodle
Пользователь: moodleuser
Хост: localhost

=== КЭШИРОВАНИЕ ===
Сессии: Redis
Кэш приложения: Redis
Хост Redis: 127.0.0.1:6379

=== БЕЗОПАСНОСТЬ ===
SSL: Принудительно
Защита паролей: Включена
Минимальная длина пароля: 8 символов

=== ПРОИЗВОДИТЕЛЬНОСТЬ ===
Gzip: Включен
Кэширование шаблонов: Включено
Максимальный размер файла: 100MB

=== ЛОКАЛИЗАЦИЯ ===
Язык: Русский
Часовой пояс: Asia/Dushanbe
Страна: Таджикистан

=== РЕЗЕРВНОЕ КОПИРОВАНИЕ ===
Автоматическое: Включено
Время: 02:00 (Понедельник-Пятница)
Хранение: 2 копии
Путь: /var/moodledata/backup

=== КОМАНДЫ УПРАВЛЕНИЯ ===
Диагностика: /root/moodle-diagnostics.sh
Проверка PHP: php -f $MOODLE_DIR/admin/cli/check.php
Очистка кэша: sudo -u www-data php $MOODLE_DIR/admin/cli/purge_caches.php
Режим обслуживания: sudo -u www-data php $MOODLE_DIR/admin/cli/maintenance.php --enable/--disable
EOF

echo "12. Удаление тестового файла PHP..."
rm -f $MOODLE_DIR/phpinfo.php

echo "13. Финальная проверка конфигурации..."
echo "Проверка синтаксиса config.php:"
php -l $CONFIG_FILE

if [ $? -eq 0 ]; then
    echo "✅ Синтаксис config.php корректен"
else
    echo "❌ Ошибка синтаксиса config.php"
    exit 1
fi

echo "14. Проверка готовности к установке..."
if sudo -u www-data php -f $MOODLE_DIR/version.php >/dev/null 2>&1; then
    echo "✅ Moodle готов к установке"
else
    echo "⚠️  Возможны проблемы с конфигурацией"
fi

echo
echo "✅ Шаг 7 завершен успешно!"
echo "📌 Конфигурация Moodle создана: $CONFIG_FILE"
echo "📌 База данных настроена: PostgreSQL"
echo "📌 Кэширование настроено: Redis"
echo "📌 Диагностика: /root/moodle-diagnostics.sh"
echo "📌 Сводка настроек: /root/moodle-config-summary.txt"
echo "📌 Следующий шаг: ./08-install-moodle.sh"
echo
