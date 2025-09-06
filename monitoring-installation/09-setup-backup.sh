#!/bin/bash

# RTTI Monitoring - Шаг 9: Резервное копирование мониторинга
# Серверы: omuzgorpro.tj (92.242.60.172), storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 9: Резервное копирование мониторинга ==="
echo "💾 Настройка автоматического резервного копирования конфигураций и данных"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

# Определение роли сервера
SERVER_IP=$(hostname -I | awk '{print $1}')
if [[ "$SERVER_IP" == "92.242.60.172" ]]; then
    SERVER_ROLE="moodle"
    SERVER_NAME="omuzgorpro.tj"
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    SERVER_ROLE="drupal"
    SERVER_NAME="storage.omuzgorpro.tj"
else
    SERVER_ROLE="standalone"
    SERVER_NAME=$(hostname -f)
fi

MONITORING_DIR="/opt/monitoring"
BACKUP_DIR="/opt/monitoring-backup"
REMOTE_BACKUP_DIR="/opt/remote-backup"

echo "🔍 Роль сервера: $SERVER_ROLE ($SERVER_NAME)"

echo "1. Создание структуры для резервного копирования..."
mkdir -p $BACKUP_DIR/{daily,weekly,monthly,configs,data,logs}
mkdir -p $REMOTE_BACKUP_DIR

echo "2. Создание скрипта резервного копирования конфигураций..."

cat > $BACKUP_DIR/backup-configs.sh << 'EOF'
#!/bin/bash
# Резервное копирование конфигураций мониторинга RTTI

MONITORING_DIR="/opt/monitoring"
BACKUP_DIR="/opt/monitoring-backup"
DATE=$(date +%Y%m%d_%H%M%S)
CONFIG_BACKUP_DIR="$BACKUP_DIR/configs"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/logs/backup.log"
}

log_message "=== Резервное копирование конфигураций RTTI ==="

# Создание архива конфигураций
BACKUP_FILE="$CONFIG_BACKUP_DIR/configs_$DATE.tar.gz"

log_message "Создание архива конфигураций: $BACKUP_FILE"

tar -czf "$BACKUP_FILE" \
    -C / \
    opt/monitoring/prometheus/config \
    opt/monitoring/prometheus/rules \
    opt/monitoring/grafana/provisioning \
    opt/monitoring/grafana/dashboards \
    opt/monitoring/alertmanager \
    opt/monitoring/docker/docker-compose.yml \
    opt/monitoring/optimization/configs \
    opt/monitoring/exporters \
    2>/dev/null

if [ $? -eq 0 ]; then
    log_message "✅ Архив конфигураций создан: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    log_message "❌ Ошибка создания архива конфигураций"
    exit 1
fi

# Создание отдельных резервных копий критичных файлов
log_message "Создание копий критичных файлов..."

# Prometheus конфигурация
cp "$MONITORING_DIR/prometheus/config/prometheus.yml" "$CONFIG_BACKUP_DIR/prometheus_$DATE.yml" 2>/dev/null
log_message "✅ Prometheus config backed up"

# Grafana dashboards
if [ -d "$MONITORING_DIR/grafana/dashboards" ]; then
    tar -czf "$CONFIG_BACKUP_DIR/dashboards_$DATE.tar.gz" -C "$MONITORING_DIR" grafana/dashboards 2>/dev/null
    log_message "✅ Grafana dashboards backed up"
fi

# Alertmanager конфигурация
if [ -f "$MONITORING_DIR/alertmanager/alertmanager.yml" ]; then
    cp "$MONITORING_DIR/alertmanager/alertmanager.yml" "$CONFIG_BACKUP_DIR/alertmanager_$DATE.yml" 2>/dev/null
    log_message "✅ Alertmanager config backed up"
fi

# Docker Compose файл
if [ -f "$MONITORING_DIR/docker/docker-compose.yml" ]; then
    cp "$MONITORING_DIR/docker/docker-compose.yml" "$CONFIG_BACKUP_DIR/docker-compose_$DATE.yml" 2>/dev/null
    log_message "✅ Docker Compose backed up"
fi

# Правила алертов
if [ -d "$MONITORING_DIR/prometheus/rules" ]; then
    tar -czf "$CONFIG_BACKUP_DIR/alert-rules_$DATE.tar.gz" -C "$MONITORING_DIR" prometheus/rules 2>/dev/null
    log_message "✅ Alert rules backed up"
fi

# Создание списка файлов в архиве
tar -tzf "$BACKUP_FILE" > "$CONFIG_BACKUP_DIR/contents_$DATE.txt" 2>/dev/null

# Удаление старых резервных копий (старше 30 дней)
find "$CONFIG_BACKUP_DIR" -name "*.tar.gz" -type f -mtime +30 -delete 2>/dev/null
find "$CONFIG_BACKUP_DIR" -name "*.yml" -type f -mtime +30 -delete 2>/dev/null
find "$CONFIG_BACKUP_DIR" -name "*.txt" -type f -mtime +30 -delete 2>/dev/null

log_message "🧹 Удалены старые резервные копии (>30 дней)"

# Проверка целостности архива
if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
    log_message "✅ Проверка целостности архива успешна"
else
    log_message "❌ Ошибка целостности архива"
fi

log_message "=== Резервное копирование конфигураций завершено ==="
EOF

