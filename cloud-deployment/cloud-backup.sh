#!/bin/bash
# Скрипт резервного копирования для облачного развертывания LMS
# Поддержка AWS S3, Google Cloud Storage, Azure Blob, DigitalOcean Spaces

set -e

# Конфигурация
BACKUP_DIR="/opt/cloud-backups"
LOG_FILE="/var/log/cloud-backup.log"
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

# Облачные настройки (определяются автоматически)
CLOUD_PROVIDER=""
CLOUD_BUCKET=""
CLOUD_REGION=""

# Функции логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE"
    exit 1
}

# Определение облачного провайдера
detect_cloud_provider() {
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        CLOUD_PROVIDER="aws"
        CLOUD_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
        log "Обнаружен AWS EC2 в регионе $CLOUD_REGION"
    elif curl -s --max-time 3 http://169.254.169.254/metadata/v1/ &>/dev/null; then
        CLOUD_PROVIDER="digitalocean"
        CLOUD_REGION=$(curl -s http://169.254.169.254/metadata/v1/region)
        log "Обнаружен DigitalOcean в регионе $CLOUD_REGION"
    elif curl -s --max-time 3 "http://metadata.google.internal/computeMetadata/v1/" -H "Metadata-Flavor: Google" &>/dev/null; then
        CLOUD_PROVIDER="gcp"
        CLOUD_REGION=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | cut -d'/' -f4)
        log "Обнаружен GCP в зоне $CLOUD_REGION"
    elif curl -s --max-time 3 "http://169.254.169.254/metadata/instance" -H "Metadata: true" &>/dev/null; then
        CLOUD_PROVIDER="azure"
        CLOUD_REGION=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/location?api-version=2021-02-01&format=text")
        log "Обнаружен Azure в регионе $CLOUD_REGION"
    else
        CLOUD_PROVIDER="generic"
        log "Обычный VPS - используем локальное хранение"
    fi
}

# Настройка облачного хранилища
setup_cloud_storage() {
    case "$CLOUD_PROVIDER" in
        "aws")
            setup_aws_s3
            ;;
        "gcp")
            setup_gcp_storage
            ;;
        "azure")
            setup_azure_storage
            ;;
        "digitalocean")
            setup_do_spaces
            ;;
        *)
            log "Используется локальное хранение"
            ;;
    esac
}

# Настройка AWS S3
setup_aws_s3() {
    log "Настройка AWS S3..."
    
    # Устанавливаем AWS CLI если не установлен
    if ! command -v aws &> /dev/null; then
        apt update
        apt install -y awscli
    fi
    
    # Получаем метаданные EC2
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    
    # Создаем bucket name
    CLOUD_BUCKET="rtti-lms-backups-${CLOUD_REGION}-${INSTANCE_ID}"
    
    # Создаем bucket если не существует
    aws s3 mb "s3://$CLOUD_BUCKET" --region "$CLOUD_REGION" 2>/dev/null || true
    
    log "AWS S3 bucket: $CLOUD_BUCKET"
}

# Настройка Google Cloud Storage
setup_gcp_storage() {
    log "Настройка Google Cloud Storage..."
    
    # Устанавливаем gsutil если не установлен
    if ! command -v gsutil &> /dev/null; then
        curl https://sdk.cloud.google.com | bash
        source ~/.bashrc
    fi
    
    # Получаем project ID
    PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/project/project-id")
    
    # Создаем bucket name
    CLOUD_BUCKET="rtti-lms-backups-${PROJECT_ID}"
    
    # Создаем bucket если не существует
    gsutil mb -p "$PROJECT_ID" -l "$CLOUD_REGION" "gs://$CLOUD_BUCKET" 2>/dev/null || true
    
    log "GCP Storage bucket: $CLOUD_BUCKET"
}

# Настройка Azure Blob Storage
setup_azure_storage() {
    log "Настройка Azure Blob Storage..."
    
    # Устанавливаем Azure CLI если не установлен
    if ! command -v az &> /dev/null; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    fi
    
    # Аутентификация через managed identity
    az login --identity
    
    # Создаем storage account name
    CLOUD_BUCKET="rttilmsbackups$(date +%s | tail -c 6)"
    
    log "Azure Storage account: $CLOUD_BUCKET"
}

