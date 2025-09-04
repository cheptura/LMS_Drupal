#!/bin/bash

# RTTI Drupal Update Script
# Обновление Drupal до последней версии

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          Drupal Update Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./update-drupal.sh"
    exit 1
fi

echo "🔄 Начинаем обновление Drupal..."
echo "📅 Дата: $(date)"
echo

DRUPAL_DIR="/var/www/html/drupal"

# Проверка существования Drupal
if [ ! -d "$DRUPAL_DIR" ]; then
    echo "❌ Drupal не найден в $DRUPAL_DIR"
    exit 1
fi

# Создание бэкапа перед обновлением
echo "💾 Создание бэкапа перед обновлением..."
./backup-drupal.sh

# Перевод в режим обслуживания
echo "🔧 Включение режима обслуживания..."
cd $DRUPAL_DIR
sudo -u www-data vendor/bin/drush state:set system.maintenance_mode 1 --input-format=integer

# Очистка кэша
echo "🧹 Очистка кэша..."
sudo -u www-data vendor/bin/drush cache:rebuild

# Обновление composer пакетов
echo "📦 Обновление Composer пакетов..."
sudo -u www-data composer update --no-dev --optimize-autoloader

# Обновление базы данных
echo "🗄️  Обновление базы данных..."
sudo -u www-data vendor/bin/drush updatedb --yes

# Импорт конфигурации
echo "⚙️  Импорт конфигурации..."
sudo -u www-data vendor/bin/drush config:import --yes 2>/dev/null || echo "ℹ️  Конфигурация не требует импорта"

# Очистка кэша после обновления
echo "🧹 Финальная очистка кэша..."
sudo -u www-data vendor/bin/drush cache:rebuild

# Выход из режима обслуживания
echo "✅ Выключение режима обслуживания..."
sudo -u www-data vendor/bin/drush state:set system.maintenance_mode 0 --input-format=integer

# Проверка состояния
echo "🔍 Проверка состояния Drupal..."
sudo -u www-data vendor/bin/drush status

echo "🎉 Обновление Drupal завершено успешно!"
echo "📋 Проверьте сайт: https://library.rtti.tj"
