#!/bin/bash
# Скрипт исправления проблемы загрузки Moodle
# Используется когда основной скрипт скачивает HTML вместо архива

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log "🔧 Исправление проблемы загрузки Moodle 5.0+"

# Переходим в временную директорию
cd /tmp

# Удаляем поврежденные файлы
log "Удаление поврежденных файлов..."
rm -f moodle-*.tgz
rm -rf moodle*

# Массив URL для попытки скачивания
MOODLE_URLS=(
    "https://download.moodle.org/download.php/direct/stable500/moodle-latest-500.tgz"
    "https://download.moodle.org/stable500/moodle-latest-500.tgz"
    "https://github.com/moodle/moodle/archive/refs/heads/MOODLE_500_STABLE.tar.gz"
    "https://download.moodle.org/download.php/direct/stable500/moodle-5.0.tgz"
)

DOWNLOAD_SUCCESS=false

for url in "${MOODLE_URLS[@]}"; do
    log "Пробуем URL: $url"
    
    if wget "$url" -O "moodle-5.0.tgz" 2>/dev/null; then
        # Проверяем что файл действительно архив
        if file "moodle-5.0.tgz" | grep -q "gzip compressed"; then
            # Проверяем что tar может прочитать файл
            if tar -tzf "moodle-5.0.tgz" >/dev/null 2>&1; then
                log "✅ Успешно скачан валидный архив Moodle"
                DOWNLOAD_SUCCESS=true
                break
            else
                warning "Файл не является валидным tar.gz архивом"
                rm -f "moodle-5.0.tgz"
            fi
        else
            warning "Файл не является gzip архивом (возможно HTML страница)"
            rm -f "moodle-5.0.tgz"
        fi
    else
        warning "Не удалось скачать с URL: $url"
    fi
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    error "Не удалось скачать Moodle ни с одного из доступных URL"
fi

# Распаковываем архив
log "Распаковка архива Moodle..."
tar -xzf "moodle-5.0.tgz"

# Определяем директорию с Moodle
MOODLE_DIR=""
if [ -d "moodle" ]; then
    MOODLE_DIR="moodle"
elif [ -d "moodle-latest-500" ]; then
    MOODLE_DIR="moodle-latest-500"
elif [ -d "moodle-MOODLE_500_STABLE" ]; then
    MOODLE_DIR="moodle-MOODLE_500_STABLE"
else
    # Ищем любую директорию с moodle
    MOODLE_DIR=$(find . -maxdepth 1 -type d -name "*moodle*" | head -1)
fi

if [ -z "$MOODLE_DIR" ]; then
    error "Не удалось найти директорию Moodle в архиве"
fi

log "Найдена директория Moodle: $MOODLE_DIR"

# Создаем целевые директории если не существуют
mkdir -p /var/www/html/moodle
mkdir -p /var/moodledata

# Копируем файлы Moodle
log "Копирование файлов Moodle..."
cp -R "$MOODLE_DIR"/* /var/www/html/moodle/

# Устанавливаем правильные права доступа
log "Настройка прав доступа..."
chown -R www-data:www-data /var/www/html/moodle
chown -R www-data:www-data /var/moodledata
chmod -R 755 /var/www/html/moodle
chmod -R 777 /var/moodledata

# Очистка временных файлов
log "Очистка временных файлов..."
rm -f "moodle-5.0.tgz"
rm -rf "$MOODLE_DIR"

log "✅ Moodle 5.0+ успешно установлен в /var/www/html/moodle"
log "Теперь можно продолжить основной скрипт установки"

# Проверяем основные файлы Moodle
if [ -f "/var/www/html/moodle/config-dist.php" ]; then
    log "✅ Найден config-dist.php - установка Moodle корректна"
else
    error "Не найден config-dist.php - возможно, установка некорректна"
fi

log "🎉 Исправление завершено успешно!"
