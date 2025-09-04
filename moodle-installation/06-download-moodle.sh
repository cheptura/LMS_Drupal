#!/bin/bash

# RTTI Moodle - Шаг 6: Загрузка Moodle
# Сервер: lms.rtti.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 6: Загрузка и подготовка Moodle 5.0+ ==="
echo "📦 Загрузка последней стабильной версии Moodle"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

MOODLE_VERSION="MOODLE_500_STABLE"  # Moodle 5.0.2+ стабильная версия
MOODLE_DIR="/var/www/moodle"
BACKUP_DIR="/root/moodle-backup-$(date +%Y%m%d-%H%M%S)"

echo "1. Создание резервной копии если Moodle уже установлен..."
if [ -d "$MOODLE_DIR" ]; then
    echo "Найдена существующая установка Moodle, создание резервной копии..."
    mkdir -p $BACKUP_DIR
    cp -r $MOODLE_DIR $BACKUP_DIR/
    echo "✅ Резервная копия создана: $BACKUP_DIR"
fi

echo "2. Установка Git для загрузки Moodle..."
apt install -y git

echo "3. Создание каталога для Moodle..."
mkdir -p $MOODLE_DIR
cd $MOODLE_DIR

echo "4. Загрузка Moodle 5.0.2+ из официального репозитория..."
echo "Загружается версия: $MOODLE_VERSION"

# Основной метод - загрузка стабильной ветки Moodle 5.0
git clone --depth=1 --branch $MOODLE_VERSION https://github.com/moodle/moodle.git temp_moodle

