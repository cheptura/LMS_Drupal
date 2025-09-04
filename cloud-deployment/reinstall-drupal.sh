#!/bin/bash
# Скрипт полной переустановки Drupal 11
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
warning "ВНИМАНИЕ: ПОЛНАЯ ПЕРЕУСТАНОВКА DRUPAL"
warning "========================================"
echo
warning "Этот скрипт удалит:"
warning "- Базу данных PostgreSQL 'drupal'"
warning "- Пользователя базы данных 'drupaluser'"
warning "- Все файлы Drupal (/var/www/html/drupal)"
warning "- Файлы учетных данных"
warning "- Конфигурацию Nginx для Drupal"
echo
warning "ВСЕ ДАННЫЕ БУДУТ ПОТЕРЯНЫ БЕЗВОЗВРАТНО!"
echo
read -p "Вы уверены, что хотите продолжить? Введите 'УДАЛИТЬ' для подтверждения: " -r
if [[ $REPLY != "УДАЛИТЬ" ]]; then
    log "Операция отменена пользователем"
    exit 0
fi

log "Начинаем полную переустановку Drupal..."

# Остановка веб-сервера
log "Остановка Nginx..."
systemctl stop nginx 2>/dev/null || true

# Удаление базы данных
log "Удаление базы данных PostgreSQL..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS drupal;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS drupaluser;" 2>/dev/null || true

# Удаление файлов Drupal
log "Удаление файлов Drupal..."
rm -rf /var/www/html/drupal 2>/dev/null || true
rm -rf /var/www/drupal 2>/dev/null || true

# Удаление конфигурации Nginx
log "Удаление конфигурации Nginx..."
rm -f /etc/nginx/sites-available/drupal 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/drupal 2>/dev/null || true

# Удаление учетных данных
log "Удаление файлов учетных данных..."
rm -f /root/drupal-credentials.txt 2>/dev/null || true
rm -f /root/drupal-admin-credentials.txt 2>/dev/null || true

# Перезагрузка конфигурации Nginx
log "Перезагрузка Nginx..."
systemctl reload nginx 2>/dev/null || true
systemctl start nginx 2>/dev/null || true

log "Очистка завершена успешно!"
echo
log "Теперь запускаем чистую установку Drupal..."
echo

# Загрузка и запуск установочного скрипта
if [ ! -f "install-drupal-cloud.sh" ]; then
    log "Загрузка установочного скрипта..."
    wget -O install-drupal-cloud.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/install-drupal-cloud.sh
    chmod +x install-drupal-cloud.sh
fi

# Запуск установки
log "Запуск установки Drupal 11..."
./install-drupal-cloud.sh cleanup

log "========================================"
log "ПЕРЕУСТАНОВКА DRUPAL ЗАВЕРШЕНА УСПЕШНО!"
log "========================================"