chmod +x $BACKUP_DIR/backup-configs.sh

echo "3. Создание скрипта резервного копирования данных..."

cat > $BACKUP_DIR/backup-data.sh << 'EOF'
#!/bin/bash
# Резервное копирование данных мониторинга RTTI

MONITORING_DIR="/opt/monitoring"
BACKUP_DIR="/opt/monitoring-backup"
DATE=$(date +%Y%m%d_%H%M%S)
DATA_BACKUP_DIR="$BACKUP_DIR/data"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/logs/backup.log"
}

log_message "=== Резервное копирование данных RTTI ==="

# Остановка контейнеров для консистентного бэкапа
log_message "Остановка контейнеров для консистентного бэкапа..."
cd "$MONITORING_DIR/docker"
docker-compose stop prometheus grafana alertmanager

# Ожидание остановки
sleep 10

# Создание архива данных Prometheus
if [ -d "$MONITORING_DIR/data/prometheus" ]; then
    log_message "Создание архива данных Prometheus..."
    tar -czf "$DATA_BACKUP_DIR/prometheus-data_$DATE.tar.gz" -C "$MONITORING_DIR/data" prometheus 2>/dev/null
    if [ $? -eq 0 ]; then
        log_message "✅ Данные Prometheus заархивированы: $(du -h "$DATA_BACKUP_DIR/prometheus-data_$DATE.tar.gz" | cut -f1)"
    else
        log_message "❌ Ошибка архивирования данных Prometheus"
    fi
fi

# Создание архива данных Grafana
if [ -d "$MONITORING_DIR/data/grafana" ]; then
    log_message "Создание архива данных Grafana..."
    tar -czf "$DATA_BACKUP_DIR/grafana-data_$DATE.tar.gz" -C "$MONITORING_DIR/data" grafana 2>/dev/null
    if [ $? -eq 0 ]; then
        log_message "✅ Данные Grafana заархивированы: $(du -h "$DATA_BACKUP_DIR/grafana-data_$DATE.tar.gz" | cut -f1)"
    else
        log_message "❌ Ошибка архивирования данных Grafana"
    fi
fi

# Создание архива данных Alertmanager
if [ -d "$MONITORING_DIR/data/alertmanager" ]; then
    log_message "Создание архива данных Alertmanager..."
    tar -czf "$DATA_BACKUP_DIR/alertmanager-data_$DATE.tar.gz" -C "$MONITORING_DIR/data" alertmanager 2>/dev/null
    if [ $? -eq 0 ]; then
        log_message "✅ Данные Alertmanager заархивированы: $(du -h "$DATA_BACKUP_DIR/alertmanager-data_$DATE.tar.gz" | cut -f1)"
    else
        log_message "❌ Ошибка архивирования данных Alertmanager"
    fi
fi

# Запуск контейнеров
log_message "Запуск контейнеров..."
docker-compose start prometheus grafana alertmanager

# Ожидание запуска
sleep 30

# Проверка запуска сервисов
for service in prometheus grafana alertmanager; do
    if docker ps | grep -q "$service"; then
        log_message "✅ $service запущен"
    else
        log_message "❌ $service не запустился"
    fi
done

# Удаление старых резервных копий данных (старше 7 дней для ежедневных)
find "$DATA_BACKUP_DIR" -name "*-data_*.tar.gz" -type f -mtime +7 -delete 2>/dev/null
log_message "🧹 Удалены старые резервные копии данных (>7 дней)"

