#!/bin/bash
# Быстрое исправление ошибки "role moodleuser cannot be dropped because some objects depend on it"

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log "🔧 Исправление ошибки PostgreSQL: role moodleuser cannot be dropped"

# Проверяем что PostgreSQL запущен
if ! systemctl is-active --quiet postgresql; then
    log "Запуск PostgreSQL..."
    systemctl start postgresql
fi

log "Правильная последовательность удаления пользователя moodleuser..."

# 1. Удаляем базу данных первой
log "1. Удаление базы данных moodle..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS moodle;" 2>/dev/null || true

# 2. Переназначаем принадлежность объектов
log "2. Переназначение объектов принадлежащих moodleuser..."
sudo -u postgres psql -c "REASSIGN OWNED BY moodleuser TO postgres;" 2>/dev/null || true

# 3. Удаляем объекты принадлежащие пользователю
log "3. Удаление объектов принадлежащих moodleuser..."
sudo -u postgres psql -c "DROP OWNED BY moodleuser;" 2>/dev/null || true

# 4. Теперь можем безопасно удалить пользователя
log "4. Удаление пользователя moodleuser..."
if sudo -u postgres psql -c "DROP USER IF EXISTS moodleuser;" 2>/dev/null; then
    log "✅ Пользователь moodleuser успешно удален"
else
    error "❌ Не удалось удалить пользователя moodleuser"
fi

# 5. Создаем нового пользователя с правильным паролем
log "5. Создание нового пользователя moodleuser..."
DB_PASSWORD=$(openssl rand -base64 32)
sudo -u postgres psql -c "CREATE USER moodleuser WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "ALTER USER moodleuser CREATEDB;"

# 6. Создаем новую базу данных
log "6. Создание новой базы данных moodle..."
sudo -u postgres psql -c "CREATE DATABASE moodle OWNER moodleuser;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE moodle TO moodleuser;"

# 7. Сохраняем учетные данные
log "7. Сохранение учетных данных..."
{
    echo "# Учетные данные базы данных Moodle (исправлено $(date))"
    echo "DB_HOST=localhost"
    echo "DB_NAME=moodle"
    echo "DB_USER=moodleuser"
    echo "DB_PASSWORD=$DB_PASSWORD"
    echo "DB_TYPE=pgsql"
} > /root/moodle-credentials.txt

chmod 600 /root/moodle-credentials.txt

# 8. Обновляем config.php если существует
if [ -f "/var/www/html/moodle/config.php" ]; then
    log "8. Обновление config.php..."
    cp /var/www/html/moodle/config.php /var/www/html/moodle/config.php.backup
    sed -i "s/\$CFG->dbpass = .*/\$CFG->dbpass = '$DB_PASSWORD';/" /var/www/html/moodle/config.php
    log "config.php обновлен с новым паролем"
else
    log "8. config.php не найден, будет создан при установке"
fi

# 9. Перезапускаем PostgreSQL
log "9. Перезапуск PostgreSQL..."
systemctl restart postgresql

# 10. Тестируем
log "10. Тестирование нового подключения..."
if sudo -u postgres psql -d moodle -c "SELECT version();" >/dev/null 2>&1; then
    log "✅ Подключение к базе данных успешно"
else
    error "❌ Ошибка подключения к базе данных"
fi

log "🎉 Проблема успешно исправлена!"
echo
echo "Информация о пользователях PostgreSQL:"
sudo -u postgres psql -c '\du'
echo
echo "Информация о базах данных:"
sudo -u postgres psql -l | grep moodle
echo
echo "📋 Учетные данные сохранены в: /root/moodle-credentials.txt"
echo "🚀 Теперь можно продолжить установку Moodle"
