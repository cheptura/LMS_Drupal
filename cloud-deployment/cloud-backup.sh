#!/bin/bash
# Скрипт резервного копирования для LMS
# Стандартное локальное резервное копирование Moodle и Drupal

set -e

# Конфигурация
BACKUP_DIR="/opt/lms-backups"
LOG_FILE="/var/log/lms-backup.log"
RETENTION_DAYS=30

# Базы данных
MOODLE_DB="moodle"
DRUPAL_DB="drupal_library"
DB_USER="postgres"
DB_HOST="localhost"

# Директории
MOODLE_ROOT="/var/www/moodle"
DRUPAL_ROOT="/var/www/drupal"
MOODLE_DATA="/var/moodledata"

# Функции логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE"
    exit 1
}

# Создание директорий
create_directories() {
    log "Создание директорий для резервного копирования..."
    
    mkdir -p "$BACKUP_DIR"/{databases,files,configs}
    mkdir -p "$BACKUP_DIR"/databases/{moodle,drupal}
    mkdir -p "$BACKUP_DIR"/files/{moodle,drupal}
    
    log "Директории созданы"
}

# Резервное копирование базы данных Moodle
backup_moodle_database() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/databases/moodle/moodle_${timestamp}.sql.gz"
    
    log "Создание резервной копии БД Moodle..."
    
    # Определяем тип БД и создаем backup
    if systemctl is-active --quiet postgresql; then
        # PostgreSQL
        sudo -u postgres pg_dump "$MOODLE_DB" | gzip > "$backup_file"
    elif systemctl is-active --quiet mysql; then
        # MySQL
        mysqldump --single-transaction --routines --triggers "$MOODLE_DB" | gzip > "$backup_file"
    else
        error "База данных не найдена"
    fi
    
    if [ $? -eq 0 ]; then
        log "Резервная копия БД Moodle создана: $backup_file"
    else
        error "Ошибка создания резервной копии БД Moodle"
    fi
}

# Резервное копирование базы данных Drupal
backup_drupal_database() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/databases/drupal/drupal_${timestamp}.sql.gz"
    
    log "Создание резервной копии БД Drupal..."
    
    # Используем Drush для создания backup
    if command -v drush &> /dev/null && [ -d "$DRUPAL_ROOT" ]; then
        cd "$DRUPAL_ROOT"
        sudo -u www-data drush sql:dump --gzip --result-file="$backup_file" 2>/dev/null || {
            # Fallback к прямому дампу БД
            if systemctl is-active --quiet postgresql; then
                sudo -u postgres pg_dump "$DRUPAL_DB" | gzip > "$backup_file"
            elif systemctl is-active --quiet mysql; then
                mysqldump --single-transaction --routines --triggers "$DRUPAL_DB" | gzip > "$backup_file"
            fi
        }
    else
        # Прямой дамп БД
        if systemctl is-active --quiet postgresql; then
            sudo -u postgres pg_dump "$DRUPAL_DB" | gzip > "$backup_file"
        elif systemctl is-active --quiet mysql; then
            mysqldump --single-transaction --routines --triggers "$DRUPAL_DB" | gzip > "$backup_file"
        fi
    fi
    
    if [ $? -eq 0 ]; then
        log "Резервная копия БД Drupal создана: $backup_file"
    else
        error "Ошибка создания резервной копии БД Drupal"
    fi
}

# Резервное копирование файлов Moodle
backup_moodle_files() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/files/moodle/moodle_files_${timestamp}.tar.gz"
    
    log "Создание резервной копии файлов Moodle..."
    
    # Включаем maintenance mode
    if [ -f "$MOODLE_ROOT/admin/cli/maintenance.php" ]; then
        sudo -u www-data php "$MOODLE_ROOT/admin/cli/maintenance.php" --enable 2>/dev/null || true
    fi
    
    # Создаем архив исключая временные файлы
    tar --exclude='*/cache/*' \
        --exclude='*/temp/*' \
        --exclude='*/sessions/*' \
        --exclude='*/locks/*' \
        --exclude='*/trashdir/*' \
        -czf "$backup_file" \
        -C "$(dirname "$MOODLE_ROOT")" "$(basename "$MOODLE_ROOT")" \
        $([ -d "$MOODLE_DATA" ] && echo "-C $(dirname "$MOODLE_DATA") $(basename "$MOODLE_DATA")") \
        2>/dev/null
    
    # Отключаем maintenance mode
    if [ -f "$MOODLE_ROOT/admin/cli/maintenance.php" ]; then
        sudo -u www-data php "$MOODLE_ROOT/admin/cli/maintenance.php" --disable 2>/dev/null || true
    fi
    
    if [ $? -eq 0 ]; then
        log "Резервная копия файлов Moodle создана: $backup_file"
    else
        error "Ошибка создания резервной копии файлов Moodle"
    fi
}