if [ $? -eq 0 ]; then
    # Перемещение файлов из временного каталога
    mv temp_moodle/* ./
    mv temp_moodle/.* ./ 2>/dev/null || true
    rmdir temp_moodle
    echo "✅ Moodle 5.0+ загружен через Git"
else
    echo "❌ Ошибка загрузки через Git, пробуем архив"
    
    # Альтернативный метод - загрузка архива Moodle 5.0.2+
    cd /tmp
    MOODLE_URL="https://download.moodle.org/download.php/direct/stable500/moodle-latest-500.tgz"
    echo "Загрузка Moodle 5.0.2+ с $MOODLE_URL"
    wget -O moodle-5.0-latest.tgz "$MOODLE_URL"
    
    if [ $? -eq 0 ]; then
        tar -xzf moodle-5.0-latest.tgz
        rm -rf $MOODLE_DIR/*
        mv moodle/* $MOODLE_DIR/
        rm -rf moodle moodle-5.0-latest.tgz
        echo "✅ Moodle 5.0.2+ загружен через архив"
    else
        echo "❌ Не удалось загрузить Moodle 5.0"
        echo "Пробуем резервную ссылку..."
        
        # Резервная ссылка для загрузки
        MOODLE_BACKUP_URL="https://download.moodle.org/releases/latest/moodle-latest.tgz"
        wget -O moodle-latest.tgz "$MOODLE_BACKUP_URL"
        
        if [ $? -eq 0 ]; then
            tar -xzf moodle-latest.tgz
            rm -rf $MOODLE_DIR/*
            mv moodle/* $MOODLE_DIR/
            rm -rf moodle moodle-latest.tgz
            echo "✅ Moodle загружен с резервной ссылки"
        else
            echo "❌ Не удалось загрузить Moodle"
            exit 1
        fi
    fi
fi

echo "5. Проверка загруженных файлов..."
if [ ! -f "$MOODLE_DIR/version.php" ]; then
    echo "❌ Файлы Moodle не найдены"
    exit 1
fi

echo "6. Определение версии Moodle..."
MOODLE_INFO=$(grep -E "(release|version)" $MOODLE_DIR/version.php | head -2)
echo "Информация о версии Moodle:"
echo "$MOODLE_INFO"

echo "7. Настройка прав доступа..."
chown -R www-data:www-data $MOODLE_DIR
find $MOODLE_DIR -type d -exec chmod 755 {} \;
find $MOODLE_DIR -type f -exec chmod 644 {} \;

echo "8. Создание каталога для данных Moodle..."
MOODLEDATA_DIR="/var/moodledata"
if [ ! -d "$MOODLEDATA_DIR" ]; then
    mkdir -p $MOODLEDATA_DIR
fi
chown -R www-data:www-data $MOODLEDATA_DIR
chmod -R 755 $MOODLEDATA_DIR

echo "9. Создание каталога для кэша..."
CACHE_DIR="/var/cache/moodle"
mkdir -p $CACHE_DIR
chown -R www-data:www-data $CACHE_DIR
chmod -R 755 $CACHE_DIR

echo "10. Подготовка конфигурационного файла..."
CONFIG_TEMPLATE="$MOODLE_DIR/config-dist.php"
CONFIG_FILE="$MOODLE_DIR/config.php"

if [ -f "$CONFIG_TEMPLATE" ]; then
    cp $CONFIG_TEMPLATE $CONFIG_FILE
    echo "✅ Шаблон конфигурации скопирован"
else
    echo "⚠️  Шаблон конфигурации не найден, создается базовый"
    cat > $CONFIG_FILE << 'EOF'
<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

// Database configuration will be added in next step
// $CFG->dbtype    = 'pgsql';
// $CFG->dblibrary = 'native';
// $CFG->dbhost    = 'localhost';
// $CFG->dbname    = 'moodle';
// $CFG->dbuser    = 'moodleuser';
// $CFG->dbpass    = 'password';
// $CFG->prefix    = 'mdl_';
// $CFG->dboptions = array(
//     'dbpersist' => 0,
//     'dbport' => '',
//     'dbsocket' => '',
//     'dbcollation' => 'utf8_unicode_ci',
// );

$CFG->wwwroot   = 'https://lms.rtti.tj';
$CFG->dataroot  = '/var/moodledata';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 0755;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF
fi

echo "11. Настройка базовых прав для конфигурации..."
chown www-data:www-data $CONFIG_FILE
chmod 644 $CONFIG_FILE

echo "12. Проверка необходимых PHP расширений для Moodle..."
echo "Проверка PHP расширений..."
php -m | grep -E "(curl|zip|gd|pgsql|redis|mbstring|xml|intl|json)" > /tmp/php_extensions.txt

REQUIRED_EXTENSIONS=("curl" "zip" "gd" "pgsql" "redis" "mbstring" "xml" "intl" "json")
MISSING_EXTENSIONS=()

for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if ! grep -q "^$ext$" /tmp/php_extensions.txt; then
        MISSING_EXTENSIONS+=("$ext")
    fi
done

if [ ${#MISSING_EXTENSIONS[@]} -gt 0 ]; then
    echo "⚠️  Отсутствуют PHP расширения: ${MISSING_EXTENSIONS[*]}"
    echo "Установка недостающих расширений..."
    for ext in "${MISSING_EXTENSIONS[@]}"; do
        apt install -y php8.3-$ext
    done

    # Перезапуск PHP 8.3 FPM
    echo "Перезапуск PHP 8.3 FPM..."
    systemctl restart php8.3-fpm
    if systemctl is-active --quiet php8.3-fpm; then
        echo "✅ PHP 8.3 FPM перезапущен"
    else
        echo "❌ Ошибка перезапуска PHP 8.3 FPM"
        echo "Проверьте: systemctl status php8.3-fpm"
    fi
fi

echo "13. Создание скрипта обновления Moodle..."
cat > /root/update-moodle.sh << EOF
#!/bin/bash
# Скрипт обновления Moodle

echo "=== Обновление Moodle ==="
BACKUP_DIR="/root/moodle-backup-\$(date +%Y%m%d-%H%M%S)"
MOODLE_DIR="$MOODLE_DIR"

echo "1. Создание резервной копии..."
mkdir -p \$BACKUP_DIR
cp -r \$MOODLE_DIR \$BACKUP_DIR/
cp -r /var/moodledata \$BACKUP_DIR/

echo "2. Перевод сайта в режим обслуживания..."
sudo -u www-data php \$MOODLE_DIR/admin/cli/maintenance.php --enable

echo "3. Загрузка последней версии..."
cd \$MOODLE_DIR
git fetch
git reset --hard origin/$MOODLE_VERSION

echo "4. Обновление через CLI..."
sudo -u www-data php \$MOODLE_DIR/admin/cli/upgrade.php --non-interactive

echo "5. Отключение режима обслуживания..."
sudo -u www-data php \$MOODLE_DIR/admin/cli/maintenance.php --disable

echo "✅ Обновление завершено"
echo "Резервная копия: \$BACKUP_DIR"
EOF

chmod +x /root/update-moodle.sh

echo "14. Создание информационного файла..."
cat > /root/moodle-installation-info.txt << EOF
# Информация об установке Moodle
# Дата создания: $(date)
# Сервер: lms.rtti.tj ($(hostname -I | awk '{print $1}'))

Путь к Moodle: $MOODLE_DIR
Путь к данным: $MOODLEDATA_DIR
Конфигурация: $CONFIG_FILE
Кэш: $CACHE_DIR

Версия Moodle:
$MOODLE_INFO

# Важные команды:
# Режим обслуживания ВКЛ: sudo -u www-data php $MOODLE_DIR/admin/cli/maintenance.php --enable
# Режим обслуживания ВЫКЛ: sudo -u www-data php $MOODLE_DIR/admin/cli/maintenance.php --disable
# Обновление кэша: sudo -u www-data php $MOODLE_DIR/admin/cli/purge_caches.php
# Переиндексация: sudo -u www-data php $MOODLE_DIR/admin/cli/search_index.php --reindex

# Скрипты:
# Обновление Moodle: /root/update-moodle.sh

# Резервные копии: $BACKUP_DIR (если была предыдущая установка)
EOF

echo "15. Создание тестовой страницы для проверки PHP..."
cat > $MOODLE_DIR/phpinfo.php << 'EOF'
<?php
// Временная страница для проверки PHP
// УДАЛИТЬ ПОСЛЕ УСТАНОВКИ!
echo "<h1>RTTI Moodle - PHP Test</h1>";
echo "<p>Сервер: " . $_SERVER['SERVER_NAME'] . "</p>";
echo "<p>PHP версия: " . phpversion() . "</p>";
echo "<p>Время: " . date('Y-m-d H:i:s') . "</p>";

// Проверка расширений
$extensions = ['pgsql', 'redis', 'gd', 'curl', 'zip', 'mbstring', 'xml', 'intl'];
echo "<h2>PHP Расширения:</h2><ul>";
foreach ($extensions as $ext) {
    $status = extension_loaded($ext) ? "✅" : "❌";
    echo "<li>$ext: $status</li>";
}
echo "</ul>";

// Информация о Moodle
if (file_exists(__DIR__ . '/version.php')) {
    echo "<h2>Moodle готов к установке ✅</h2>";
} else {
    echo "<h2>Ошибка: файлы Moodle не найдены ❌</h2>";
}
?>
EOF

chown www-data:www-data $MOODLE_DIR/phpinfo.php

echo "16. Проверка структуры файлов..."
echo "Основные файлы Moodle:"
ls -la $MOODLE_DIR/ | grep -E "(index\.php|version\.php|config\.php|admin)"

echo
echo "✅ Шаг 6 завершен успешно!"
echo "📌 Moodle загружен в $MOODLE_DIR"
echo "📌 Данные будут в $MOODLEDATA_DIR"
echo "📌 Конфигурация: $CONFIG_FILE"
echo "📌 Информация: /root/moodle-installation-info.txt"
echo "📌 Скрипт обновления: /root/update-moodle.sh"
echo "📌 Тест PHP: https://lms.rtti.tj/phpinfo.php (УДАЛИТЬ ПОСЛЕ УСТАНОВКИ!)"
echo "📌 Следующий шаг: ./07-configure-moodle.sh"
echo
