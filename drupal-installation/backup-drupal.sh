#!/bin/bash

# RTTI Drupal Backup Script
# Создание полного бэкапа Drupal

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          Drupal Backup Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./backup-drupal.sh"
    exit 1
fi

# Переменные
BACKUP_DIR="/var/backups/drupal"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="drupal_backup_$DATE"
DRUPAL_DIR="/var/www/html/drupal"
FILES_DIR="/var/drupaldata"

echo "💾 Создание бэкапа Drupal..."
echo "📅 Дата: $(date)"
echo "📂 Директория бэкапов: $BACKUP_DIR"
echo

# Создание директории бэкапов
mkdir -p $BACKUP_DIR

# Включение режима обслуживания
echo "🔧 Включение режима обслуживания..."
cd $DRUPAL_DIR
sudo -u www-data vendor/bin/drush state:set system.maintenance_mode 1 --input-format=integer

# Получение данных подключения к БД
echo "📋 Получение информации о базе данных..."
if [ -f "$DRUPAL_DIR/sites/default/settings.php" ]; then
    DB_NAME=$(grep "database.*=>" $DRUPAL_DIR/sites/default/settings.php | head -1 | cut -d"'" -f2)
    DB_USER=$(grep "username.*=>" $DRUPAL_DIR/sites/default/settings.php | head -1 | cut -d"'" -f2)
    DB_PASS=$(grep "password.*=>" $DRUPAL_DIR/sites/default/settings.php | head -1 | cut -d"'" -f2)
    DB_HOST=$(grep "host.*=>" $DRUPAL_DIR/sites/default/settings.php | head -1 | cut -d"'" -f2)
else
    echo "❌ Файл настроек Drupal не найден"
    exit 1
fi

# Бэкап через Drush
echo "🗄️  Создание бэкапа базы данных через Drush..."
sudo -u www-data vendor/bin/drush sql:dump --result-file="$BACKUP_DIR/${BACKUP_NAME}_database.sql"

# Альтернативный бэкап БД через pg_dump
echo "🗄️  Создание альтернативного бэкапа БД..."
if [ ! -z "$DB_PASS" ]; then
    PGPASSWORD="$DB_PASS" pg_dump -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/${BACKUP_NAME}_database_alt.sql"
fi

# Экспорт конфигурации
echo "⚙️  Экспорт конфигурации..."
sudo -u www-data vendor/bin/drush config:export --destination="$BACKUP_DIR/${BACKUP_NAME}_config"

# Бэкап файлов Drupal
echo "📂 Создание бэкапа файлов Drupal..."
tar -czf "$BACKUP_DIR/${BACKUP_NAME}_drupal_files.tar.gz" -C "$(dirname $DRUPAL_DIR)" "$(basename $DRUPAL_DIR)"

# Бэкап загруженных файлов
echo "📁 Создание бэкапа загруженных файлов..."
if [ -d "$FILES_DIR" ]; then
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_drupal_data.tar.gz" -C "$(dirname $FILES_DIR)" "$(basename $FILES_DIR)"
fi

# Бэкап публичных файлов
echo "📸 Создание бэкапа публичных файлов..."
if [ -d "$DRUPAL_DIR/sites/default/files" ]; then
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_public_files.tar.gz" -C "$DRUPAL_DIR/sites/default" files
fi

# Выключение режима обслуживания
echo "✅ Выключение режима обслуживания..."
sudo -u www-data vendor/bin/drush state:set system.maintenance_mode 0 --input-format=integer

# Создание информационного файла
echo "📋 Создание информационного файла..."
cat > "$BACKUP_DIR/${BACKUP_NAME}_info.txt" << EOF
Drupal Backup Information
========================
Date: $(date)
Server: $(hostname)
Drupal Directory: $DRUPAL_DIR
Files Directory: $FILES_DIR
Database: $DB_NAME
Database Host: $DB_HOST
Database User: $DB_USER
Files:
- Database (Drush): ${BACKUP_NAME}_database.sql
- Database (pg_dump): ${BACKUP_NAME}_database_alt.sql
- Configuration: ${BACKUP_NAME}_config/
- Drupal Files: ${BACKUP_NAME}_drupal_files.tar.gz
- Data Files: ${BACKUP_NAME}_drupal_data.tar.gz
- Public Files: ${BACKUP_NAME}_public_files.tar.gz
EOF

# Установка прав доступа
chown -R root:root "$BACKUP_DIR"
chmod 600 "$BACKUP_DIR"/${BACKUP_NAME}*

# Размер бэкапов
echo "📊 Размеры бэкапов:"
ls -lh "$BACKUP_DIR"/${BACKUP_NAME}*

# Очистка старых бэкапов (старше 30 дней)
echo "🧹 Очистка старых бэкапов..."
find "$BACKUP_DIR" -name "drupal_backup_*" -mtime +30 -delete

echo "🎉 Бэкап Drupal создан успешно!"
echo "📂 Файлы бэкапа:"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_database.sql"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_drupal_files.tar.gz"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_drupal_data.tar.gz"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_public_files.tar.gz"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_config/"
echo "   - $BACKUP_DIR/${BACKUP_NAME}_info.txt"
