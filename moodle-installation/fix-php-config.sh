#!/bin/bash

# RTTI Moodle - Исправление конфигурации PHP для Moodle
# Исправляет max_input_vars и другие критические настройки

echo "=== RTTI Moodle - Исправление конфигурации PHP ==="
echo "🔧 Настройка PHP для соответствия требованиям Moodle"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

# Определяем версию PHP
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo "🔍 Обнаружена версия PHP: $PHP_VERSION"

PHP_FPM_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
PHP_CLI_INI="/etc/php/$PHP_VERSION/cli/php.ini"

# Проверяем существование файлов конфигурации
if [ ! -f "$PHP_FPM_INI" ]; then
    echo "❌ Файл конфигурации PHP-FPM не найден: $PHP_FPM_INI"
    exit 1
fi

if [ ! -f "$PHP_CLI_INI" ]; then
    echo "❌ Файл конфигурации PHP CLI не найден: $PHP_CLI_INI"
    exit 1
fi

echo "📄 Найдены конфигурационные файлы:"
echo "   - FPM: $PHP_FPM_INI"
echo "   - CLI: $PHP_CLI_INI"
echo

# Создаем резервные копии
echo "💾 Создание резервных копий..."
cp "$PHP_FPM_INI" "${PHP_FPM_INI}.backup-$(date +%Y%m%d-%H%M%S)"
cp "$PHP_CLI_INI" "${PHP_CLI_INI}.backup-$(date +%Y%m%d-%H%M%S)"

# Функция для настройки PHP INI файла
configure_php_ini() {
    local ini_file=$1
    local file_type=$2
    echo "🔧 Настройка $file_type: $ini_file"
    
    # Функция для установки или обновления параметра
    set_php_setting() {
        local setting=$1
        local value=$2
        local file=$3
        
        # Удаляем существующие настройки (закомментированные и активные)
        sed -i "/^;*\s*$setting\s*=/d" "$file"
        # Добавляем новую настройку
        echo "$setting = $value" >> "$file"
    }
    
    # Критические настройки для Moodle
    set_php_setting "max_execution_time" "300" "$ini_file"
    set_php_setting "max_input_time" "300" "$ini_file"
    set_php_setting "memory_limit" "512M" "$ini_file"
    set_php_setting "post_max_size" "100M" "$ini_file"
    set_php_setting "upload_max_filesize" "100M" "$ini_file"
    set_php_setting "max_input_vars" "5000" "$ini_file"
    
    # Настройки OPcache
    set_php_setting "opcache.enable" "1" "$ini_file"
    set_php_setting "opcache.memory_consumption" "256" "$ini_file"
    set_php_setting "opcache.max_accelerated_files" "10000" "$ini_file"
    set_php_setting "opcache.revalidate_freq" "2" "$ini_file"
    
    echo "   ✅ $file_type настроен"
}

# Настраиваем оба INI файла
configure_php_ini "$PHP_FPM_INI" "PHP-FPM"
configure_php_ini "$PHP_CLI_INI" "PHP CLI"

echo
echo "🔄 Перезапуск PHP-FPM..."
systemctl restart php$PHP_VERSION-fpm

if systemctl is-active --quiet php$PHP_VERSION-fpm; then
    echo "✅ PHP-FPM успешно перезапущен"
else
    echo "❌ Ошибка перезапуска PHP-FPM"
    exit 1
fi

echo
echo "🧪 Проверка настроек PHP..."

# Проверяем критические настройки
echo "📊 Текущие настройки PHP:"
php -r "
echo 'max_execution_time = ' . ini_get('max_execution_time') . ' (требуется >= 300)' . PHP_EOL;
echo 'memory_limit = ' . ini_get('memory_limit') . ' (требуется >= 512M)' . PHP_EOL;
echo 'max_input_vars = ' . ini_get('max_input_vars') . ' (требуется >= 5000)' . PHP_EOL;
echo 'post_max_size = ' . ini_get('post_max_size') . ' (требуется >= 100M)' . PHP_EOL;
echo 'upload_max_filesize = ' . ini_get('upload_max_filesize') . ' (требуется >= 100M)' . PHP_EOL;
"

# Проверяем конкретно max_input_vars
MAX_INPUT_VARS=$(php -r "echo ini_get('max_input_vars');")
if [ "$MAX_INPUT_VARS" -ge 5000 ]; then
    echo "✅ max_input_vars = $MAX_INPUT_VARS (соответствует требованиям Moodle)"
else
    echo "❌ max_input_vars = $MAX_INPUT_VARS (недостаточно для Moodle, требуется >= 5000)"
    echo "🔧 Попытка дополнительной настройки..."
    
    # Добавляем настройку в дополнительный конфигурационный файл
    echo "max_input_vars = 5000" > "/etc/php/$PHP_VERSION/conf.d/99-moodle-settings.ini"
    systemctl restart php$PHP_VERSION-fpm
    
    # Проверяем снова
    MAX_INPUT_VARS_NEW=$(php -r "echo ini_get('max_input_vars');")
    if [ "$MAX_INPUT_VARS_NEW" -ge 5000 ]; then
        echo "✅ max_input_vars исправлен: $MAX_INPUT_VARS_NEW"
    else
        echo "❌ Не удалось исправить max_input_vars"
        exit 1
    fi
fi

echo
echo "✅ Конфигурация PHP успешно обновлена для Moodle!"
echo "📋 Резервные копии сохранены с временной меткой"
echo "🔄 Теперь можно продолжить установку Moodle"