# Настройка DigitalOcean Spaces
setup_do_spaces() {
    log "Настройка DigitalOcean Spaces..."
    
    # Используем s3cmd для работы с Spaces
    if ! command -v s3cmd &> /dev/null; then
        apt update
        apt install -y s3cmd
    fi
    
    # Создаем bucket name
    CLOUD_BUCKET="rtti-lms-backups-$(hostname)"
    
    log "DigitalOcean Spaces: $CLOUD_BUCKET"
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
        upload_to_cloud "$backup_file" "databases/moodle/"
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
        upload_to_cloud "$backup_file" "databases/drupal/"
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
        upload_to_cloud "$backup_file" "files/moodle/"
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
        upload_to_cloud "$backup_file" "files/drupal/"
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
        upload_to_cloud "$backup_file" "configs/"
    else
        error "Ошибка создания резервной копии конфигураций"
    fi
}

# Загрузка в облачное хранилище
upload_to_cloud() {
    local file_path="$1"
    local cloud_path="$2"
    local filename=$(basename "$file_path")
    
    case "$CLOUD_PROVIDER" in
        "aws")
            aws s3 cp "$file_path" "s3://$CLOUD_BUCKET/$cloud_path$filename"
            ;;
        "gcp")
            gsutil cp "$file_path" "gs://$CLOUD_BUCKET/$cloud_path$filename"
            ;;
        "azure")
            az storage blob upload --account-name "$CLOUD_BUCKET" --container-name backups --name "$cloud_path$filename" --file "$file_path"
            ;;
        "digitalocean")
            s3cmd put "$file_path" "s3://$CLOUD_BUCKET/$cloud_path$filename"
            ;;
        *)
            log "Файл сохранен локально: $file_path"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "Файл загружен в облако: $cloud_path$filename"
        # Удаляем локальную копию для экономии места
        rm -f "$file_path"
    else
        log "Ошибка загрузки в облако, файл сохранен локально: $file_path"
    fi
}

# Очистка старых резервных копий
cleanup_old_backups() {
    log "Очистка старых резервных копий..."
    
    # Локальная очистка
    find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # Облачная очистка
    case "$CLOUD_PROVIDER" in
        "aws")
            # Настройка lifecycle policy для S3
            cat > /tmp/lifecycle.json << EOF
{
    "Rules": [
        {
            "ID": "DeleteOldBackups",
            "Status": "Enabled",
            "Expiration": {
                "Days": $RETENTION_DAYS
            }
        }
    ]
}
EOF
            aws s3api put-bucket-lifecycle-configuration --bucket "$CLOUD_BUCKET" --lifecycle-configuration file:///tmp/lifecycle.json 2>/dev/null || true
            rm -f /tmp/lifecycle.json
            ;;
        "gcp")
            # Настройка lifecycle для GCS
            cat > /tmp/lifecycle.json << EOF
{
    "rule": [
        {
            "action": {"type": "Delete"},
            "condition": {"age": $RETENTION_DAYS}
        }
    ]
}
EOF
            gsutil lifecycle set /tmp/lifecycle.json "gs://$CLOUD_BUCKET" 2>/dev/null || true
            rm -f /tmp/lifecycle.json
            ;;
        *)
            log "Автоматическая очистка облачных файлов не настроена для $CLOUD_PROVIDER"
            ;;
    esac
    
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
            --data "{\"text\":\"LMS Backup [$CLOUD_PROVIDER]: $status - $message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
    
    # Отправка email (если настроен)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "LMS Cloud Backup - $status" admin@rtti.tj 2>/dev/null || true
    fi
    
    log "Уведомление отправлено: $status"
}

# Основная функция резервного копирования
main_backup() {
    local backup_type="$1"
    
    log "=== Начало облачного резервного копирования LMS (тип: $backup_type) ==="
    
    detect_cloud_provider
    setup_cloud_storage
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
    
    log "=== Облачное резервное копирование LMS завершено (тип: $backup_type) ==="
    send_notification "SUCCESS" "Резервное копирование завершено успешно на $CLOUD_PROVIDER"
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
    echo "Поддерживаемые облачные провайдеры:"
    echo "  - AWS S3"
    echo "  - Google Cloud Storage"
    echo "  - Azure Blob Storage"
    echo "  - DigitalOcean Spaces"
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
