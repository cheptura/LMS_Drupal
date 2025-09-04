#!/bin/bash
# Быстрый тест загрузки Moodle 5.0+

echo "🔍 Тестируем новую ссылку для Moodle 5.0..."

# Тест правильной ссылки
wget -q --spider "https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz"
if [ $? -eq 0 ]; then
    echo "✅ УСПЕХ! Ссылка работает: https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz"
    echo "📦 Начинаем загрузку..."
    wget "https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz" -O test-moodle-5.tgz
    echo "📊 Размер файла:"
    ls -lh test-moodle-5.tgz
    rm -f test-moodle-5.tgz
    echo "🎉 Готово! Можно устанавливать Moodle 5.0+"
else
    echo "❌ Ошибка: ссылка не работает"
    exit 1
fi
