#!/bin/bash

# RTTI Drupal - Исправление проблемы с отсутствующим OPcache
# Дата: $(date)

echo "=== Исправление проблемы с OPcache ==="
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./fix-opcache.sh"
    exit 1
fi

PHP_VERSION="8.3"

echo "🔍 Проверяем установку OPcache..."

# Проверяем, установлен ли OPcache
if php -m | grep -q "Zend OPcache"; then
    echo "✅ OPcache уже установлен"
    
    # Проверяем настройки
    echo "📋 Текущие настройки OPcache:"
    php -r "
    if (extension_loaded('Zend OPcache')) {
        echo 'OPcache включен: ' . (ini_get('opcache.enable') ? 'Да' : 'Нет') . PHP_EOL;
        echo 'Память: ' . ini_get('opcache.memory_consumption') . 'MB' . PHP_EOL;
        echo 'Макс. файлов: ' . ini_get('opcache.max_accelerated_files') . PHP_EOL;
        echo 'Валидация: ' . ini_get('opcache.validate_timestamps') . PHP_EOL;
    } else {
        echo 'OPcache не загружен' . PHP_EOL;
    }
    "
else
    echo "❌ OPcache не установлен, устанавливаем..."
    
    # Устанавливаем OPcache
    apt update
    apt install -y php${PHP_VERSION}-opcache
    
    if [ $? -eq 0 ]; then
        echo "✅ OPcache установлен успешно"
    else
        echo "❌ Ошибка установки OPcache"
        exit 1
    fi
fi

# Настраиваем OPcache для Drupal
OPCACHE_CONF="/etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini"

echo "🔧 Настраиваем OPcache для Drupal..."

# Создаем резервную копию если файл существует
if [ -f "$OPCACHE_CONF" ]; then
    cp "$OPCACHE_CONF" "$OPCACHE_CONF.backup.$(date +%Y%m%d-%H%M%S)"
    echo "✅ Создана резервная копия: $OPCACHE_CONF.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Создаем оптимизированную конфигурацию OPcache для Drupal
cat > "$OPCACHE_CONF" << 'EOF'
; configuration for php opcache module
; priority=10
zend_extension=opcache.so

; OPcache settings optimized for Drupal
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.max_wasted_percentage=5
opcache.use_cwd=1
opcache.validate_timestamps=1
opcache.revalidate_freq=2
opcache.revalidate_path=0
opcache.save_comments=1
opcache.load_comments=1
opcache.fast_shutdown=1
opcache.enable_file_override=0
opcache.optimization_level=0x7FFFBFFF
opcache.inherited_hack=1
opcache.dups_fix=0
opcache.blacklist_filename=/etc/php/8.3/opcache-blacklist.txt

; Drupal specific settings
opcache.max_file_size=0
opcache.consistency_checks=0
opcache.force_restart_timeout=180
opcache.error_log=""
opcache.log_verbosity_level=1
opcache.preferred_memory_model=""
opcache.protect_memory=0
opcache.restrict_api=""

; Performance settings
opcache.huge_code_pages=1
opcache.lockfile_path=/tmp
opcache.opt_debug_level=0
opcache.file_update_protection=2
opcache.min_restart_time=1
EOF

echo "✅ Конфигурация OPcache создана: $OPCACHE_CONF"

# Создаем файл исключений для OPcache
BLACKLIST_FILE="/etc/php/${PHP_VERSION}/opcache-blacklist.txt"
cat > "$BLACKLIST_FILE" << 'EOF'
; OPcache blacklist for Drupal
; Files that should not be cached

