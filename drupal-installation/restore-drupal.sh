#!/bin/bash

# RTTI Drupal Restore Script
# Восстановление Drupal из бэкапа

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Drupal Restore Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./restore-drupal.sh"
    exit 1
fi

# Переменные
BACKUP_DIR="/var/backups/drupal"
DRUPAL_DIR="/var/www/html/drupal"
FILES_DIR="/var/drupaldata"

echo "🔄 Восстановление Drupal из бэкапа..."
echo "📅 Дата: $(date)"
echo

# Показать доступные бэкапы
echo "📂 Доступные бэкапы:"
ls -la "$BACKUP_DIR"/drupal_backup_*_info.txt 2>/dev/null | awk '{print $9}' | sed 's/_info.txt//' | sed 's/.*\///'

# Запрос имени бэкапа
read -p "📝 Введите имя бэкапа для восстановления (например: drupal_backup_20240904_143000): " BACKUP_NAME

if [ ! -f "$BACKUP_DIR/${BACKUP_NAME}_info.txt" ]; then
    echo "❌ Бэкап не найден: $BACKUP_NAME"
    exit 1
fi

# Показать информацию о бэкапе
echo "📋 Информация о бэкапе:"
cat "$BACKUP_DIR/${BACKUP_NAME}_info.txt"
echo

# Подтверждение
read -p "⚠️  ВНИМАНИЕ! Это действие перезапишет текущую установку Drupal. Продолжить? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Восстановление отменено"
    exit 0
fi

# Включение режима обслуживания
echo "🔧 Включение режима обслуживания..."
if [ -d "$DRUPAL_DIR" ]; then
    cd $DRUPAL_DIR
    sudo -u www-data vendor/bin/drush state:set system.maintenance_mode 1 --input-format=integer 2>/dev/null || true
fi

# Остановка веб-сервера
echo "🛑 Остановка веб-сервера..."
systemctl stop nginx

# Получение данных подключения к БД из бэкапа
if [ -f "$BACKUP_DIR/${BACKUP_NAME}_info.txt" ]; then
    DB_NAME=$(grep "Database:" "$BACKUP_DIR/${BACKUP_NAME}_info.txt" | awk '{print $2}')
    DB_HOST=$(grep "Database Host:" "$BACKUP_DIR/${BACKUP_NAME}_info.txt" | awk '{print $3}')
    DB_USER=$(grep "Database User:" "$BACKUP_DIR/${BACKUP_NAME}_info.txt" | awk '{print $3}')
fi

# Запрос пароля БД
read -s -p "🔑 Введите пароль базы данных для пользователя $DB_USER: " DB_PASS
echo

# Восстановление базы данных
echo "🗄️  Восстановление базы данных..."
if [ -f "$BACKUP_DIR/${BACKUP_NAME}_database.sql" ]; then
    PGPASSWORD="$DB_PASS" dropdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" 2>/dev/null || true
    PGPASSWORD="$DB_PASS" createdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" < "$BACKUP_DIR/${BACKUP_NAME}_database.sql"
fi

# Восстановление файлов Drupal
echo "📂 Восстановление файлов Drupal..."
if [ -f "$BACKUP_DIR/${BACKUP_NAME}_drupal_files.tar.gz" ]; then
    rm -rf "$DRUPAL_DIR.backup"
    if [ -d "$DRUPAL_DIR" ]; then
        mv "$DRUPAL_DIR" "$DRUPAL_DIR.backup"
    fi
    tar -xzf "$BACKUP_DIR/${BACKUP_NAME}_drupal_files.tar.gz" -C "$(dirname $DRUPAL_DIR)"
fi

# Восстановление данных Drupal
echo "📁 Восстановление данных Drupal..."
if [ -f "$BACKUP_DIR/${BACKUP_NAME}_drupal_data.tar.gz" ]; then
    rm -rf "$FILES_DIR.backup"
    if [ -d "$FILES_DIR" ]; then
        mv "$FILES_DIR" "$FILES_DIR.backup"
    fi
    tar -xzf "$BACKUP_DIR/${BACKUP_NAME}_drupal_data.tar.gz" -C "$(dirname $FILES_DIR)"
fi

# Восстановление публичных файлов
echo "📸 Восстановление публичных файлов..."
if [ -f "$BACKUP_DIR/${BACKUP_NAME}_public_files.tar.gz" ]; then
    rm -rf "$DRUPAL_DIR/sites/default/files.backup"
    if [ -d "$DRUPAL_DIR/sites/default/files" ]; then
        mv "$DRUPAL_DIR/sites/default/files" "$DRUPAL_DIR/sites/default/files.backup"
    fi
    tar -xzf "$BACKUP_DIR/${BACKUP_NAME}_public_files.tar.gz" -C "$DRUPAL_DIR/sites/default"
fi

# Восстановление конфигурации
echo "⚙️  Восстановление конфигурации..."
if [ -d "$BACKUP_DIR/${BACKUP_NAME}_config" ]; then
    cd $DRUPAL_DIR
    sudo -u www-data vendor/bin/drush config:import --source="$BACKUP_DIR/${BACKUP_NAME}_config" --yes 2>/dev/null || echo "ℹ️  Конфигурация не требует импорта"
fi

# Установка правильных прав доступа
echo "🔐 Установка прав доступа..."
chown -R www-data:www-data $DRUPAL_DIR
chown -R www-data:www-data $FILES_DIR
chmod -R 755 $DRUPAL_DIR
chmod -R 755 $FILES_DIR
chmod 444 $DRUPAL_DIR/sites/default/settings.php

# Обновление базы данных
echo "🔄 Обновление базы данных..."
cd $DRUPAL_DIR
sudo -u www-data vendor/bin/drush updatedb --yes

# Очистка кэша
echo "🧹 Очистка кэша..."
sudo -u www-data vendor/bin/drush cache:rebuild

# Запуск веб-сервера
echo "▶️  Запуск веб-сервера..."
systemctl start nginx

# Выключение режима обслуживания
echo "✅ Выключение режима обслуживания..."
sudo -u www-data vendor/bin/drush state:set system.maintenance_mode 0 --input-format=integer

echo "🎉 Восстановление Drupal завершено успешно!"
echo "📋 Проверьте сайт: https://storage.omuzgorpro.tj"
echo "📂 Старые файлы сохранены в:"
echo "   - $DRUPAL_DIR.backup"
echo "   - $FILES_DIR.backup"
echo "   - $DRUPAL_DIR/sites/default/files.backup"
