#!/bin/bash

# Простое исправление - создание директорий и принудительная генерация CSS/JS

echo "🔧 Создание директорий и принудительная генерация CSS/JS файлов..."

DRUPAL_DIR="/var/www/drupal"
FILES_DIR="$DRUPAL_DIR/web/sites/default/files"

# Создаем недостающие директории
echo "📁 Создание директорий css и js..."
mkdir -p "$FILES_DIR/css"
mkdir -p "$FILES_DIR/js"

# Устанавливаем права
chown -R www-data:www-data "$FILES_DIR"
chmod -R 775 "$FILES_DIR"

echo "🔍 Проверяем Drush..."
cd "$DRUPAL_DIR"

if [ -f "$DRUPAL_DIR/vendor/bin/drush" ]; then
    DRUSH_CMD="$DRUPAL_DIR/vendor/bin/drush"
else
    echo "❌ Drush не найден!"
    exit 1
fi

echo "⚙️ Включаем агрегацию CSS/JS..."
sudo -u www-data "$DRUSH_CMD" config:set system.performance css.preprocess 1 -y
sudo -u www-data "$DRUSH_CMD" config:set system.performance js.preprocess 1 -y

echo "🧹 Очищаем кэш..."
sudo -u www-data "$DRUSH_CMD" cache:rebuild

echo "🌐 Принудительно генерируем файлы через curl..."
curl -s "https://storage.omuzgorpro.tj/" > /dev/null 2>&1

# Проверяем что получилось
echo "🔍 Проверяем созданные файлы..."
ls -la "$FILES_DIR/"
echo ""
echo "CSS файлы:"
ls -la "$FILES_DIR/css/" 2>/dev/null || echo "CSS директория пуста"
echo ""
echo "JS файлы:" 
ls -la "$FILES_DIR/js/" 2>/dev/null || echo "JS директория пуста"

echo ""
echo "✅ Готово! Обновите страницу в браузере."
