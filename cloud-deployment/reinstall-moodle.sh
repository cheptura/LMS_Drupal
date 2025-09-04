#!/bin/bash
# Скрипт полной переустановки Moodle 5.0+
# Автоматически удаляет все данные и выполняет чистую установку

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Проверка прав доступа
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен запускаться с правами root"
fi

# Предупреждение пользователя
warning "========================================"
warning "ВНИМАНИЕ: ПОЛНАЯ ПЕРЕУСТАНОВКА MOODLE"
warning "========================================"
echo
warning "Этот скрипт удалит:"
warning "- Базу данных PostgreSQL 'moodle'"
warning "- Пользователя базы данных 'moodleuser'"
warning "- Все файлы Moodle (/var/www/html/moodle)"
warning "- Все данные Moodle (/var/moodledata)"
warning "- Файлы учетных данных"
warning "- Конфигурацию Nginx для Moodle"
echo
warning "ВСЕ ДАННЫЕ БУДУТ ПОТЕРЯНЫ БЕЗВОЗВРАТНО!"
echo
read -p "Вы уверены, что хотите продолжить? Введите 'УДАЛИТЬ' для подтверждения: " -r
if [[ $REPLY != "УДАЛИТЬ" ]]; then
    log "Операция отменена пользователем"
    exit 0
fi

log "Начинаем полную переустановку Moodle..."

# Остановка веб-сервера
log "Остановка Nginx..."
systemctl stop nginx 2>/dev/null || true

# Удаление базы данных
log "Удаление базы данных PostgreSQL..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS moodle;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS moodleuser;" 2>/dev/null || true

# Удаление файлов Moodle
log "Удаление файлов Moodle..."
rm -rf /var/www/html/moodle 2>/dev/null || true
rm -rf /var/www/moodle 2>/dev/null || true
rm -rf /var/moodledata 2>/dev/null || true

# Удаление конфигурации Nginx
log "Удаление конфигурации Nginx..."
rm -f /etc/nginx/sites-available/moodle 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/moodle 2>/dev/null || true

# Удаление учетных данных
log "Удаление файлов учетных данных..."
rm -f /root/moodle-credentials.txt 2>/dev/null || true
rm -f /root/moodle-admin-credentials.txt 2>/dev/null || true

# Перезагрузка конфигурации Nginx
log "Перезагрузка Nginx..."
systemctl reload nginx 2>/dev/null || true
systemctl start nginx 2>/dev/null || true

log "Очистка завершена успешно!"
echo
log "Теперь запускаем чистую установку Moodle..."
echo

# Загрузка и запуск установочного скрипта
if [ ! -f "install-moodle-cloud.sh" ]; then
    log "Загрузка установочного скрипта..."
    wget -O install-moodle-cloud.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/install-moodle-cloud.sh
    chmod +x install-moodle-cloud.sh
fi

# Запуск установки
log "Запуск установки Moodle 5.0+..."
./install-moodle-cloud.sh cleanup

log "========================================"
log "ПЕРЕУСТАНОВКА MOODLE ЗАВЕРШЕНА УСПЕШНО!"
log "========================================"
