#!/bin/bash
# Установка полного стека мониторинга Prometheus + Grafana + Node Exporter + AlertManager
# Для мониторинга Moodle 5.0.2 + Drupal 11 инфраструктуры RTTI

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Конфигурация
PROMETHEUS_VERSION="2.47.2"
GRAFANA_VERSION="10.2.0"
ALERTMANAGER_VERSION="0.25.0"
NODE_EXPORTER_VERSION="1.6.1"
NGINX_EXPORTER_VERSION="0.11.0"
POSTGRES_EXPORTER_VERSION="0.12.1"

# Серверы RTTI LMS
LMS_SERVER="92.242.60.172"        # lms.rtti.tj (Moodle + мониторинг)
LIBRARY_SERVER="92.242.61.204"    # library.rtti.tj (Drupal)
LMS_DOMAIN="lms.rtti.tj"
LIBRARY_DOMAIN="library.rtti.tj"

MONITORING_USER="monitoring"
PROMETHEUS_DIR="/opt/prometheus"
GRAFANA_DIR="/opt/grafana"
ALERTMANAGER_DIR="/opt/alertmanager"
NODE_EXPORTER_DIR="/opt/node_exporter"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен запускаться с правами root"
   exit 1
fi

info "🚀 Начинаем установку стека мониторинга Prometheus + Grafana для RTTI LMS"

# Создание пользователя для мониторинга
create_monitoring_user() {
    log "Создание пользователя для мониторинга..."
    
    if ! id -u $MONITORING_USER > /dev/null 2>&1; then
        useradd --no-create-home --shell /bin/false $MONITORING_USER
        log "Пользователь $MONITORING_USER создан"
    else
        warning "Пользователь $MONITORING_USER уже существует"
    fi
}

# Установка зависимостей
install_dependencies() {
    log "Установка зависимостей..."
    
    apt update
    apt install -y \
        wget \
        curl \
        tar \
        adduser \
        libfontconfig1 \
        ca-certificates \
        software-properties-common \
        apt-transport-https \
        gnupg \
        lsb-release
}

# Установка Node Exporter
install_node_exporter() {
    log "Установка Node Exporter $NODE_EXPORTER_VERSION..."
    
    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    
    mkdir -p $NODE_EXPORTER_DIR
    cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter $NODE_EXPORTER_DIR/
    chown -R $MONITORING_USER:$MONITORING_USER $NODE_EXPORTER_DIR
    
    # Создание systemd сервиса
    cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$MONITORING_USER
Group=$MONITORING_USER
Type=simple
ExecStart=$NODE_EXPORTER_DIR/node_exporter \\
    --web.listen-address=:9100 \\
    --collector.systemd \\
    --collector.processes \\
    --collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    
    log "Node Exporter установлен и запущен на порту 9100"
}

# Установка Prometheus
install_prometheus() {
    log "Установка Prometheus $PROMETHEUS_VERSION..."
    
    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    
    mkdir -p $PROMETHEUS_DIR/{bin,data,config}
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus $PROMETHEUS_DIR/bin/
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool $PROMETHEUS_DIR/bin/
    
    chown -R $MONITORING_USER:$MONITORING_USER $PROMETHEUS_DIR
    
    # Конфигурация Prometheus
    cat > $PROMETHEUS_DIR/config/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/opt/prometheus/config/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 5s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 5s

  - job_name: 'nginx-exporter'
    static_configs:
      - targets: ['localhost:9113']
    scrape_interval: 10s

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['localhost:9187']
    scrape_interval: 10s

  - job_name: 'moodle-health'
    static_configs:
      - targets: ['localhost:80']
    metrics_path: '/admin/tool/monitor/health.php'
    scrape_interval: 30s
    scheme: 'http'

  - job_name: 'drupal-health'
    static_configs:
      - targets: ['localhost:80']
    metrics_path: '/admin/reports/status'
    scrape_interval: 30s
    scheme: 'http'
EOF

    # Создание директории для правил алертов
    mkdir -p $PROMETHEUS_DIR/config/rules
    
    # Создание systemd сервиса
    cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=$MONITORING_USER
Group=$MONITORING_USER
Type=simple
ExecStart=$PROMETHEUS_DIR/bin/prometheus \\
    --config.file=$PROMETHEUS_DIR/config/prometheus.yml \\
    --storage.tsdb.path=$PROMETHEUS_DIR/data \\
    --web.console.templates=$PROMETHEUS_DIR/consoles \\
    --web.console.libraries=$PROMETHEUS_DIR/console_libraries \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle \\
    --storage.tsdb.retention.time=30d

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
    
    log "Prometheus установлен и запущен на порту 9090"
}