; Drupal development files
/var/www/*/web/sites/*/files/*
/var/www/*/web/sites/*/private/*
/var/www/*/vendor/bin/*
/var/www/*/drush/*

; Temporary files
/tmp/*
/var/tmp/*

; Configuration files that change frequently
/var/www/*/web/sites/*/settings*.php
/var/www/*/web/sites/*/services*.yml
EOF

echo "✅ Создан файл исключений: $BLACKLIST_FILE"

# Также настраиваем для CLI если нужно
CLI_CONF="/etc/php/${PHP_VERSION}/cli/conf.d/10-opcache.ini"
if [ -f "$CLI_CONF" ]; then
    sed -i 's/opcache.enable_cli=1/opcache.enable_cli=0/' "$CLI_CONF"
    echo "✅ OPcache отключен для CLI"
fi

echo "🔄 Перезапускаем PHP-FPM..."
if systemctl restart php${PHP_VERSION}-fpm; then
    echo "✅ PHP-FPM перезапущен успешно"
    
    # Проверяем статус
    if systemctl is-active --quiet php${PHP_VERSION}-fpm; then
        echo "✅ PHP-FPM работает"
    else
        echo "❌ PHP-FPM не запустился"
        systemctl status php${PHP_VERSION}-fpm --no-pager
    fi
else
    echo "❌ Ошибка перезапуска PHP-FPM"
    systemctl status php${PHP_VERSION}-fpm --no-pager
fi

echo
echo "🧪 Проверяем OPcache..."

# Проверяем загрузку OPcache
php -r "
if (extension_loaded('Zend OPcache')) {
    echo '✅ OPcache загружен успешно' . PHP_EOL;
    echo 'Настройки:' . PHP_EOL;
    echo '  - Включен: ' . (ini_get('opcache.enable') ? 'Да' : 'Нет') . PHP_EOL;
    echo '  - Память: ' . ini_get('opcache.memory_consumption') . 'MB' . PHP_EOL;
    echo '  - Макс. файлов: ' . ini_get('opcache.max_accelerated_files') . PHP_EOL;
    echo '  - Валидация: ' . (ini_get('opcache.validate_timestamps') ? 'Включена' : 'Отключена') . PHP_EOL;
    echo '  - Интервал проверки: ' . ini_get('opcache.revalidate_freq') . 'с' . PHP_EOL;
} else {
    echo '❌ OPcache не загружен' . PHP_EOL;
    exit(1);
}
"

if [ $? -eq 0 ]; then
    echo "✅ OPcache настроен успешно"
    
    # Создаем тестовый PHP файл для проверки OPcache
    TEST_FILE="/tmp/opcache_test.php"
    cat > "$TEST_FILE" << 'EOF'
<?php
if (function_exists('opcache_get_status')) {
    $status = opcache_get_status();
    if ($status !== false) {
        echo "OPcache работает!\n";
        echo "Использовано памяти: " . round($status['memory_usage']['used_memory'] / 1024 / 1024, 2) . "MB\n";
        echo "Свободно памяти: " . round($status['memory_usage']['free_memory'] / 1024 / 1024, 2) . "MB\n";
        echo "Кешированных файлов: " . $status['opcache_statistics']['num_cached_scripts'] . "\n";
        echo "Попаданий в кеш: " . $status['opcache_statistics']['hits'] . "\n";
        echo "Промахов кеша: " . $status['opcache_statistics']['misses'] . "\n";
    } else {
        echo "OPcache недоступен\n";
    }
} else {
    echo "Функции OPcache не найдены\n";
}
?>
EOF
    
    echo
    echo "📊 Статус OPcache:"
    php "$TEST_FILE"
    rm -f "$TEST_FILE"
    
else
    echo "❌ Проблемы с конфигурацией OPcache"
fi

echo
echo "✅ Настройка OPcache завершена"
echo
echo "🎯 Рекомендации:"
echo "1. Перезапустите Nginx: sudo systemctl restart nginx"
echo "2. Очистите кеш Drupal: drush cr (если доступен)"
echo "3. Мониторьте производительность через админку Drupal"
echo "4. Для очистки кеша OPcache: sudo systemctl restart php${PHP_VERSION}-fpm"
