#!/bin/bash

# RTTI Moodle Update Script
# Обновление Moodle до последней версии

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          Moodle Update Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./update-moodle.sh"
    exit 1
fi

echo "🔄 Начинаем обновление Moodle..."
echo "📅 Дата: $(date)"
echo

# Создание бэкапа перед обновлением
echo "💾 Создание бэкапа перед обновлением..."
./backup-moodle.sh

# Перевод в режим обслуживания
echo "🔧 Включение режима обслуживания..."
cd /var/www/html/moodle
sudo -u www-data php admin/cli/maintenance.php --enable

# Обновление кода
echo "📥 Загрузка обновлений Moodle..."
cd /tmp
wget -O moodle-latest.tgz https://download.moodle.org/download.php/direct/stable40/moodle-latest-40.tgz
tar -xzf moodle-latest.tgz

# Копирование новых файлов
echo "📂 Обновление файлов..."
rsync -av --exclude=config.php moodle/ /var/www/html/moodle/
chown -R www-data:www-data /var/www/html/moodle

# Обновление базы данных
echo "🗄️  Обновление базы данных..."
cd /var/www/html/moodle
sudo -u www-data php admin/cli/upgrade.php --non-interactive

# Очистка кэша
echo "🧹 Очистка кэша..."
sudo -u www-data php admin/cli/purge_caches.php

# Выход из режима обслуживания
echo "✅ Выключение режима обслуживания..."
sudo -u www-data php admin/cli/maintenance.php --disable

echo "🎉 Обновление Moodle завершено успешно!"
echo "📋 Проверьте сайт: https://omuzgorpro.tj"