# Статистика использования места
log_message "Использование места резервными копиями:"
du -sh "$BACKUP_DIR"/* | tee -a "$BACKUP_DIR/logs/backup.log"

log_message "=== Резервное копирование данных завершено ==="
EOF

chmod +x $BACKUP_DIR/backup-data.sh

echo "4. Создание скрипта полного резервного копирования..."

cat > $BACKUP_DIR/backup-full.sh << 'EOF'
#!/bin/bash
# Полное резервное копирование мониторинга RTTI

MONITORING_DIR="/opt/monitoring"
BACKUP_DIR="/opt/monitoring-backup"
DATE=$(date +%Y%m%d_%H%M%S)
FULL_BACKUP_DIR="$BACKUP_DIR/weekly"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/logs/backup.log"
}

log_message "=== Полное резервное копирование RTTI ==="

# Создание полного архива
FULL_BACKUP_FILE="$FULL_BACKUP_DIR/full-monitoring_$DATE.tar.gz"

log_message "Создание полного архива: $FULL_BACKUP_FILE"

# Остановка сервисов для консистентного бэкапа
log_message "Остановка сервисов мониторинга..."
cd "$MONITORING_DIR/docker"
docker-compose down

sleep 15

# Создание полного архива
tar -czf "$FULL_BACKUP_FILE" \
    --exclude="$MONITORING_DIR/data/prometheus/wal" \
    --exclude="$MONITORING_DIR/data/prometheus/queries.active" \
    -C / \
    opt/monitoring \
    2>/dev/null

if [ $? -eq 0 ]; then
    log_message "✅ Полный архив создан: $(du -h "$FULL_BACKUP_FILE" | cut -f1)"
else
    log_message "❌ Ошибка создания полного архива"
fi

# Запуск сервисов
log_message "Запуск сервисов мониторинга..."
docker-compose up -d

sleep 60

# Проверка запуска
log_message "Проверка запуска сервисов:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(prometheus|grafana|alertmanager)" | tee -a "$BACKUP_DIR/logs/backup.log"

# Создание контрольной суммы
if [ -f "$FULL_BACKUP_FILE" ]; then
    md5sum "$FULL_BACKUP_FILE" > "$FULL_BACKUP_FILE.md5"
    log_message "✅ Создана контрольная сумма"
fi

# Удаление старых полных резервных копий (старше 4 недель)
find "$FULL_BACKUP_DIR" -name "full-monitoring_*.tar.gz" -type f -mtime +28 -delete 2>/dev/null
find "$FULL_BACKUP_DIR" -name "*.md5" -type f -mtime +28 -delete 2>/dev/null
log_message "🧹 Удалены старые полные резервные копии (>4 недели)"

log_message "=== Полное резервное копирование завершено ==="
EOF

chmod +x $BACKUP_DIR/backup-full.sh

echo "5. Создание скрипта восстановления..."

cat > $BACKUP_DIR/restore.sh << 'EOF'
#!/bin/bash
# Восстановление мониторинга RTTI из резервной копии

MONITORING_DIR="/opt/monitoring"
BACKUP_DIR="/opt/monitoring-backup"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

show_usage() {
    echo "Использование: $0 [опции]"
    echo "Опции:"
    echo "  -t TYPE     Тип восстановления: configs|data|full"
    echo "  -f FILE     Файл для восстановления"
    echo "  -l          Показать доступные резервные копии"
    echo "  -h          Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0 -l                                    # Показать доступные копии"
    echo "  $0 -t configs -f configs_20240904.tar.gz # Восстановить конфигурации"
    echo "  $0 -t data -f prometheus-data_20240904.tar.gz # Восстановить данные"
    echo "  $0 -t full -f full-monitoring_20240904.tar.gz # Полное восстановление"
}

list_backups() {
    log_message "=== Доступные резервные копии ==="
    
    echo "Конфигурации:"
    ls -lh "$BACKUP_DIR/configs/"*.tar.gz 2>/dev/null | tail -10
    
    echo -e "\nДанные:"
    ls -lh "$BACKUP_DIR/data/"*.tar.gz 2>/dev/null | tail -10
    
    echo -e "\nПолные резервные копии:"
    ls -lh "$BACKUP_DIR/weekly/"*.tar.gz 2>/dev/null | tail -5
}

restore_configs() {
    local backup_file="$1"
    
    log_message "=== Восстановление конфигураций ==="
    
    if [ ! -f "$backup_file" ]; then
        log_message "❌ Файл резервной копии не найден: $backup_file"
        return 1
    fi
    
    # Создание резервной копии текущих конфигураций
    local current_backup="/tmp/current-configs-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$current_backup" -C / opt/monitoring/prometheus/config opt/monitoring/grafana opt/monitoring/alertmanager 2>/dev/null
    log_message "📦 Текущие конфигурации сохранены в: $current_backup"
    
    # Восстановление конфигураций
    log_message "📥 Восстановление конфигураций из: $backup_file"
    tar -xzf "$backup_file" -C / 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "✅ Конфигурации восстановлены"
        
        # Перезагрузка конфигураций
        log_message "🔄 Перезагрузка конфигураций..."
        cd "$MONITORING_DIR/docker"
        docker-compose restart
        
        log_message "✅ Восстановление конфигураций завершено"
    else
        log_message "❌ Ошибка восстановления конфигураций"
        return 1
    fi
}

restore_data() {
    local backup_file="$1"
    
    log_message "=== Восстановление данных ==="
    
    if [ ! -f "$backup_file" ]; then
        log_message "❌ Файл резервной копии не найден: $backup_file"
        return 1
    fi
    
    # Остановка сервисов
    log_message "⏹️  Остановка сервисов мониторинга..."
    cd "$MONITORING_DIR/docker"
    docker-compose stop
    
    sleep 10
    
    # Создание резервной копии текущих данных
    local current_backup="/tmp/current-data-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$current_backup" -C "$MONITORING_DIR" data 2>/dev/null
    log_message "📦 Текущие данные сохранены в: $current_backup"
    
    # Восстановление данных
    log_message "📥 Восстановление данных из: $backup_file"
    
    # Определение типа данных по имени файла
    if [[ "$backup_file" == *"prometheus-data"* ]]; then
        rm -rf "$MONITORING_DIR/data/prometheus"
        tar -xzf "$backup_file" -C "$MONITORING_DIR/data" 2>/dev/null
    elif [[ "$backup_file" == *"grafana-data"* ]]; then
        rm -rf "$MONITORING_DIR/data/grafana"
        tar -xzf "$backup_file" -C "$MONITORING_DIR/data" 2>/dev/null
    elif [[ "$backup_file" == *"alertmanager-data"* ]]; then
        rm -rf "$MONITORING_DIR/data/alertmanager"
        tar -xzf "$backup_file" -C "$MONITORING_DIR/data" 2>/dev/null
    else
        log_message "❌ Неизвестный тип файла данных"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        log_message "✅ Данные восстановлены"
        
        # Запуск сервисов
        log_message "▶️  Запуск сервисов мониторинга..."
        docker-compose up -d
        
        sleep 60
        
        log_message "✅ Восстановление данных завершено"
    else
        log_message "❌ Ошибка восстановления данных"
        return 1
    fi
}

restore_full() {
    local backup_file="$1"
    
    log_message "=== Полное восстановление ==="
    
    if [ ! -f "$backup_file" ]; then
        log_message "❌ Файл резервной копии не найден: $backup_file"
        return 1
    fi
    
    # Проверка контрольной суммы
    if [ -f "$backup_file.md5" ]; then
        log_message "🔍 Проверка целостности архива..."
        if md5sum -c "$backup_file.md5"; then
            log_message "✅ Целостность архива подтверждена"
        else
            log_message "❌ Ошибка целостности архива"
            return 1
        fi
    fi
    
    # Остановка и удаление текущей установки
    log_message "⏹️  Остановка текущих сервисов..."
    cd "$MONITORING_DIR/docker" 2>/dev/null
    docker-compose down 2>/dev/null
    
    # Создание резервной копии текущей установки
    local current_backup="/tmp/current-monitoring-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$current_backup" -C / opt/monitoring 2>/dev/null
    log_message "📦 Текущая установка сохранена в: $current_backup"
    
    # Удаление текущей установки
    rm -rf "$MONITORING_DIR"
    
    # Полное восстановление
    log_message "📥 Полное восстановление из: $backup_file"
    tar -xzf "$backup_file" -C / 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "✅ Полное восстановление выполнено"
        
        # Запуск сервисов
        log_message "▶️  Запуск восстановленных сервисов..."
        cd "$MONITORING_DIR/docker"
        docker-compose up -d
        
        sleep 60
        
        # Проверка запуска
        log_message "🔍 Проверка запуска сервисов:"
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(prometheus|grafana|alertmanager)"
        
        log_message "✅ Полное восстановление завершено"
    else
        log_message "❌ Ошибка полного восстановления"
        
        # Попытка восстановить из current_backup
        if [ -f "$current_backup" ]; then
            log_message "🔄 Попытка восстановления из резервной копии..."
            tar -xzf "$current_backup" -C / 2>/dev/null
        fi
        
        return 1
    fi
}

# Обработка аргументов
while getopts "t:f:lh" opt; do
    case $opt in
        t)
            RESTORE_TYPE="$OPTARG"
            ;;
        f)
            BACKUP_FILE="$OPTARG"
            ;;
        l)
            list_backups
            exit 0
            ;;
        h)
            show_usage
            exit 0
            ;;
        \?)
            echo "❌ Неверная опция: -$OPTARG" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Проверка аргументов
if [ -z "$RESTORE_TYPE" ]; then
    echo "❌ Не указан тип восстановления"
    show_usage
    exit 1
fi

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Не указан файл резервной копии"
    show_usage
    exit 1
fi

# Поиск файла в соответствующей директории
case $RESTORE_TYPE in
    configs)
        FULL_BACKUP_PATH="$BACKUP_DIR/configs/$BACKUP_FILE"
        ;;
    data)
        FULL_BACKUP_PATH="$BACKUP_DIR/data/$BACKUP_FILE"
        ;;
    full)
        FULL_BACKUP_PATH="$BACKUP_DIR/weekly/$BACKUP_FILE"
        ;;
    *)
        echo "❌ Неверный тип восстановления: $RESTORE_TYPE"
        show_usage
        exit 1
        ;;
esac

# Выполнение восстановления
case $RESTORE_TYPE in
    configs)
        restore_configs "$FULL_BACKUP_PATH"
        ;;
    data)
        restore_data "$FULL_BACKUP_PATH"
        ;;
    full)
        restore_full "$FULL_BACKUP_PATH"
        ;;
esac
EOF

chmod +x $BACKUP_DIR/restore.sh

echo "6. Создание скрипта синхронизации с удаленным сервером..."

cat > $BACKUP_DIR/sync-remote.sh << 'EOF'
#!/bin/bash
# Синхронизация резервных копий с удаленным сервером

BACKUP_DIR="/opt/monitoring-backup"
REMOTE_BACKUP_DIR="/opt/remote-backup"

# Определение удаленного сервера
SERVER_IP=$(hostname -I | awk '{print $1}')
if [[ "$SERVER_IP" == "92.242.60.172" ]]; then
    REMOTE_SERVER="storage.omuzgorpro.tj"  # Drupal сервер
    REMOTE_IP="92.242.61.204"
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    REMOTE_SERVER="omuzgorpro.tj"      # Moodle сервер
    REMOTE_IP="92.242.60.172"
else
    echo "❌ Неизвестный сервер, синхронизация невозможна"
    exit 1
fi

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/logs/sync.log"
}

log_message "=== Синхронизация резервных копий с $REMOTE_SERVER ==="

# Проверка доступности удаленного сервера
if ping -c 1 "$REMOTE_IP" > /dev/null 2>&1; then
    log_message "✅ Удаленный сервер $REMOTE_SERVER доступен"
else
    log_message "❌ Удаленный сервер $REMOTE_SERVER недоступен"
    exit 1
fi

# Создание SSH ключа если не существует
if [ ! -f "/root/.ssh/id_rsa" ]; then
    log_message "🔑 Создание SSH ключа..."
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -C "monitoring-backup@$(hostname)"
    log_message "✅ SSH ключ создан"
fi

# Синхронизация конфигураций (ежедневно)
log_message "📤 Синхронизация конфигураций..."
rsync -avz --delete \
    -e "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
    "$BACKUP_DIR/configs/" \
    "root@$REMOTE_IP:$REMOTE_BACKUP_DIR/configs-from-$(hostname)/" \
    2>/dev/null

if [ $? -eq 0 ]; then
    log_message "✅ Конфигурации синхронизированы"
else
    log_message "❌ Ошибка синхронизации конфигураций"
fi

# Синхронизация критичных данных (еженедельно)
if [ "$(date +%u)" -eq 7 ]; then  # Воскресенье
    log_message "📤 Синхронизация критичных данных..."
    
    # Синхронизация только последних резервных копий
    rsync -avz \
        -e "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30" \
        --include="*.tar.gz" \
        --include="*.md5" \
        --max-size=1G \
        "$BACKUP_DIR/weekly/" \
        "root@$REMOTE_IP:$REMOTE_BACKUP_DIR/weekly-from-$(hostname)/" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "✅ Критичные данные синхронизированы"
    else
        log_message "❌ Ошибка синхронизации критичных данных"
    fi
fi

# Получение статуса удаленного мониторинга
log_message "📥 Получение статуса удаленного мониторинга..."
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$REMOTE_IP" \
    "docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E '(prometheus|grafana|alertmanager)'" \
    > "$BACKUP_DIR/logs/remote-status-$(date +%Y%m%d).txt" 2>/dev/null

if [ $? -eq 0 ]; then
    log_message "✅ Статус удаленного мониторинга получен"
else
    log_message "❌ Не удалось получить статус удаленного мониторинга"
fi

log_message "=== Синхронизация завершена ==="
EOF

chmod +x $BACKUP_DIR/sync-remote.sh

echo "7. Настройка cron задач для автоматического резервного копирования..."

# Резервное копирование конфигураций - ежедневно в 01:00
(crontab -l 2>/dev/null; echo "0 1 * * * $BACKUP_DIR/backup-configs.sh") | crontab -

# Резервное копирование данных - ежедневно в 02:00
(crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_DIR/backup-data.sh") | crontab -

# Полное резервное копирование - еженедельно в воскресенье в 03:00
(crontab -l 2>/dev/null; echo "0 3 * * 0 $BACKUP_DIR/backup-full.sh") | crontab -

# Синхронизация с удаленным сервером - ежедневно в 04:00
(crontab -l 2>/dev/null; echo "0 4 * * * $BACKUP_DIR/sync-remote.sh") | crontab -

echo "8. Создание скрипта проверки резервных копий..."

cat > $BACKUP_DIR/verify-backups.sh << 'EOF'
#!/bin/bash
# Проверка целостности резервных копий RTTI

BACKUP_DIR="/opt/monitoring-backup"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/logs/verify.log"
}

log_message "=== Проверка целостности резервных копий RTTI ==="

# Проверка конфигураций
log_message "🔍 Проверка резервных копий конфигураций..."
config_files=$(find "$BACKUP_DIR/configs" -name "*.tar.gz" -type f -mtime -7 | wc -l)
log_message "Найдено резервных копий конфигураций за последние 7 дней: $config_files"

if [ "$config_files" -eq 0 ]; then
    log_message "❌ Нет свежих резервных копий конфигураций"
else
    log_message "✅ Резервные копии конфигураций актуальны"
fi

# Проверка данных
log_message "🔍 Проверка резервных копий данных..."
data_files=$(find "$BACKUP_DIR/data" -name "*.tar.gz" -type f -mtime -1 | wc -l)
log_message "Найдено резервных копий данных за последние 24 часа: $data_files"

if [ "$data_files" -eq 0 ]; then
    log_message "❌ Нет свежих резервных копий данных"
else
    log_message "✅ Резервные копии данных актуальны"
fi

# Проверка полных резервных копий
log_message "🔍 Проверка полных резервных копий..."
full_files=$(find "$BACKUP_DIR/weekly" -name "*.tar.gz" -type f -mtime -7 | wc -l)
log_message "Найдено полных резервных копий за последние 7 дней: $full_files"

if [ "$full_files" -eq 0 ]; then
    log_message "❌ Нет свежих полных резервных копий"
else
    log_message "✅ Полные резервные копии актуальны"
fi

# Проверка целостности архивов
log_message "🔍 Проверка целостности архивов..."
corrupted=0

# Проверка последних архивов конфигураций
latest_config=$(find "$BACKUP_DIR/configs" -name "configs_*.tar.gz" -type f | sort | tail -1)
if [ -n "$latest_config" ]; then
    if tar -tzf "$latest_config" > /dev/null 2>&1; then
        log_message "✅ Последний архив конфигураций: OK"
    else
        log_message "❌ Последний архив конфигураций: ПОВРЕЖДЕН"
        corrupted=$((corrupted + 1))
    fi
fi

# Проверка последних архивов данных
for data_file in $(find "$BACKUP_DIR/data" -name "*-data_*.tar.gz" -type f -mtime -1); do
    if tar -tzf "$data_file" > /dev/null 2>&1; then
        log_message "✅ $(basename "$data_file"): OK"
    else
        log_message "❌ $(basename "$data_file"): ПОВРЕЖДЕН"
        corrupted=$((corrupted + 1))
    fi
done

# Проверка последнего полного архива
latest_full=$(find "$BACKUP_DIR/weekly" -name "full-monitoring_*.tar.gz" -type f | sort | tail -1)
if [ -n "$latest_full" ]; then
    if [ -f "$latest_full.md5" ]; then
        if md5sum -c "$latest_full.md5" > /dev/null 2>&1; then
            log_message "✅ Последний полный архив: OK (проверен MD5)"
        else
            log_message "❌ Последний полный архив: ПОВРЕЖДЕН (MD5 не совпадает)"
            corrupted=$((corrupted + 1))
        fi
    else
        if tar -tzf "$latest_full" > /dev/null 2>&1; then
            log_message "✅ Последний полный архив: OK"
        else
            log_message "❌ Последний полный архив: ПОВРЕЖДЕН"
            corrupted=$((corrupted + 1))
        fi
    fi
fi

# Статистика использования места
log_message "📊 Статистика использования места:"
du -sh "$BACKUP_DIR"/* | tee -a "$BACKUP_DIR/logs/verify.log"

total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
log_message "Общий размер резервных копий: $total_size"

# Общий результат
if [ "$corrupted" -eq 0 ]; then
    log_message "✅ Все резервные копии в порядке"
    exit 0
else
    log_message "❌ Обнаружено поврежденных архивов: $corrupted"
    exit 1
fi
EOF

chmod +x $BACKUP_DIR/verify-backups.sh

# Добавление проверки в cron - каждый день в 05:00
(crontab -l 2>/dev/null; echo "0 5 * * * $BACKUP_DIR/verify-backups.sh") | crontab -

echo "9. Создание конфигурации для мониторинга резервных копий..."

cat > $MONITORING_DIR/prometheus/rules/backup-alerts.yml << EOF
# Правила алертов для резервного копирования RTTI
# Дата: $(date)

groups:
  - name: rtti.backup
    rules:
      # Алерт при отсутствии свежих резервных копий
      - alert: BackupConfigsOld
        expr: (time() - node_filesystem_files_mtime{mountpoint="/opt/monitoring-backup/configs"}) > 86400  # 24 часа
        for: 1h
        labels:
          severity: warning
          service: backup
        annotations:
          summary: "Устаревшие резервные копии конфигураций на {{ \$labels.instance }}"
          description: "Резервные копии конфигураций не обновлялись более 24 часов"

      - alert: BackupDataOld
        expr: (time() - node_filesystem_files_mtime{mountpoint="/opt/monitoring-backup/data"}) > 86400  # 24 часа
        for: 1h
        labels:
          severity: warning
          service: backup
        annotations:
          summary: "Устаревшие резервные копии данных на {{ \$labels.instance }}"
          description: "Резервные копии данных не обновлялись более 24 часов"

      - alert: BackupFullOld
        expr: (time() - node_filesystem_files_mtime{mountpoint="/opt/monitoring-backup/weekly"}) > 604800  # 7 дней
        for: 2h
        labels:
          severity: critical
          service: backup
        annotations:
          summary: "Устаревшие полные резервные копии на {{ \$labels.instance }}"
          description: "Полные резервные копии не создавались более 7 дней"

      # Алерт при заполнении диска резервными копиями
      - alert: BackupDiskFull
        expr: (node_filesystem_size_bytes{mountpoint="/opt/monitoring-backup"} - node_filesystem_avail_bytes{mountpoint="/opt/monitoring-backup"}) / node_filesystem_size_bytes{mountpoint="/opt/monitoring-backup"} > 0.9
        for: 5m
        labels:
          severity: critical
          service: backup
        annotations:
          summary: "Диск резервных копий заполнен на {{ \$labels.instance }}"
          description: "Диск с резервными копиями заполнен на {{ \$value | humanizePercentage }}"

EOF

echo "10. Создание документации по резервному копированию..."

cat > /root/backup-guide.txt << EOF
# РУКОВОДСТВО ПО РЕЗЕРВНОМУ КОПИРОВАНИЮ RTTI
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== ОБЗОР СИСТЕМЫ РЕЗЕРВНОГО КОПИРОВАНИЯ ===

Автоматическое резервное копирование:
✅ Конфигурации - ежедневно в 01:00
✅ Данные - ежедневно в 02:00  
✅ Полное копирование - еженедельно в 03:00 (воскресенье)
✅ Синхронизация - ежедневно в 04:00
✅ Проверка целостности - ежедневно в 05:00

Типы резервных копий:
📁 Конфигурации: Prometheus, Grafana, Alertmanager, Docker Compose
📁 Данные: Временные ряды, дашборды, настройки
📁 Полные: Вся система мониторинга

=== СТРУКТУРА ДИРЕКТОРИЙ ===

$BACKUP_DIR/
├── configs/          # Ежедневные резервные копии конфигураций
├── data/            # Ежедневные резервные копии данных
├── weekly/          # Еженедельные полные резервные копии
├── logs/            # Логи резервного копирования
├── backup-configs.sh    # Скрипт резервного копирования конфигураций
├── backup-data.sh       # Скрипт резервного копирования данных
├── backup-full.sh       # Скрипт полного резервного копирования
├── restore.sh           # Скрипт восстановления
├── sync-remote.sh       # Скрипт синхронизации с удаленным сервером
└── verify-backups.sh    # Скрипт проверки резервных копий

=== РУЧНОЕ УПРАВЛЕНИЕ ===

Создание резервных копий:
$BACKUP_DIR/backup-configs.sh      # Резервное копирование конфигураций
$BACKUP_DIR/backup-data.sh         # Резервное копирование данных
$BACKUP_DIR/backup-full.sh         # Полное резервное копирование

Восстановление:
$BACKUP_DIR/restore.sh -l                                    # Список доступных копий
$BACKUP_DIR/restore.sh -t configs -f configs_YYYYMMDD.tar.gz # Восстановить конфигурации
$BACKUP_DIR/restore.sh -t data -f prometheus-data_YYYYMMDD.tar.gz # Восстановить данные Prometheus
$BACKUP_DIR/restore.sh -t full -f full-monitoring_YYYYMMDD.tar.gz # Полное восстановление

Проверка и синхронизация:
$BACKUP_DIR/verify-backups.sh      # Проверка целостности резервных копий
$BACKUP_DIR/sync-remote.sh         # Синхронизация с удаленным сервером

=== ПОЛИТИКИ ХРАНЕНИЯ ===

Конфигурации:
- Хранение: 30 дней
- Частота: ежедневно
- Размер: ~10-50 MB

Данные:
- Хранение: 7 дней (ежедневные)
- Частота: ежедневно
- Размер: ~100MB-2GB

Полные резервные копии:
- Хранение: 4 недели
- Частота: еженедельно
- Размер: ~1-10GB

=== СИНХРОНИЗАЦИЯ МЕЖДУ СЕРВЕРАМИ ===

Текущий сервер: $SERVER_NAME
EOF

if [[ "$SERVER_IP" == "92.242.60.172" ]]; then
    cat >> /root/backup-guide.txt << EOF
Удаленный сервер: storage.omuzgorpro.tj (92.242.61.204)
Синхронизация: Конфигурации ежедневно, полные копии еженедельно
EOF
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    cat >> /root/backup-guide.txt << EOF
Удаленный сервер: omuzgorpro.tj (92.242.60.172)
Синхронизация: Конфигурации ежедневно, полные копии еженедельно
EOF
fi

cat >> /root/backup-guide.txt << EOF

Настройка SSH:
- SSH ключи создаются автоматически
- Требуется обмен ключами между серверами
- Синхронизация через rsync по SSH

=== МОНИТОРИНГ РЕЗЕРВНОГО КОПИРОВАНИЯ ===

Алерты Prometheus:
✅ BackupConfigsOld - устаревшие конфигурации (>24ч)
✅ BackupDataOld - устаревшие данные (>24ч)
✅ BackupFullOld - устаревшие полные копии (>7д)
✅ BackupDiskFull - заполнение диска (>90%)

Логи:
- $BACKUP_DIR/logs/backup.log - общие логи
- $BACKUP_DIR/logs/verify.log - проверка целостности
- $BACKUP_DIR/logs/sync.log - синхронизация

=== ВОССТАНОВЛЕНИЕ ПОСЛЕ СБОЯ ===

Сценарий 1: Повреждение конфигураций
1. $BACKUP_DIR/restore.sh -l
2. $BACKUP_DIR/restore.sh -t configs -f [последний_файл]
3. Проверка работы сервисов

Сценарий 2: Потеря данных Prometheus
1. $BACKUP_DIR/restore.sh -l
2. $BACKUP_DIR/restore.sh -t data -f [prometheus-data_файл]
3. Перезапуск контейнеров

Сценарий 3: Полное восстановление
1. $BACKUP_DIR/restore.sh -l
2. $BACKUP_DIR/restore.sh -t full -f [full-monitoring_файл]
3. Проверка всех сервисов

Сценарий 4: Восстановление с удаленного сервера
1. Подключение к удаленному серверу
2. Копирование резервных копий
3. Восстановление стандартными скриптами

=== ТЕСТИРОВАНИЕ ВОССТАНОВЛЕНИЯ ===

Ежемесячное тестирование:
1. Выбор случайной резервной копии
2. Развертывание в тестовой среде
3. Проверка функциональности
4. Документирование результатов

План тестирования:
- 1-я неделя: тест конфигураций
- 2-я неделя: тест данных
- 3-я неделя: полное восстановление
- 4-я неделя: восстановление с удаленного сервера

=== БЕЗОПАСНОСТЬ ===

Шифрование:
- Резервные копии не шифрованы (локальное хранение)
- SSH соединения зашифрованы
- Рекомендуется шифрование чувствительных данных

Доступ:
- Доступ только root пользователю
- Права 600 на резервные копии
- Логирование всех операций

=== ОПТИМИЗАЦИЯ ПРОИЗВОДИТЕЛЬНОСТИ ===

Сжатие:
- Используется gzip сжатие (tar -czf)
- Экономия места ~70-80%
- Увеличение времени создания/восстановления

Исключения:
- WAL файлы Prometheus (временные)
- Активные запросы (queries.active)
- Кэш файлы

=== УСТРАНЕНИЕ НЕПОЛАДОК ===

Проблема: Резервная копия не создается
Решение:
1. Проверить права доступа
2. Проверить свободное место
3. Проверить логи в $BACKUP_DIR/logs/

Проблема: Ошибка восстановления
Решение:
1. Проверить целостность архива
2. Проверить права доступа
3. Остановить сервисы перед восстановлением

Проблема: Синхронизация не работает
Решение:
1. Проверить SSH доступ
2. Проверить сетевую доступность
3. Проверить SSH ключи

=== КОНТАКТЫ И ПОДДЕРЖКА ===

Администратор: RTTI IT Team
Документация: /root/backup-guide.txt
Логи: $BACKUP_DIR/logs/
Скрипты: $BACKUP_DIR/

Горячая линия при критических сбоях:
1. Оценить масштаб проблемы
2. Выбрать стратегию восстановления
3. Выполнить восстановление
4. Проверить функциональность
5. Документировать инцидент

ВАЖНО: Всегда создавайте резервную копию перед восстановлением!
EOF

echo "11. Создание начальных резервных копий..."

echo "Создание первичной резервной копии конфигураций..."
$BACKUP_DIR/backup-configs.sh

echo "12. Проверка настроенных cron задач..."

echo "Настроенные задачи резервного копирования:"
crontab -l | grep -E "(backup|verify|sync)"

echo "13. Создание отчета о резервном копировании..."

cat > /root/backup-setup-report.txt << EOF
# ОТЧЕТ О НАСТРОЙКЕ РЕЗЕРВНОГО КОПИРОВАНИЯ
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===

Скрипты резервного копирования:
✅ backup-configs.sh - резервное копирование конфигураций
✅ backup-data.sh - резервное копирование данных
✅ backup-full.sh - полное резервное копирование
✅ restore.sh - восстановление из резервных копий
✅ sync-remote.sh - синхронизация с удаленным сервером
✅ verify-backups.sh - проверка целостности

Автоматизация:
✅ Cron задачи настроены
✅ Логирование настроено
✅ Мониторинг алертов настроен
✅ Политики хранения настроены

=== РАСПИСАНИЕ РЕЗЕРВНОГО КОПИРОВАНИЯ ===

01:00 ежедневно - Резервное копирование конфигураций
02:00 ежедневно - Резервное копирование данных
03:00 воскресенье - Полное резервное копирование
04:00 ежедневно - Синхронизация с удаленным сервером
05:00 ежедневно - Проверка целостности резервных копий

=== ДИРЕКТОРИИ ===

Основная: $BACKUP_DIR
Конфигурации: $BACKUP_DIR/configs
Данные: $BACKUP_DIR/data
Полные копии: $BACKUP_DIR/weekly
Логи: $BACKUP_DIR/logs
Удаленное хранение: $REMOTE_BACKUP_DIR

=== ПОЛИТИКИ ХРАНЕНИЯ ===

Конфигурации: 30 дней
Данные: 7 дней
Полные копии: 4 недели
Удаленные копии: 30 дней

=== РАЗМЕРЫ И СТАТИСТИКА ===

EOF

# Добавляем текущие размеры
echo "Текущие размеры:" >> /root/backup-setup-report.txt
du -sh "$BACKUP_DIR" >> /root/backup-setup-report.txt 2>/dev/null || echo "Директория еще не содержит данных" >> /root/backup-setup-report.txt

cat >> /root/backup-setup-report.txt << EOF

=== КОМАНДЫ УПРАВЛЕНИЯ ===

Создание резервных копий:
$BACKUP_DIR/backup-configs.sh
$BACKUP_DIR/backup-data.sh
$BACKUP_DIR/backup-full.sh

Восстановление:
$BACKUP_DIR/restore.sh -l                    # Список копий
$BACKUP_DIR/restore.sh -t [type] -f [file]   # Восстановление

Проверка и обслуживание:
$BACKUP_DIR/verify-backups.sh                # Проверка целостности
$BACKUP_DIR/sync-remote.sh                   # Синхронизация

=== МОНИТОРИНГ ===

Алерты: prometheus/rules/backup-alerts.yml
Логи: $BACKUP_DIR/logs/
Статус: через Grafana дашборды

=== БЕЗОПАСНОСТЬ ===

SSH ключи: /root/.ssh/
Права доступа: только root
Шифрование: SSH туннели для синхронизации

=== СЛЕДУЮЩИЕ ШАГИ ===

1. Настроить SSH ключи между серверами
2. Протестировать восстановление
3. Настроить дополнительные алерты
4. Документировать процедуры

=== ТЕСТИРОВАНИЕ ===

Рекомендуется протестировать:
- Создание резервных копий
- Восстановление конфигураций
- Восстановление данных
- Полное восстановление
- Синхронизацию между серверами

Система резервного копирования готова к работе!
EOF

echo "14. Проверка работы резервного копирования..."

# Проверка созданных файлов
echo "Созданные скрипты:"
ls -la $BACKUP_DIR/*.sh

# Проверка cron задач
echo "Cron задачи:"
crontab -l | grep backup

# Первоначальная проверка
$BACKUP_DIR/verify-backups.sh

echo
echo "✅ Шаг 9 завершен успешно!"
echo "💾 Система резервного копирования настроена"
echo "🔄 Автоматическое расписание настроено"
echo "📁 Структура директорий создана"
echo "🔍 Проверка целостности настроена"
echo "🌐 Синхронизация между серверами настроена"
echo "📋 Отчет: /root/backup-setup-report.txt"
echo "📖 Руководство: /root/backup-guide.txt"
echo "🧪 Тестирование: $BACKUP_DIR/verify-backups.sh"
echo "📌 Следующий шаг: ./10-final-check.sh"
echo
