#!/bin/bash
# Скрипт резервного копирования LMS с NAS для продакшн
# Поддерживает Moodle 5.0.2 и Drupal 11 с расписанием бэкапов

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

# Конфигурация по умолчанию
BACKUP_TYPE="${1:-daily}"
MOODLE_ROOT="/var/www/moodle"
DRUPAL_ROOT="/var/www/drupal"
MOODLE_DATA="/var/moodledata"
NAS_MOUNT="/mnt/nas"
BACKUP_ROOT="$NAS_MOUNT/backups"
LOG_FILE="/var/log/nas-backup.log"

# Время хранения бэкапов
DAILY_RETENTION=7    # 7 дней
WEEKLY_RETENTION=4   # 4 недели
MONTHLY_RETENTION=12 # 12 месяцев

# Функция проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен запускаться с правами root"
    fi
}

# Проверка подключения NAS
check_nas_connection() {
    if ! mountpoint -q "$NAS_MOUNT"; then
        warning "NAS не смонтирован. Попытка подключения..."
        mount -a
        sleep 5
        
        if ! mountpoint -q "$NAS_MOUNT"; then
            error "Не удалось подключиться к NAS"
        fi
    fi
    
    log "NAS подключен успешно"
}

# Создание директорий для бэкапов
create_backup_directories() {
    log "Создание директорий для бэкапов..."
    
    mkdir -p "$BACKUP_ROOT"/{daily,weekly,monthly}
    mkdir -p "$BACKUP_ROOT"/daily/{moodle,drupal,databases,logs}
    mkdir -p "$BACKUP_ROOT"/weekly/{moodle,drupal,databases,logs}
    mkdir -p "$BACKUP_ROOT"/monthly/{moodle,drupal,databases,logs}
    
    # Создание директории для текущего бэкапа
    CURRENT_DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="$BACKUP_ROOT/$BACKUP_TYPE/$CURRENT_DATE"
    mkdir -p "$BACKUP_DIR"/{moodle,drupal,databases,configs,logs}
    
    log "Директории созданы: $BACKUP_DIR"
}

# Включение режима обслуживания
enable_maintenance_mode() {
    log "Включение режима обслуживания..."
    
    # Moodle maintenance mode
    if [ -f "$MOODLE_ROOT/admin/cli/maintenance.php" ]; then
        sudo -u www-data php "$MOODLE_ROOT/admin/cli/maintenance.php" --enable
        log "Режим обслуживания Moodle включен"
    fi
    
    # Drupal maintenance mode
    if [ -f "$DRUPAL_ROOT/web" ] && command -v drush &> /dev/null; then
        sudo -u www-data drush --root="$DRUPAL_ROOT/web" state:set system.maintenance_mode 1
        sudo -u www-data drush --root="$DRUPAL_ROOT/web" cr
        log "Режим обслуживания Drupal включен"
    fi
    
    sleep 10  # Даем время завершиться активным операциям
}

# Отключение режима обслуживания
disable_maintenance_mode() {
    log "Отключение режима обслуживания..."
    
    # Moodle maintenance mode
    if [ -f "$MOODLE_ROOT/admin/cli/maintenance.php" ]; then
        sudo -u www-data php "$MOODLE_ROOT/admin/cli/maintenance.php" --disable
        log "Режим обслуживания Moodle отключен"
    fi
    
    # Drupal maintenance mode
    if [ -f "$DRUPAL_ROOT/web" ] && command -v drush &> /dev/null; then
        sudo -u www-data drush --root="$DRUPAL_ROOT/web" state:set system.maintenance_mode 0
        sudo -u www-data drush --root="$DRUPAL_ROOT/web" cr
        log "Режим обслуживания Drupal отключен"
    fi
}

