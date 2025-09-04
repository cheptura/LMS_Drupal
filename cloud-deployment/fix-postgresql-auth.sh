#!/bin/bash
# Скрипт исправления проблем с аутентификацией PostgreSQL для Moodle
# Используется когда пользователь moodleuser не может подключиться к базе данных

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

log "🔧 Исправление проблем с PostgreSQL аутентификацией"

# Проверяем что PostgreSQL запущен
if ! systemctl is-active --quiet postgresql; then
    log "Запуск PostgreSQL..."
    systemctl start postgresql
fi

# Проверяем существует ли пользователь moodleuser
log "Проверка существования пользователя moodleuser..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='moodleuser'" | grep -q 1; then
    log "Пользователь moodleuser существует"
    
    # Пересоздаем пользователя с новым паролем
    log "Пересоздание пользователя moodleuser с новым паролем..."
    sudo -u postgres psql -c "DROP USER IF EXISTS moodleuser;"
else
    log "Пользователь moodleuser не существует, создаем..."
fi

# Генерируем новый пароль
DB_PASSWORD=$(openssl rand -base64 32)
log "Генерация нового пароля для базы данных..."

# Создаем пользователя
log "Создание пользователя moodleuser..."
sudo -u postgres psql -c "CREATE USER moodleuser WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "ALTER USER moodleuser CREATEDB;"

# Проверяем и пересоздаем базу данных
log "Настройка базы данных moodle..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS moodle;"
sudo -u postgres psql -c "CREATE DATABASE moodle OWNER moodleuser;"

# Предоставляем все права
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE moodle TO moodleuser;"

# Обновляем конфигурацию Moodle если она существует
if [ -f "/var/www/html/moodle/config.php" ]; then
    log "Обновление config.php с новым паролем..."
    
    # Создаем резервную копию
    cp /var/www/html/moodle/config.php /var/www/html/moodle/config.php.backup
    
    # Обновляем пароль в конфигурации
    sed -i "s/\$CFG->dbpass = .*/\$CFG->dbpass = '$DB_PASSWORD';/" /var/www/html/moodle/config.php
    
    log "Конфигурация Moodle обновлена"
else
    warning "config.php не найден, будет создан при установке Moodle"
fi

# Сохраняем учетные данные
log "Сохранение учетных данных в /root/moodle-credentials.txt..."
{
    echo "# Учетные данные базы данных Moodle (обновлено $(date))"
    echo "DB_HOST=localhost"
    echo "DB_NAME=moodle"
    echo "DB_USER=moodleuser"
    echo "DB_PASSWORD=$DB_PASSWORD"
    echo "DB_TYPE=pgsql"
} > /root/moodle-credentials.txt

chmod 600 /root/moodle-credentials.txt

# Перезапускаем PostgreSQL
log "Перезапуск PostgreSQL..."
systemctl restart postgresql

# Тест подключения
log "Тестирование подключения к базе данных..."
if sudo -u postgres psql -d moodle -c "SELECT version();" >/dev/null 2>&1; then
    log "✅ Подключение к базе данных moodle успешно"
else
    error "❌ Не удалось подключиться к базе данных moodle"
fi

# Тест с новыми учетными данными
log "Тестирование подключения с учетными данными moodleuser..."
export PGPASSWORD="$DB_PASSWORD"
if psql -h localhost -U moodleuser -d moodle -c "SELECT 1;" >/dev/null 2>&1; then
    log "✅ Аутентификация moodleuser успешна"
else
    warning "⚠️  Прямая аутентификация moodleuser не удалась, но это может быть нормально"
fi

# Показываем информацию о пользователях
log "Информация о пользователях PostgreSQL:"
sudo -u postgres psql -c '\du'

# Показываем информацию о базах данных
log "Информация о базах данных:"
sudo -u postgres psql -l | grep moodle

log "🎉 Исправление завершено!"
log "📋 Учетные данные сохранены в /root/moodle-credentials.txt"
log "🚀 Теперь можно продолжить установку Moodle"

echo
echo "Следующие шаги:"
echo "1. Запустить установку Moodle: sudo ./install-moodle-cloud.sh"
echo "2. Или продолжить установку через веб-интерфейс"
echo "3. Учетные данные базы данных: cat /root/moodle-credentials.txt"