# Установка AlertManager
install_alertmanager() {
    log "Установка AlertManager $ALERTMANAGER_VERSION..."
    
    cd /tmp
    wget https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
    tar xvf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
    
    mkdir -p $ALERTMANAGER_DIR/{bin,data,config}
    cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/alertmanager $ALERTMANAGER_DIR/bin/
    cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/amtool $ALERTMANAGER_DIR/bin/
    
    chown -R $MONITORING_USER:$MONITORING_USER $ALERTMANAGER_DIR
    
    # Конфигурация AlertManager
    cat > $ALERTMANAGER_DIR/config/alertmanager.yml << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@rtti.tj'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@rtti.tj'
    subject: "RTTI LMS Alert: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      Instance: {{ .Labels.instance }}
      Severity: {{ .Labels.severity }}
      {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

    # Создание systemd сервиса
    cat > /etc/systemd/system/alertmanager.service << EOF
[Unit]
Description=AlertManager
Wants=network-online.target
After=network-online.target

[Service]
User=$MONITORING_USER
Group=$MONITORING_USER
Type=simple
ExecStart=$ALERTMANAGER_DIR/bin/alertmanager \\
    --config.file=$ALERTMANAGER_DIR/config/alertmanager.yml \\
    --storage.path=$ALERTMANAGER_DIR/data \\
    --web.listen-address=0.0.0.0:9093

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable alertmanager
    systemctl start alertmanager
    
    log "AlertManager установлен и запущен на порту 9093"
}

# Установка Grafana
install_grafana() {
    log "Установка Grafana..."
    
    # Добавление репозитория Grafana
    wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
    add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
    
    apt update
    apt install -y grafana
    
    # Настройка Grafana
    cat > /etc/grafana/grafana.ini << EOF
[server]
http_port = 3000
domain = localhost

[security]
admin_user = admin
admin_password = rtti_admin_2025

[database]
type = sqlite3
path = grafana.db

[session]
provider = file

[analytics]
reporting_enabled = false
check_for_updates = false

[log]
mode = file
level = info
EOF

    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server
    
    log "Grafana установлена и запущена на порту 3000"
    info "Логин: admin, Пароль: rtti_admin_2025"
}

# Установка дополнительных экспортеров
install_additional_exporters() {
    log "Установка дополнительных экспортеров..."
    
    # Nginx Prometheus Exporter
    cd /tmp
    wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v${NGINX_EXPORTER_VERSION}/nginx-prometheus-exporter_${NGINX_EXPORTER_VERSION}_linux_amd64.tar.gz
    tar xvf nginx-prometheus-exporter_${NGINX_EXPORTER_VERSION}_linux_amd64.tar.gz
    
    mkdir -p /opt/nginx_exporter
    cp nginx-prometheus-exporter /opt/nginx_exporter/
    chown -R $MONITORING_USER:$MONITORING_USER /opt/nginx_exporter
    
    # Systemd сервис для nginx exporter
    cat > /etc/systemd/system/nginx_exporter.service << EOF
[Unit]
Description=Nginx Prometheus Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$MONITORING_USER
Group=$MONITORING_USER
Type=simple
ExecStart=/opt/nginx_exporter/nginx-prometheus-exporter \\
    -nginx.scrape-uri=http://localhost/nginx_status

[Install]
WantedBy=multi-user.target
EOF

    # Postgres Exporter
    cd /tmp
    wget https://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz
    tar xvf postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz
    
    mkdir -p /opt/postgres_exporter
    cp postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64/postgres_exporter /opt/postgres_exporter/
    chown -R $MONITORING_USER:$MONITORING_USER /opt/postgres_exporter
    
    # Создание пользователя для мониторинга PostgreSQL
    sudo -u postgres psql -c "CREATE USER monitoring WITH PASSWORD 'monitoring_password_2025';"
    sudo -u postgres psql -c "GRANT SELECT ON pg_stat_database TO monitoring;"
    sudo -u postgres psql -c "GRANT SELECT ON pg_stat_replication TO monitoring;"
    
    # Environment файл для postgres exporter
    cat > /etc/default/postgres_exporter << EOF
DATA_SOURCE_NAME="postgresql://monitoring:monitoring_password_2025@localhost:5432/postgres?sslmode=disable"
EOF

    # Systemd сервис для postgres exporter
    cat > /etc/systemd/system/postgres_exporter.service << EOF
[Unit]
Description=PostgreSQL Prometheus Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$MONITORING_USER
Group=$MONITORING_USER
Type=simple
EnvironmentFile=/etc/default/postgres_exporter
ExecStart=/opt/postgres_exporter/postgres_exporter \\
    --web.listen-address=:9187

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nginx_exporter postgres_exporter
    systemctl start nginx_exporter postgres_exporter
    
    log "Дополнительные экспортеры установлены"
}

# Создание правил алертов
create_alert_rules() {
    log "Создание правил алертов..."
    
    cat > $PROMETHEUS_DIR/config/rules/lms_alerts.yml << EOF
groups:
- name: lms.rules
  rules:
  - alert: InstanceDown
    expr: up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Instance {{ \$labels.instance }} down"
      description: "{{ \$labels.instance }} has been down for more than 5 minutes."

  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ \$labels.instance }}"
      description: "CPU usage is above 80% for more than 10 minutes."

  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ \$labels.instance }}"
      description: "Memory usage is above 85% for more than 10 minutes."

  - alert: DiskSpaceLow
    expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Low disk space on {{ \$labels.instance }}"
      description: "Less than 10% disk space remaining."

  - alert: NginxDown
    expr: nginx_up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Nginx is down on {{ \$labels.instance }}"
      description: "Nginx has been down for more than 5 minutes."

  - alert: PostgreSQLDown
    expr: pg_up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "PostgreSQL is down on {{ \$labels.instance }}"
      description: "PostgreSQL has been down for more than 5 minutes."

  - alert: MoodleResponseTime
    expr: probe_duration_seconds{job="moodle-health"} > 5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Moodle slow response time"
      description: "Moodle response time is above 5 seconds."

  - alert: DrupalResponseTime
    expr: probe_duration_seconds{job="drupal-health"} > 5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Drupal slow response time"
      description: "Drupal response time is above 5 seconds."