# Резервное копирование баз данных
backup_databases() {
    log "Резервное копирование баз данных..."
    
    # Moodle database
    if systemctl is-active --quiet postgresql; then
        sudo -u postgres pg_dump moodle | gzip > "$BACKUP_DIR/databases/moodle_$(date +%Y%m%d_%H%M%S).sql.gz"
        log "База данных Moodle скопирована"
    fi
    
    # Drupal database
    if [ -f "$DRUPAL_ROOT/web" ] && command -v drush &> /dev/null; then
        sudo -u www-data drush --root="$DRUPAL_ROOT/web" sql:dump --gzip --result-file="$BACKUP_DIR/databases/drupal_$(date +%Y%m%d_%H%M%S).sql.gz"
        log "База данных Drupal скопирована"
    elif systemctl is-active --quiet postgresql; then
        sudo -u postgres pg_dump drupal_library | gzip > "$BACKUP_DIR/databases/drupal_$(date +%Y%m%d_%H%M%S).sql.gz"
        log "База данных Drupal скопирована (прямой дамп)"
    fi
}

# Резервное копирование файлов Moodle
backup_moodle_files() {
    log "Резервное копирование файлов Moodle..."
    
    # Исключаем временные файлы и кэш
    tar --exclude="$MOODLE_ROOT/cache" \
        --exclude="$MOODLE_ROOT/temp" \
        --exclude="$MOODLE_ROOT/trashdir" \
        --exclude="$MOODLE_DATA/cache" \
        --exclude="$MOODLE_DATA/temp" \
        --exclude="$MOODLE_DATA/trashdir" \
        --exclude="$MOODLE_DATA/sessions" \
        -czf "$BACKUP_DIR/moodle/moodle_files_$(date +%Y%m%d_%H%M%S).tar.gz" \
        "$MOODLE_ROOT" "$MOODLE_DATA" 2>/dev/null
    
    # Отдельный бэкап конфига
    cp "$MOODLE_ROOT/config.php" "$BACKUP_DIR/configs/moodle_config.php"
    
    log "Файлы Moodle скопированы"
}

# Резервное копирование файлов Drupal
backup_drupal_files() {
    log "Резервное копирование файлов Drupal..."
    
    if [ -d "$DRUPAL_ROOT" ]; then
        # Исключаем сгенерированные файлы
        tar --exclude="$DRUPAL_ROOT/web/sites/*/files/css" \
            --exclude="$DRUPAL_ROOT/web/sites/*/files/js" \
            --exclude="$DRUPAL_ROOT/web/sites/*/files/php" \
            --exclude="$DRUPAL_ROOT/vendor" \
            --exclude="$DRUPAL_ROOT/node_modules" \
            -czf "$BACKUP_DIR/drupal/drupal_files_$(date +%Y%m%d_%H%M%S).tar.gz" \
            "$DRUPAL_ROOT" 2>/dev/null
        
        # Отдельный бэкап конфигов
        if [ -f "$DRUPAL_ROOT/web/sites/default/settings.php" ]; then
            cp "$DRUPAL_ROOT/web/sites/default/settings.php" "$BACKUP_DIR/configs/drupal_settings.php"
        fi
        
        log "Файлы Drupal скопированы"
    fi
}

# Резервное копирование конфигураций системы
backup_system_configs() {
    log "Резервное копирование конфигураций системы..."
    
    # Nginx конфигурации
    if [ -d "/etc/nginx/sites-available" ]; then
        tar -czf "$BACKUP_DIR/configs/nginx_configs_$(date +%Y%m%d_%H%M%S).tar.gz" \
            /etc/nginx/sites-available /etc/nginx/nginx.conf 2>/dev/null
    fi
    
    # PHP конфигурации
    if [ -d "/etc/php" ]; then
        tar -czf "$BACKUP_DIR/configs/php_configs_$(date +%Y%m%d_%H%M%S).tar.gz" \
            /etc/php/*/fpm/pool.d /etc/php/*/fpm/php.ini 2>/dev/null
    fi
    
    # PostgreSQL конфигурации
    if [ -d "/etc/postgresql" ]; then
        tar -czf "$BACKUP_DIR/configs/postgresql_configs_$(date +%Y%m%d_%H%M%S).tar.gz" \
            /etc/postgresql/*/main/postgresql.conf \
            /etc/postgresql/*/main/pg_hba.conf 2>/dev/null
    fi
    
    # Cron jobs
    crontab -l > "$BACKUP_DIR/configs/crontab_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || true
    
    log "Конфигурации системы скопированы"
}

