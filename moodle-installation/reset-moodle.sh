#!/bin/bash

# RTTI Moodle Reset Script
# Сброс Moodle к начальным настройкам

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          Moodle Reset Script                                ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./reset-moodle.sh"
    exit 1
fi

# Переменные
MOODLE_DIR="/var/www/html/moodle"
DATA_DIR="/var/moodledata"
BACKUP_DIR="/var/backups/moodle"

echo "⚠️  ВНИМАНИЕ: Сброс Moodle к начальным настройкам"
echo "📅 Дата: $(date)"
echo "📂 Moodle директория: $MOODLE_DIR"
echo "📁 Данные директория: $DATA_DIR"
echo

# Показать что будет сделано
echo "🔄 БУДЕТ ВЫПОЛНЕНО:"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "1. 💾 Создание полного бэкапа текущей системы"
echo "2. 🧹 Очистка кэша и временных файлов"
echo "3. 🗄️  Сброс базы данных к начальному состоянию"
echo "4. ⚙️  Восстановление конфигурации по умолчанию"
echo "5. 👤 Создание нового администратора"
echo "6. 🔧 Исправление прав доступа"
echo "7. 🔄 Перезапуск всех сервисов"
echo

# Подтверждение
read -p "❓ Вы действительно хотите сбросить Moodle? Это действие НЕЛЬЗЯ отменить! (yes/no): " -r
echo
if [[ ! $REPLY =~ ^(yes|YES)$ ]]; then
    echo "❌ Сброс отменен"
    exit 0
fi

read -p "❓ Введите 'RESET' для подтверждения: " -r
echo
if [[ $REPLY != "RESET" ]]; then
    echo "❌ Неверное подтверждение. Сброс отменен"
    exit 0
fi

# Создание бэкапа перед сбросом
echo "💾 Создание экстренного бэкапа..."
./backup-moodle.sh
BACKUP_STATUS=$?
if [ $BACKUP_STATUS -ne 0 ]; then
    echo "❌ Ошибка создания бэкапа. Сброс отменен для безопасности"
    exit 1
fi
echo "✅ Бэкап создан успешно"

# Включение режима обслуживания
echo "🔧 Включение режима обслуживания..."
cd $MOODLE_DIR
sudo -u www-data php admin/cli/maintenance.php --enable
echo "✅ Режим обслуживания включен"

# Остановка веб-сервера
echo "🛑 Остановка веб-сервера..."
systemctl stop nginx

# Получение данных БД из конфигурации
echo "🔍 Получение параметров базы данных..."
if [ -f "$MOODLE_DIR/config.php" ]; then
    DB_NAME=$(grep 'dbname' $MOODLE_DIR/config.php | cut -d"'" -f2)
    DB_USER=$(grep 'dbuser' $MOODLE_DIR/config.php | cut -d"'" -f2)
    DB_PASS=$(grep 'dbpass' $MOODLE_DIR/config.php | cut -d"'" -f2)
    DB_HOST=$(grep 'dbhost' $MOODLE_DIR/config.php | cut -d"'" -f2)
    WWW_ROOT=$(grep 'wwwroot' $MOODLE_DIR/config.php | cut -d"'" -f2)
    DATA_ROOT=$(grep 'dataroot' $MOODLE_DIR/config.php | cut -d"'" -f2)
    
    echo "✅ Параметры БД получены"
    echo "   База данных: $DB_NAME"
    echo "   Пользователь: $DB_USER"
    echo "   Хост: $DB_HOST"
else
    echo "❌ Файл config.php не найден"
    exit 1
fi

