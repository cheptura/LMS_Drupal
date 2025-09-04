#!/bin/bash
# Тестовый скрипт для проверки загрузки Moodle 5.0+

set -e

MOODLE_VERSION="5.0"

echo "🔍 Тестируем загрузку Moodle $MOODLE_VERSION..."

cd /tmp

# Тест основной ссылки для Moodle 5.0
echo "📥 Попытка 1: Официальный сайт Moodle 5.0..."
if wget -q --spider "https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz"; then
    echo "✅ Основная ссылка Moodle 5.0 доступна"
    wget "https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz" -O "moodle-${MOODLE_VERSION}.tgz"
    echo "✅ Moodle $MOODLE_VERSION скачан успешно"
    ls -lh moodle-${MOODLE_VERSION}.tgz
else
    echo "❌ Основная ссылка недоступна, пробуем GitHub..."
    
    # Тест GitHub ссылки для Moodle 5.0
    if wget -q --spider "https://github.com/moodle/moodle/archive/refs/heads/MOODLE_500_STABLE.tar.gz"; then
        echo "✅ GitHub ссылка для Moodle 5.0 доступна"
        wget "https://github.com/moodle/moodle/archive/refs/heads/MOODLE_500_STABLE.tar.gz" -O "moodle-${MOODLE_VERSION}.tgz"
        echo "✅ Moodle $MOODLE_VERSION скачан с GitHub"
        ls -lh moodle-${MOODLE_VERSION}.tgz
    else
        echo "❌ GitHub ссылка тоже недоступна"
        echo "❌ Не удалось найти доступную версию Moodle 5.0"
        exit 1
    fi
fi

echo ""
echo "🎉 Тест завершен. Проверьте результат выше."
echo "📁 Скачанные файлы:"
ls -lh moodle-*.tgz 2>/dev/null || echo "Нет скачанных файлов"

# Очистка
rm -f moodle-*.tgz
echo "🧹 Временные файлы удалены"