# Резервное копирование файлов Drupal
backup_drupal_files() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/files/drupal/drupal_files_${timestamp}.tar.gz"
    
    log "Создание резервной копии файлов Drupal..."
    
    # Включаем maintenance mode
    if [ -d "$DRUPAL_ROOT" ] && command -v drush &> /dev/null; then
        cd "$DRUPAL_ROOT"
        sudo -u www-data drush state:set system.maintenance_mode 1 2>/dev/null || true
        sudo -u www-data drush cr 2>/dev/null || true
    fi
    
    # Создаем архив исключая временные файлы
    tar --exclude='*/css/*' \
        --exclude='*/js/*' \
        --exclude='*/php/twig/*' \
        --exclude='*/tmp/*' \
        --exclude='*/translations/*' \
        --exclude='*/styles/*' \
        --exclude='node_modules' \
        --exclude='vendor' \
        -czf "$backup_file" \
        -C "$(dirname "$DRUPAL_ROOT")" "$(basename "$DRUPAL_ROOT")" \
        2>/dev/null
    
    # Отключаем maintenance mode
    if [ -d "$DRUPAL_ROOT" ] && command -v drush &> /dev/null; then
        cd "$DRUPAL_ROOT"
        sudo -u www-data drush state:set system.maintenance_mode 0 2>/dev/null || true
        sudo -u www-data drush cr 2>/dev/null || true
    fi
    
    if [ $? -eq 0 ]; then
        log "Резервная копия файлов Drupal создана: $backup_file"
    else
        error "Ошибка создания резервной копии файлов Drupal"
    fi
}

# Резервное копирование конфигураций
backup_configs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/configs/system_configs_${timestamp}.tar.gz"
    
    log "Создание резервной копии системных конфигураций..."
    
    tar -czf "$backup_file" \
        /etc/nginx/ \
        /etc/php/ \
        /etc/postgresql/ \
        /etc/mysql/ \
        /etc/ssl/ \
        /etc/crontab \
        /etc/hosts \
        /etc/fstab \
        /root/*-installation-info.txt \
        /root/*-credentials.txt \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        log "Резервная копия конфигураций создана: $backup_file"
    else
        error "Ошибка создания резервной копии конфигураций"
    fi
}

# Очистка старых резервных копий
cleanup_old_backups() {
    log "Очистка старых резервных копий..."
    
    # Локальная очистка
    find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    log "Очистка старых резервных копий завершена"
}

# Проверка целостности резервных копий
verify_backups() {
    log "Проверка целостности резервных копий..."
    
    local errors=0
    
    # Проверка локальных архивов
    for backup_file in $(find "$BACKUP_DIR" -name "*.tar.gz" -mtime -1 2>/dev/null); do
        if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
            log "ERROR: Поврежденный архив: $backup_file"
            ((errors++))
        fi
    done
    
    # Проверка SQL архивов
    for backup_file in $(find "$BACKUP_DIR" -name "*.sql.gz" -mtime -1 2>/dev/null); do
        if ! gzip -t "$backup_file" 2>/dev/null; then
            log "ERROR: Поврежденный SQL архив: $backup_file"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log "Все резервные копии прошли проверку целостности"
    else
        log "Обнаружено $errors поврежденных резервных копий"
    fi
}

# Отправка уведомлений
send_notification() {
    local status="$1"
    local message="$2"
    
    # Отправка в Slack (если настроен webhook)
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"LMS Backup: $status - $message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
    
    # Отправка email (если настроен)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "LMS Backup - $status" admin@rtti.tj 2>/dev/null || true
    fi
    
    log "Уведомление отправлено: $status"
}

# Основная функция резервного копирования
main_backup() {
    local backup_type="$1"
    
    log "=== Начало резервного копирования LMS (тип: $backup_type) ==="
    
    create_directories
    
    case "$backup_type" in
        "databases"|"db")
            backup_moodle_database
            backup_drupal_database
            ;;
        "files")
            backup_moodle_files
            backup_drupal_files
            ;;
        "configs")
            backup_configs
            ;;
        "full"|*)
            backup_moodle_database
            backup_drupal_database
            backup_moodle_files
            backup_drupal_files
            backup_configs
            ;;
    esac
    
    cleanup_old_backups
    verify_backups
    
    log "=== Резервное копирование LMS завершено (тип: $backup_type) ==="
    send_notification "SUCCESS" "Резервное копирование завершено успешно"
}

# Показать справку
show_help() {
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "Команды резервного копирования:"
    echo "  full      - Полное резервное копирование (БД + файлы + конфиги)"
    echo "  databases - Резервное копирование только баз данных"
    echo "  files     - Резервное копирование только файлов"
    echo "  configs   - Резервное копирование только конфигураций"
    echo ""
    echo "Другие команды:"
    echo "  verify    - Проверка целостности резервных копий"
    echo "  cleanup   - Очистка старых резервных копий"
    echo "  help      - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 full"
    echo "  $0 databases"
    echo "  $0 verify"
    echo ""
    echo "Поддерживаемые системы:"
    echo "  - Moodle 5.0.2 LMS"
    echo "  - Drupal 11 Library"
}

# Главная логика
case "${1:-full}" in
    "full"|"databases"|"db"|"files"|"configs")
        main_backup "$1"
        ;;
    "verify")
        verify_backups
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "help"|*)
        show_help
        ;;
esac
