#!/bin/bash

# RTTI Drupal - Шаг 7: Базовая конфигурация
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 7: Базовая конфигурация Drupal ==="
echo "📖 Настройка основных параметров"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"

# Проверка установки Drupal
if [ ! -d "$DRUPAL_DIR" ] || [ ! -f "$DRUPAL_DIR/web/sites/default/settings.php" ]; then
    echo "❌ Drupal не установлен"
    exit 1
fi

echo "1. Переход в каталог Drupal..."
cd $DRUPAL_DIR

echo "2. Проверка Drush..."
DRUSH_CMD="$DRUPAL_DIR/vendor/bin/drush"
if [ ! -f "$DRUSH_CMD" ]; then
    echo "❌ Drush не найден"
    exit 1
fi

echo "3. Проверка статуса Drupal..."
if ! sudo -u www-data $DRUSH_CMD status >/dev/null 2>&1; then
    echo "❌ Drupal не отвечает"
    exit 1
fi
echo "✅ Drupal загружается корректно"

echo "4. Включение базовых модулей..."
sudo -u www-data $DRUSH_CMD pm:enable node field field_ui views views_ui media file taxonomy search admin_toolbar -y

echo "5. Настройка русского языка..."
sudo -u www-data $DRUSH_CMD locale:check
sudo -u www-data $DRUSH_CMD config:set language.negotiation selected_langcode ru -y
sudo -u www-data $DRUSH_CMD config:set system.site default_langcode ru -y

echo "6. Настройка часового пояса..."
sudo -u www-data $DRUSH_CMD config:set system.date timezone.default Asia/Dushanbe -y

echo "7. Загрузка переводов..."
sudo -u www-data $DRUSH_CMD locale:update

echo "8. Настройка сайта..."
sudo -u www-data $DRUSH_CMD config:set system.site name "RTTI Digital Library" -y
sudo -u www-data $DRUSH_CMD config:set system.site slogan "Цифровая библиотека РТТИ" -y
sudo -u www-data $DRUSH_CMD config:set system.site mail "admin@omuzgorpro.tj" -y

echo "9. Настройка производительности..."
sudo -u www-data $DRUSH_CMD config:set system.performance css.preprocess true -y
sudo -u www-data $DRUSH_CMD config:set system.performance js.preprocess true -y
sudo -u www-data $DRUSH_CMD config:set system.performance cache.page.max_age 3600 -y

echo "10. Настройка путей к файлам..."
# Раскомментирование и настройка file_public_path в settings.php
SETTINGS_FILE="$DRUPAL_DIR/web/sites/default/settings.php"
if grep -q "^# \$settings\['file_public_path'\]" "$SETTINGS_FILE"; then
    sed -i "s/^# \$settings\['file_public_path'\]/\$settings['file_public_path']/" "$SETTINGS_FILE"
    echo "   ✅ Раскомментирован file_public_path"
elif ! grep -q "\$settings\['file_public_path'\]" "$SETTINGS_FILE"; then
    echo "\$settings['file_public_path'] = 'sites/default/files';" >> "$SETTINGS_FILE"
    echo "   ✅ Добавлен file_public_path"
else
    echo "   ✅ file_public_path уже настроен"
fi

echo "11. Индексация поиска..."
sudo -u www-data $DRUSH_CMD search-api:reset-tracker 2>/dev/null || echo "   ⚠️  Search API не установлен"
sudo -u www-data $DRUSH_CMD search-api:index 2>/dev/null || echo "   ✅ Стандартный поиск"

echo "12. Очистка кэша..."
sudo -u www-data $DRUSH_CMD cache:rebuild
echo "   ✅ Кэш очищен"

echo
echo "✅ Шаг 7 завершен успешно!"
echo "📌 Базовая конфигурация применена"
echo "📌 Русский язык настроен"
echo "📌 Основные модули активированы"
echo "📌 Следующий шаг: ./08-post-install.sh"
echo
