#!/bin/bash

# RTTI Monitoring System Backup Script
# Создание бэкапа конфигураций мониторинга

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                      Monitoring Backup Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./backup-monitoring.sh"
    exit 1
fi

# Переменные
BACKUP_DIR="/var/backups/monitoring"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="monitoring_backup_$DATE"

echo "💾 Создание бэкапа системы мониторинга..."
echo "📅 Дата: $(date)"
echo "📂 Директория бэкапов: $BACKUP_DIR"
echo

# Создание директории бэкапов
mkdir -p $BACKUP_DIR

# Создание рабочей директории для бэкапа
WORK_DIR="$BACKUP_DIR/$BACKUP_NAME"
mkdir -p "$WORK_DIR"

# Функция бэкапа конфигурации
backup_config() {
    local service=$1
    local config_path=$2
    local backup_subdir="$WORK_DIR/$service"
    
    echo "📋 Бэкап конфигурации $service..."
    
    if [ -d "$config_path" ]; then
        mkdir -p "$backup_subdir"
        cp -r "$config_path"/* "$backup_subdir/"
        echo "✅ Конфигурация $service скопирована"
    else
        echo "⚠️  Конфигурация $service не найдена в $config_path"
    fi
}

# Функция бэкапа данных
backup_data() {
    local service=$1
    local data_path=$2
    local backup_subdir="$WORK_DIR/$service-data"
    
    echo "📊 Бэкап данных $service..."
    
    if [ -d "$data_path" ]; then
        mkdir -p "$backup_subdir"
        
        # Для Prometheus данных создаем snapshot
        if [ "$service" = "prometheus" ] && [ -d "$data_path" ]; then
            echo "📸 Создание snapshot Prometheus..."
            curl -XPOST http://localhost:9090/api/v1/admin/tsdb/snapshot
            
            # Копирование последнего snapshot
            LATEST_SNAPSHOT=$(ls -t "$data_path/snapshots/" 2>/dev/null | head -1)
            if [ ! -z "$LATEST_SNAPSHOT" ]; then
                cp -r "$data_path/snapshots/$LATEST_SNAPSHOT" "$backup_subdir/snapshot"
                echo "✅ Prometheus snapshot создан"
            fi
        else
            # Обычное копирование для других сервисов
            tar -czf "$backup_subdir.tar.gz" -C "$(dirname $data_path)" "$(basename $data_path)"
            echo "✅ Данные $service заархивированы"
        fi
    else
        echo "⚠️  Данные $service не найдены в $data_path"
    fi
}

# Остановка сервисов для консистентного бэкапа
echo "⏸️  Временная остановка сервисов для консистентного бэкапа..."

SERVICES_TO_STOP=()
if systemctl is-active --quiet prometheus; then
    SERVICES_TO_STOP+=("prometheus")
fi
if systemctl is-active --quiet alertmanager; then
    SERVICES_TO_STOP+=("alertmanager")
fi

for service in "${SERVICES_TO_STOP[@]}"; do
    systemctl stop "$service"
    echo "⏸️  $service остановлен"
done

# Бэкап конфигураций
echo "📋 Создание бэкапа конфигураций..."

# Prometheus
backup_config "prometheus" "/etc/prometheus"

# Grafana
backup_config "grafana" "/etc/grafana"

# Alertmanager
backup_config "alertmanager" "/etc/alertmanager"

# Бэкап данных
echo "📊 Создание бэкапа данных..."

# Prometheus данные
backup_data "prometheus" "/var/lib/prometheus"

# Grafana данные (дашборды, пользователи, настройки)
backup_data "grafana" "/var/lib/grafana"

# Alertmanager данные
backup_data "alertmanager" "/var/lib/alertmanager"

# Запуск сервисов обратно
echo "▶️  Запуск сервисов..."
for service in "${SERVICES_TO_STOP[@]}"; do
    systemctl start "$service"
    echo "▶️  $service запущен"
done

# Бэкап пользовательских скриптов и дашбордов
echo "📜 Бэкап пользовательских скриптов..."

# Скрипты мониторинга
if [ -d "/opt/monitoring-scripts" ]; then
    cp -r "/opt/monitoring-scripts" "$WORK_DIR/"
    echo "✅ Пользовательские скрипты скопированы"
fi

# Экспорт дашбордов Grafana через API
echo "📊 Экспорт дашбордов Grafana..."
GRAFANA_DASHBOARDS_DIR="$WORK_DIR/grafana-dashboards"
mkdir -p "$GRAFANA_DASHBOARDS_DIR"

# Получение списка дашбордов
if systemctl is-active --quiet grafana-server; then
    sleep 5  # Ждем запуска Grafana
    
    # Экспорт через API (требует настройки API ключа)
    GRAFANA_URL="http://localhost:3000"
    GRAFANA_API_KEY=$(grep "admin_password" /etc/grafana/grafana.ini | cut -d'=' -f2 | xargs || echo "admin")
    
    # Попытка получить дашборды
    curl -s -H "Authorization: Bearer admin:$GRAFANA_API_KEY" \
         "$GRAFANA_URL/api/search?type=dash-db" > "$GRAFANA_DASHBOARDS_DIR/dashboards_list.json" 2>/dev/null || true
    
    echo "📊 Список дашбордов экспортирован"
fi

# Создание информационного файла
echo "📋 Создание информационного файла..."
cat > "$WORK_DIR/backup_info.txt" << EOF
Monitoring System Backup Information
===================================
Date: $(date)
Server: $(hostname)
IP: $(hostname -I | awk '{print $1}')

Backed up components:
EOF

# Добавление информации о компонентах
for service in prometheus grafana alertmanager; do
    if systemctl is-active --quiet "$service" || systemctl is-active --quiet "${service}-server"; then
        VERSION=$($service --version 2>/dev/null | head -1 || echo "Unknown version")
        echo "- $service: $VERSION" >> "$WORK_DIR/backup_info.txt"
    fi
done

cat >> "$WORK_DIR/backup_info.txt" << EOF

Directories backed up:
- /etc/prometheus/          -> prometheus/
- /etc/grafana/            -> grafana/
- /etc/alertmanager/       -> alertmanager/
- /var/lib/prometheus/     -> prometheus-data.tar.gz
- /var/lib/grafana/        -> grafana-data.tar.gz
- /var/lib/alertmanager/   -> alertmanager-data.tar.gz

Files:
- backup_info.txt          -> This file
- grafana-dashboards/      -> Exported dashboards

Restore command:
sudo ./restore-monitoring.sh $BACKUP_NAME
EOF

# Создание архива
echo "📦 Создание финального архива..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"

# Установка прав доступа
chown -R root:root "$BACKUP_DIR"
chmod 600 "${BACKUP_NAME}.tar.gz"

# Удаление рабочей директории
rm -rf "$WORK_DIR"

# Размер бэкапа
BACKUP_SIZE=$(ls -lh "${BACKUP_NAME}.tar.gz" | awk '{print $5}')
echo "📊 Размер бэкапа: $BACKUP_SIZE"

# Очистка старых бэкапов (старше 30 дней)
echo "🧹 Очистка старых бэкапов..."
find "$BACKUP_DIR" -name "monitoring_backup_*.tar.gz" -mtime +30 -delete

# Список бэкапов
echo "📂 Доступные бэкапы:"
ls -lt "$BACKUP_DIR"/monitoring_backup_*.tar.gz | head -5

echo
echo "🎉 Бэкап системы мониторинга создан успешно!"
echo "📂 Файл бэкапа: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo "📊 Размер: $BACKUP_SIZE"
echo
echo "🔄 Для восстановления используйте:"
echo "   sudo ./restore-monitoring.sh $BACKUP_NAME"
echo
echo "📋 Содержимое бэкапа:"
echo "   • Конфигурации Prometheus, Grafana, Alertmanager"
echo "   • Данные временных рядов Prometheus"
echo "   • Дашборды и настройки Grafana"
echo "   • Правила алертов и уведомления"
echo "   • Пользовательские скрипты"