EOF

    chown -R $MONITORING_USER:$MONITORING_USER $PROMETHEUS_DIR/config/rules/
    
    # Перезагрузка конфигурации Prometheus
    curl -X POST http://localhost:9090/-/reload || warning "Не удалось перезагрузить конфигурацию Prometheus"
    
    log "Правила алертов созданы"
}

# Настройка Nginx для статуса
configure_nginx_status() {
    log "Настройка статуса Nginx для мониторинга..."
    
    cat > /etc/nginx/sites-available/monitoring << EOF
server {
    listen 80;
    server_name monitoring.rtti.tj;
    
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow ::1;
        deny all;
    }
    
    location /prometheus/ {
        proxy_pass http://localhost:9090/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /grafana/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /alertmanager/ {
        proxy_pass http://localhost:9093/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/monitoring /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    log "Nginx настроен для мониторинга"
}

# Импорт дашбордов Grafana
import_grafana_dashboards() {
    log "Импорт дашбордов Grafana..."
    
    # Ожидание запуска Grafana
    sleep 30
    
    # Добавление Prometheus как источника данных
    curl -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://localhost:9090",
            "access": "proxy",
            "isDefault": true
        }' \
        http://admin:rtti_admin_2025@localhost:3000/api/datasources
    
    log "Источник данных Prometheus добавлен в Grafana"
    info "Рекомендуется импортировать готовые дашборды:"
    info "- Node Exporter Full: ID 1860"
    info "- Nginx: ID 12708"
    info "- PostgreSQL: ID 9628"
}