# Резервное копирование логов
backup_logs() {
    log "Резервное копирование важных логов..."
    
    # Логи Nginx
    if [ -d "/var/log/nginx" ]; then
        tar -czf "$BACKUP_DIR/logs/nginx_logs_$(date +%Y%m%d_%H%M%S).tar.gz" \
            /var/log/nginx/*.log 2>/dev/null
    fi
    
    # Логи PHP
    if [ -d "/var/log/php8.2-fpm" ]; then
        tar -czf "$BACKUP_DIR/logs/php_logs_$(date +%Y%m%d_%H%M%S).tar.gz" \
            /var/log/php*.log 2>/dev/null
    fi
    
    # Системные логи
    tar -czf "$BACKUP_DIR/logs/system_logs_$(date +%Y%m%d_%H%M%S).tar.gz" \
        /var/log/syslog /var/log/auth.log /var/log/fail2ban.log 2>/dev/null
    
    log "Логи скопированы"
}

# Создание метаданных бэкапа
create_backup_metadata() {
    log "Создание метаданных бэкапа..."
    
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
=== LMS BACKUP METADATA ===
Backup Date: $(date)
Backup Type: $BACKUP_TYPE
Server: $(hostname)
IP Address: $(hostname -I | awk '{print $1}')

=== SYSTEM INFO ===
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Uptime: $(uptime -p)

=== SERVICES STATUS ===
Nginx: $(systemctl is-active nginx 2>/dev/null || echo "inactive")
PHP-FPM 8.2: $(systemctl is-active php8.2-fpm 2>/dev/null || echo "inactive")
PHP-FPM 8.3: $(systemctl is-active php8.3-fpm 2>/dev/null || echo "inactive")
PostgreSQL: $(systemctl is-active postgresql 2>/dev/null || echo "inactive")
Redis: $(systemctl is-active redis-server 2>/dev/null || echo "inactive")

=== DISK USAGE ===
$(df -h | grep -E '^/dev|^tmpfs')

=== BACKUP CONTENTS ===
$(ls -la "$BACKUP_DIR")

=== DATABASE SIZES ===
$(sudo -u postgres psql -c "\l+" 2>/dev/null | grep -E 'moodle|drupal' || echo "PostgreSQL not available")

=== MOODLE INFO ===
$(if [ -f "$MOODLE_ROOT/version.php" ]; then grep '$release' "$MOODLE_ROOT/version.php" | head -1; else echo "Moodle not found"; fi)

=== DRUPAL INFO ===
$(if [ -f "$DRUPAL_ROOT/composer.json" ]; then grep '"drupal/core"' "$DRUPAL_ROOT/composer.json"; else echo "Drupal not found"; fi)

=== NAS INFO ===
NAS Mount: $(mountpoint "$NAS_MOUNT" 2>/dev/null && echo "Connected" || echo "Disconnected")
Available Space: $(df -h "$NAS_MOUNT" 2>/dev/null | tail -1 | awk '{print $4}' || echo "Unknown")

=== BACKUP VERIFICATION ===
$(cd "$BACKUP_DIR" && find . -name "*.tar.gz" -exec sh -c 'echo -n "{}  "; tar -tzf "{}" | wc -l; echo " files"' \;)
$(cd "$BACKUP_DIR" && find . -name "*.sql.gz" -exec sh -c 'echo -n "{}  "; zcat "{}" | wc -l; echo " lines"' \;)
EOF
    
    # Создание checksum файла
    cd "$BACKUP_DIR"
    find . -type f -exec sha256sum {} \; > backup_checksums.txt
    
    log "Метаданные созданы"
}

# Очистка старых бэкапов
cleanup_old_backups() {
    log "Очистка старых бэкапов..."
    
    case $BACKUP_TYPE in
        "daily")
            find "$BACKUP_ROOT/daily" -maxdepth 1 -type d -mtime +$DAILY_RETENTION -exec rm -rf {} \; 2>/dev/null || true
            ;;
        "weekly")
            find "$BACKUP_ROOT/weekly" -maxdepth 1 -type d -mtime +$((WEEKLY_RETENTION * 7)) -exec rm -rf {} \; 2>/dev/null || true
            ;;
        "monthly")
            find "$BACKUP_ROOT/monthly" -maxdepth 1 -type d -mtime +$((MONTHLY_RETENTION * 30)) -exec rm -rf {} \; 2>/dev/null || true
            ;;
    esac
    
    log "Старые бэкапы очищены"
}

# Проверка целостности бэкапа
verify_backup() {
    log "Проверка целостности бэкапа..."
    
    # Проверка размеров файлов
    local backup_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    local min_size_mb=100  # Минимальный размер бэкапа в MB
    local backup_size_mb=$(du -sm "$BACKUP_DIR" | cut -f1)
    
    if [ "$backup_size_mb" -lt "$min_size_mb" ]; then
        warning "Размер бэкапа слишком мал: $backup_size"
    else
        log "Размер бэкапа: $backup_size"
    fi
    
    # Проверка архивов
    local corrupt_files=0
    for archive in $(find "$BACKUP_DIR" -name "*.tar.gz"); do
        if ! tar -tzf "$archive" >/dev/null 2>&1; then
            error "Поврежденный архив: $archive"
            corrupt_files=$((corrupt_files + 1))
        fi
    done
    
    # Проверка SQL дампов
    for sql_dump in $(find "$BACKUP_DIR" -name "*.sql.gz"); do
        if ! zcat "$sql_dump" | head -10 | grep -q "PostgreSQL\|CREATE\|INSERT" 2>/dev/null; then
            warning "Возможно поврежден SQL дамп: $sql_dump"
        fi
    done
    
    if [ "$corrupt_files" -eq 0 ]; then
        log "Проверка целостности прошла успешно"
    else
        error "Найдено $corrupt_files поврежденных файлов"
    fi
}

# Отправка уведомления о статусе
send_notification() {
    local status="$1"
    local message="$2"
    
    # Логирование в syslog
    logger -t "nas-backup" "$status: $message"
    
    # Отправка email (если настроен postfix/sendmail)
    if command -v mail &> /dev/null && [ -f "/etc/postfix/main.cf" ]; then
        echo "$message" | mail -s "LMS Backup $status - $(hostname)" root
    fi
    
    # Создание статусного файла
    echo "$(date): $status - $message" >> "$NAS_MOUNT/backup_status.log"
}

# Главная функция резервного копирования
perform_backup() {
    local start_time=$(date +%s)
    
    log "Начинаем $BACKUP_TYPE резервное копирование..."
    
    # Включение режима обслуживания только для полных бэкапов
    if [ "$BACKUP_TYPE" = "weekly" ] || [ "$BACKUP_TYPE" = "monthly" ]; then
        enable_maintenance_mode
    fi
    
    # Выполнение бэкапа
    backup_databases
    backup_moodle_files
    backup_drupal_files
    backup_system_configs
    backup_logs
    create_backup_metadata
    
    # Отключение режима обслуживания
    if [ "$BACKUP_TYPE" = "weekly" ] || [ "$BACKUP_TYPE" = "monthly" ]; then
        disable_maintenance_mode
    fi
    
    # Проверка и очистка
    verify_backup
    cleanup_old_backups
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local backup_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    
    log "$BACKUP_TYPE резервное копирование завершено за $duration секунд, размер: $backup_size"
    send_notification "SUCCESS" "$BACKUP_TYPE backup completed in $duration seconds, size: $backup_size"
}

# Функция восстановления из бэкапа
restore_from_backup() {
    local restore_dir="$1"
    
    if [ -z "$restore_dir" ] || [ ! -d "$restore_dir" ]; then
        error "Некорректная директория для восстановления: $restore_dir"
    fi
    
    log "Восстановление из бэкапа: $restore_dir"
    
    echo "ВНИМАНИЕ: Это полностью заменит текущие данные!"
    read -p "Вы уверены? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Восстановление отменено"
        return
    fi
    
    enable_maintenance_mode
    
    # Восстановление баз данных
    for sql_file in "$restore_dir"/databases/*.sql.gz; do
        if [[ "$sql_file" == *"moodle"* ]]; then
            log "Восстановление базы данных Moodle..."
            sudo -u postgres dropdb --if-exists moodle
            sudo -u postgres createdb moodle
            zcat "$sql_file" | sudo -u postgres psql moodle
        elif [[ "$sql_file" == *"drupal"* ]]; then
            log "Восстановление базы данных Drupal..."
            sudo -u postgres dropdb --if-exists drupal_library
            sudo -u postgres createdb drupal_library
            zcat "$sql_file" | sudo -u postgres psql drupal_library
        fi
    done
    
    # Восстановление файлов
    for tar_file in "$restore_dir"/moodle/*.tar.gz; do
        log "Восстановление файлов Moodle..."
        tar -xzf "$tar_file" -C / --overwrite
    done
    
    for tar_file in "$restore_dir"/drupal/*.tar.gz; do
        log "Восстановление файлов Drupal..."
        tar -xzf "$tar_file" -C / --overwrite
    done
    
    # Восстановление прав доступа
    chown -R www-data:www-data "$MOODLE_ROOT" "$MOODLE_DATA"
    if [ -d "$DRUPAL_ROOT" ]; then
        chown -R www-data:www-data "$DRUPAL_ROOT"
    fi
    
    systemctl restart nginx php8.2-fpm php8.3-fpm
    
    disable_maintenance_mode
    
    log "Восстановление завершено"
}

# Список доступных бэкапов
list_backups() {
    log "Доступные бэкапы в NAS:"
    
    for backup_type in daily weekly monthly; do
        echo "=== $backup_type ==="
        ls -la "$BACKUP_ROOT/$backup_type/" 2>/dev/null | grep "^d" | awk '{print $9}' || echo "Нет бэкапов"
        echo
    done
}

# Проверка использования
usage() {
    echo "Использование: $0 [daily|weekly|monthly|restore|list]"
    echo
    echo "Команды:"
    echo "  daily   - Ежедневное резервное копирование"
    echo "  weekly  - Еженедельное резервное копирование"
    echo "  monthly - Ежемесячное резервное копирование"
    echo "  restore - Восстановление из бэкапа"
    echo "  list    - Список доступных бэкапов"
    echo
    echo "Примеры:"
    echo "  $0 daily"
    echo "  $0 restore /mnt/nas/backups/daily/20241203_020000"
}

# Главная функция
main() {
    case "${1:-daily}" in
        "daily"|"weekly"|"monthly")
            check_root
            check_nas_connection
            create_backup_directories
            perform_backup
            ;;
        "restore")
            check_root
            check_nas_connection
            restore_from_backup "$2"
            ;;
        "list")
            check_nas_connection
            list_backups
            ;;
        "help"|"-h"|"--help")
            usage
            ;;
        *)
            error "Неизвестная команда: $1"
            usage
            ;;
    esac
}

# Обработка ошибок
trap 'error "Резервное копирование прервано"; disable_maintenance_mode; exit 1' ERR

# Запуск скрипта
main "$@" 2>&1 | tee -a "$LOG_FILE"
