#!/bin/bash

# RTTI Moodle Backup Script
# Создание полного бэкапа Moodle

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          Moodle Backup Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./backup-moodle.sh"
    exit 1
fi

# Переменные
BACKUP_DIR="/var/backups/moodle"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="moodle_backup_$DATE"
MOODLE_DIR="/var/www/html/moodle"
DATA_DIR="/var/moodledata"

echo "💾 Создание бэкапа Moodle..."
echo "📅 Дата: $(date)"
echo "📂 Директория бэкапов: $BACKUP_DIR"
echo

# Создание директории бэкапов
mkdir -p $BACKUP_DIR

# Включение режима обслуживания
echo "🔧 Включение режима обслуживания..."
cd $MOODLE_DIR
sudo -u www-data php admin/cli/maintenance.php --enable

# Бэкап базы данных
echo "🗄️  Создание бэкапа базы данных..."
DB_NAME=$(grep 'dbname' $MOODLE_DIR/config.php | cut -d"'" -f2)
DB_USER=$(grep 'dbuser' $MOODLE_DIR/config.php | cut -d"'" -f2)
DB_PASS=$(grep 'dbpass' $MOODLE_DIR/config.php | cut -d"'" -f2)

PGPASSWORD="$DB_PASS" pg_dump -h localhost -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/${BACKUP_NAME}_database.sql"

# Бэкап файлов Moodle
echo "📂 Создание бэкапа файлов Moodle..."
tar -czf "$BACKUP_DIR/${BACKUP_NAME}_moodle_files.tar.gz" -C "$(dirname $MOODLE_DIR)" "$(basename $MOODLE_DIR)"

# Бэкап данных Moodle
echo "📁 Создание бэкапа данных Moodle..."
tar -czf "$BACKUP_DIR/${BACKUP_NAME}_moodle_data.tar.gz" -C "$(dirname $DATA_DIR)" "$(basename $DATA_DIR)"

# Выключение режима обслуживания
echo "✅ Выключение режима обслуживания..."
sudo -u www-data php admin/cli/maintenance.php --disable

# Создание информационного файла
echo "📋 Создание информационного файла..."
cat > "$BACKUP_DIR/${BACKUP_NAME}_info.txt" << EOF
Moodle Backup Information
========================
Date: $(date)
Server: $(hostname)
Moodle Directory: $MOODLE_DIR
Data Directory: $DATA_DIR
Database: $DB_NAME
Files:
- Database: ${BACKUP_NAME}_database.sql
- Moodle Files: ${BACKUP_NAME}_moodle_files.tar.gz
- Moodle Data: ${BACKUP_NAME}_moodle_data.tar.gz
EOF

# Установка прав доступа
chown -R root:root "$BACKUP_DIR"
chmod 600 "$BACKUP_DIR"/${BACKUP_NAME}*

# Размер бэкапов
echo "📊 Размеры бэкапов:"
ls -lh "$BACKUP_DIR"/${BACKUP_NAME}*

# Очистка старых бэкапов (старше 30 дней)
echo "🧹 Очистка старых бэкапов..."
find "$BACKUP_DIR" -name "moodle_backup_*" -mtime +30 -delete

echo "🎉 Бэкап Moodle создан успешно!"
echo "📂 Файлы бэкапа:"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_database.sql"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_moodle_files.tar.gz"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_moodle_data.tar.gz"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_info.txt"