# Создание отчета об установке
create_installation_report() {
    log "Создание отчета об установке..."
    
    cat > /root/monitoring-installation-report.txt << EOF
=== PROMETHEUS MONITORING STACK INSTALLATION REPORT ===
Дата установки: $(date)
Сервер: $(hostname -f)

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===
✅ Prometheus $PROMETHEUS_VERSION - порт 9090
✅ Grafana $GRAFANA_VERSION - порт 3000
✅ AlertManager $ALERTMANAGER_VERSION - порт 9093
✅ Node Exporter $NODE_EXPORTER_VERSION - порт 9100
✅ Nginx Exporter $NGINX_EXPORTER_VERSION - порт 9113
✅ PostgreSQL Exporter $POSTGRES_EXPORTER_VERSION - порт 9187

=== ДОСТУП К ИНТЕРФЕЙСАМ ===
🌐 Prometheus: http://$(hostname -I | awk '{print $1}'):9090
🌐 Grafana: http://$(hostname -I | awk '{print $1}'):3000
   Логин: admin / Пароль: rtti_admin_2025
🌐 AlertManager: http://$(hostname -I | awk '{print $1}'):9093

=== ЧЕРЕЗ NGINX ПРОКСИ ===
🌐 Prometheus: http://monitoring.rtti.tj/prometheus/
🌐 Grafana: http://monitoring.rtti.tj/grafana/
🌐 AlertManager: http://monitoring.rtti.tj/alertmanager/

=== ФАЙЛЫ КОНФИГУРАЦИИ ===
📁 Prometheus: $PROMETHEUS_DIR/config/prometheus.yml
📁 AlertManager: $ALERTMANAGER_DIR/config/alertmanager.yml
📁 Grafana: /etc/grafana/grafana.ini
📁 Правила алертов: $PROMETHEUS_DIR/config/rules/lms_alerts.yml

=== СИСТЕМНЫЕ СЕРВИСЫ ===
🔧 prometheus.service
🔧 grafana-server.service
🔧 alertmanager.service
🔧 node_exporter.service
🔧 nginx_exporter.service
🔧 postgres_exporter.service

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Настройте email уведомления в AlertManager
2. Импортируйте дашборды в Grafana
3. Добавьте мониторинг других серверов
4. Настройте SSL сертификаты для веб-интерфейсов

=== ПОЛЕЗНЫЕ КОМАНДЫ ===
# Проверка статуса всех сервисов мониторинга
systemctl status prometheus grafana-server alertmanager node_exporter

# Просмотр логов
journalctl -u prometheus -f
journalctl -u grafana-server -f

# Перезагрузка конфигурации Prometheus
curl -X POST http://localhost:9090/-/reload

# Проверка правил алертов
/opt/prometheus/bin/promtool check rules $PROMETHEUS_DIR/config/rules/*.yml
EOF

    log "Отчет об установке создан: /root/monitoring-installation-report.txt"
}

# Основная функция установки
main() {
    log "🚀 Начинаем установку полного стека мониторинга для RTTI LMS"
    
    create_monitoring_user
    install_dependencies
    install_node_exporter
    install_prometheus
    install_alertmanager
    install_grafana
    install_additional_exporters
    create_alert_rules
    configure_nginx_status
    import_grafana_dashboards
    create_installation_report
    
    log "✅ Установка стека мониторинга завершена успешно!"
    
    echo ""
    info "🌐 Веб-интерфейсы доступны по адресам:"
    info "   Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
    info "   Grafana: http://$(hostname -I | awk '{print $1}'):3000 (admin/rtti_admin_2025)"
    info "   AlertManager: http://$(hostname -I | awk '{print $1}'):9093"
    echo ""
    info "📋 Полный отчет: /root/monitoring-installation-report.txt"
    echo ""
    warning "🔧 Не забудьте:"
    warning "   1. Настроить email уведомления в AlertManager"
    warning "   2. Импортировать дашборды в Grafana"
    warning "   3. Добавить домен monitoring.rtti.tj в DNS"
    warning "   4. Настроить SSL сертификаты"
}

# Запуск
main "$@"
