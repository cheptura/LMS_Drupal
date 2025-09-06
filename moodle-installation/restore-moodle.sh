#!/bin/bash

# RTTI Moodle Restore Script
# Восстановление Moodle из бэкапа

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Moodle Restore Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./restore-moodle.sh"
    exit 1
fi

# Переменные
BACKUP_DIR="/var/backups/moodle"
MOODLE_DIR="/var/www/html/moodle"
DATA_DIR="/var/moodledata"

echo "🔄 Восстановление Moodle из бэкапа..."
echo "📅 Дата: $(date)"
echo

# Показать доступные бэкапы
echo "📂 Доступные бэкапы:"
ls -la "$BACKUP_DIR"/moodle_backup_*_info.txt 2>/dev/null | awk '{print $9}' | sed 's/_info.txt//' | sed 's/.*\///'

# Запрос имени бэкапа
read -p "📝 Введите имя бэкапа для восстановления (например: moodle_backup_20240904_143000): " BACKUP_NAME

if [ ! -f "$BACKUP_DIR/${BACKUP_NAME}_info.txt" ]; then
    echo "❌ Бэкап не найден: $BACKUP_NAME"
    exit 1
fi

# Показать информацию о бэкапе
echo "📋 Информация о бэкапе:"
cat "$BACKUP_DIR/${BACKUP_NAME}_info.txt"
echo

# Подтверждение
read -p "⚠️  ВНИМАНИЕ! Это действие перезапишет текущую установку Moodle. Продолжить? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Восстановление отменено"
    exit 0
fi

# Включение режима обслуживания
echo "🔧 Включение режима обслуживания..."
cd $MOODLE_DIR
sudo -u www-data php admin/cli/maintenance.php --enable

# Остановка веб-сервера
echo "🛑 Остановка веб-сервера..."
systemctl stop nginx

# Получение данных подключения к БД
DB_NAME=$(grep 'dbname' $MOODLE_DIR/config.php | cut -d"'" -f2)
DB_USER=$(grep 'dbuser' $MOODLE_DIR/config.php | cut -d"'" -f2)
DB_PASS=$(grep 'dbpass' $MOODLE_DIR/config.php | cut -d"'" -f2)

# Восстановление базы данных
echo "🗄️  Восстановление базы данных..."
PGPASSWORD="$DB_PASS" dropdb -h localhost -U "$DB_USER" "$DB_NAME"
PGPASSWORD="$DB_PASS" createdb -h localhost -U "$DB_USER" "$DB_NAME"
PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" "$DB_NAME" < "$BACKUP_DIR/${BACKUP_NAME}_database.sql"

# Восстановление файлов Moodle
echo "📂 Восстановление файлов Moodle..."
rm -rf "$MOODLE_DIR.backup"
mv "$MOODLE_DIR" "$MOODLE_DIR.backup"
tar -xzf "$BACKUP_DIR/${BACKUP_NAME}_moodle_files.tar.gz" -C "$(dirname $MOODLE_DIR)"

# Восстановление данных Moodle
echo "📁 Восстановление данных Moodle..."
rm -rf "$DATA_DIR.backup"
mv "$DATA_DIR" "$DATA_DIR.backup"
tar -xzf "$BACKUP_DIR/${BACKUP_NAME}_moodle_data.tar.gz" -C "$(dirname $DATA_DIR)"

# Установка правильных прав доступа
echo "🔐 Установка прав доступа..."
chown -R www-data:www-data $MOODLE_DIR
chown -R www-data:www-data $DATA_DIR
chmod -R 755 $MOODLE_DIR
chmod -R 755 $DATA_DIR

# Запуск веб-сервера
echo "▶️  Запуск веб-сервера..."
systemctl start nginx

# Выключение режима обслуживания
echo "✅ Выключение режима обслуживания..."
cd $MOODLE_DIR
sudo -u www-data php admin/cli/maintenance.php --disable

# Очистка кэша
echo "🧹 Очистка кэша..."
sudo -u www-data php admin/cli/purge_caches.php

echo "🎉 Восстановление Moodle завершено успешно!"
echo "📋 Проверьте сайт: https://omuzgorpro.tj"
echo "📂 Старые файлы сохранены в:"
echo "   - $MOODLE_DIR.backup"
echo "   - $DATA_DIR.backup"