# Очистка кэша и временных файлов
echo "🧹 Очистка кэша и временных файлов..."
if [ -d "$DATA_DIR/cache" ]; then
    rm -rf $DATA_DIR/cache/*
    echo "✅ Кэш очищен"
fi

if [ -d "$DATA_DIR/sessions" ]; then
    rm -rf $DATA_DIR/sessions/*
    echo "✅ Сессии очищены"
fi

if [ -d "$DATA_DIR/temp" ]; then
    rm -rf $DATA_DIR/temp/*
    echo "✅ Временные файлы очищены"
fi

if [ -d "$DATA_DIR/localcache" ]; then
    rm -rf $DATA_DIR/localcache/*
    echo "✅ Локальный кэш очищен"
fi

# Сброс базы данных
echo "🗄️  Сброс базы данных..."
PGPASSWORD="$DB_PASS" dropdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME"
PGPASSWORD="$DB_PASS" createdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME"
echo "✅ База данных пересоздана"

# Скачивание и установка чистого Moodle
echo "📥 Загрузка чистой версии Moodle..."
cd /tmp
wget -O moodle-clean.tgz https://download.moodle.org/download.php/direct/stable50/moodle-latest-50.tgz
tar -xzf moodle-clean.tgz

# Сохранение текущего config.php
echo "💾 Сохранение текущей конфигурации..."
cp $MOODLE_DIR/config.php /tmp/config.php.backup

# Замена файлов Moodle на чистые
echo "🔄 Замена файлов Moodle..."
rm -rf $MOODLE_DIR.old
mv $MOODLE_DIR $MOODLE_DIR.old
mv moodle $MOODLE_DIR

# Восстановление конфигурации
echo "⚙️  Восстановление конфигурации..."
cp /tmp/config.php.backup $MOODLE_DIR/config.php

# Установка прав доступа
echo "🔐 Установка прав доступа..."
chown -R www-data:www-data $MOODLE_DIR
chown -R www-data:www-data $DATA_DIR
./fix-permissions.sh

# Запуск веб-сервера
echo "▶️  Запуск веб-сервера..."
systemctl start nginx

# Установка Moodle
echo "🚀 Запуск установки Moodle..."
cd $MOODLE_DIR

# Установка через CLI
sudo -u www-data php admin/cli/install_database.php \
    --agree-license \
    --adminuser=admin \
    --adminpass=RTTIAdmin2024! \
    --adminemail=admin@rtti.tj \
    --fullname="RTTI Learning Management System" \
    --shortname="RTTI LMS" \
    --summary="Система управления обучением RTTI"

# Дополнительные настройки
echo "⚙️  Применение дополнительных настроек..."

# Настройка языка
sudo -u www-data php admin/cli/cfg.php --name=lang --set=ru

# Настройка timezone
sudo -u www-data php admin/cli/cfg.php --name=timezone --set=Asia/Dushanbe

# Включение регистрации пользователей
sudo -u www-data php admin/cli/cfg.php --name=registerauth --set=email

# Настройка email
sudo -u www-data php admin/cli/cfg.php --name=smtphosts --set=localhost
sudo -u www-data php admin/cli/cfg.php --name=noreplyaddress --set=noreply@rtti.tj

# Отключение режима обслуживания
echo "✅ Отключение режима обслуживания..."
sudo -u www-data php admin/cli/maintenance.php --disable

# Очистка кэша
echo "🧹 Очистка кэша..."
sudo -u www-data php admin/cli/purge_caches.php

# Создание информационного файла
echo "📋 Создание информационного файла..."
RESET_INFO="/root/moodle-reset-$(date +%Y%m%d_%H%M%S).txt"

cat > $RESET_INFO << EOF
Moodle Reset Information
=======================
Date: $(date)
Server: $(hostname)
Action: Complete Moodle Reset

Database Details:
- Name: $DB_NAME
- User: $DB_USER
- Host: $DB_HOST

Administrator Account:
- Username: admin
- Password: RTTIAdmin2024!
- Email: admin@rtti.tj

URLs:
- Site: $WWW_ROOT
- Admin: $WWW_ROOT/admin/

Directories:
- Moodle: $MOODLE_DIR
- Data: $DATA_DIR
- Old Moodle: $MOODLE_DIR.old

Backup Created: Check $BACKUP_DIR for emergency backup
EOF

echo "✅ Информация сохранена в: $RESET_INFO"

# Проверка системы
echo "🔍 Проверка системы после сброса..."
./diagnose-moodle.sh

echo
echo "🎉 СБРОС MOODLE ЗАВЕРШЕН УСПЕШНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "🌐 URL: $WWW_ROOT"
echo "👤 Администратор: admin"
echo "🔑 Пароль: RTTIAdmin2024!"
echo "📧 Email: admin@rtti.tj"
echo
echo "📁 Важные файлы:"
echo "   📋 Информация о сбросе: $RESET_INFO"
echo "   💾 Экстренный бэкап: $BACKUP_DIR"
echo "   📂 Старые файлы: $MOODLE_DIR.old"
echo
echo "🔧 Следующие шаги:"
echo "   1. Откройте $WWW_ROOT в браузере"
echo "   2. Войдите с новыми данными администратора"
echo "   3. Настройте систему под ваши потребности"
echo "   4. Импортируйте необходимые курсы и пользователей"
echo
echo "⚠️  ВНИМАНИЕ: Старые файлы сохранены в $MOODLE_DIR.old"
echo "   Их можно удалить после проверки работоспособности системы"
