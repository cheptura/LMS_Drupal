#!/bin/bash

# RTTI Monitoring - Шаг 2: Установка Docker и Prometheus
# Серверы: lms.rtti.tj (92.242.60.172), library.rtti.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 2: Docker и Prometheus ==="
echo "🐳 Установка контейнерной платформы и системы мониторинга"
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
    SERVER_NAME="lms.rtti.tj"
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    SERVER_ROLE="drupal"
    SERVER_NAME="library.rtti.tj"
else
    echo "⚠️ IP адрес не распознан, используется режим standalone"
    SERVER_ROLE="standalone"
    SERVER_NAME=$(hostname -f)
fi

MONITORING_DIR="/opt/monitoring"
PROMETHEUS_DIR="$MONITORING_DIR/prometheus"
DOCKER_COMPOSE_DIR="$MONITORING_DIR/docker"

echo "🔍 Обнаружена роль сервера: $SERVER_ROLE ($SERVER_NAME)"

echo "1. Обновление системы..."
apt update && apt upgrade -y

echo "2. Установка зависимостей..."
apt install -y curl wget gnupg lsb-release apt-transport-https ca-certificates

echo "3. Установка Docker..."

# Добавление официального GPG ключа Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Добавление репозитория Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Запуск и включение Docker
systemctl start docker
systemctl enable docker

# Добавление пользователя в группу docker
usermod -aG docker $SUDO_USER 2>/dev/null || true

echo "4. Установка Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "5. Создание структуры директорий..."
mkdir -p $MONITORING_DIR/{prometheus,grafana,alertmanager,exporters,data,logs}
mkdir -p $PROMETHEUS_DIR/{config,data,rules}
mkdir -p $DOCKER_COMPOSE_DIR

echo "6. Настройка Prometheus..."

# Конфигурация Prometheus
cat > $PROMETHEUS_DIR/config/prometheus.yml << EOF
# Конфигурация Prometheus для RTTI мониторинга
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)

global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'rtti'
    environment: 'production'
    datacenter: 'main'

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus мониторинг самого себя
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s
    metrics_path: /metrics

  # Node Exporter для системных метрик
  - job_name: 'node-exporter'
    static_configs:
      - targets: 
          - 'node-exporter:9100'
    scrape_interval: 15s
    metrics_path: /metrics
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: '$SERVER_NAME'

  # Nginx Exporter для веб-сервера
  - job_name: 'nginx-exporter'
    static_configs:
      - targets: ['nginx-exporter:9113']
    scrape_interval: 30s
    metrics_path: /metrics

  # PostgreSQL Exporter для базы данных
  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']
    scrape_interval: 30s
    metrics_path: /metrics

  # Redis Exporter для кэша
  - job_name: 'redis-exporter'
    static_configs:
      - targets: ['redis-exporter:9121']
    scrape_interval: 30s
    metrics_path: /metrics

  # Blackbox Exporter для внешних проверок
  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://$SERVER_NAME
          - https://$SERVER_NAME/user/login
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  # SSL сертификаты
  - job_name: 'blackbox-ssl'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
          - $SERVER_NAME:443
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

EOF

# Дополнительные targets в зависимости от роли сервера
if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> $PROMETHEUS_DIR/config/prometheus.yml << EOF
  # Мониторинг Drupal сервера (удаленно)
  - job_name: 'drupal-server'
    static_configs:
      - targets: 
          - '92.242.61.204:9100'
    scrape_interval: 30s
    metrics_path: /metrics
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'library.rtti.tj'

  # Проверка доступности Drupal
  - job_name: 'drupal-health'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://library.rtti.tj
          - https://library.rtti.tj/admin
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> $PROMETHEUS_DIR/config/prometheus.yml << EOF
  # Мониторинг Moodle сервера (удаленно)
  - job_name: 'moodle-server'
    static_configs:
      - targets: 
          - '92.242.60.172:9100'
    scrape_interval: 30s
    metrics_path: /metrics
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'lms.rtti.tj'

  # Проверка доступности Moodle
  - job_name: 'moodle-health'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://lms.rtti.tj
          - https://lms.rtti.tj/login
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

EOF
fi

echo "7. Создание правил алертинга..."

# Основные правила алертов
cat > $PROMETHEUS_DIR/rules/alerts.yml << EOF
# Правила алертов для RTTI мониторинга
# Дата: $(date)

groups:
  - name: system.rules
    rules:
      # Высокая загрузка CPU
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Высокая загрузка CPU на {{ \$labels.instance }}"
          description: "CPU загружен на {{ \$value }}% более 5 минут"

      # Критическая загрузка CPU
      - alert: CriticalCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 95
        for: 2m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "КРИТИЧЕСКАЯ загрузка CPU на {{ \$labels.instance }}"
          description: "CPU загружен на {{ \$value }}% более 2 минут"

      # Мало свободной памяти
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Высокое использование памяти на {{ \$labels.instance }}"
          description: "Память использована на {{ \$value }}%"

      # Критически мало памяти
      - alert: CriticalMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 95
        for: 2m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "КРИТИЧЕСКОЕ использование памяти на {{ \$labels.instance }}"
          description: "Память использована на {{ \$value }}%"

      # Мало места на диске
      - alert: HighDiskUsage
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Высокое использование диска на {{ \$labels.instance }}"
          description: "Диск {{ \$labels.mountpoint }} заполнен на {{ \$value }}%"

      # Критически мало места на диске
      - alert: CriticalDiskUsage
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 95
        for: 2m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "КРИТИЧЕСКОЕ использование диска на {{ \$labels.instance }}"
          description: "Диск {{ \$labels.mountpoint }} заполнен на {{ \$value }}%"

      # Высокая загрузка системы
      - alert: HighLoadAverage
        expr: node_load1 > 4
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Высокая загрузка системы на {{ \$labels.instance }}"
          description: "Load average: {{ \$value }}"

  - name: web.rules
    rules:
      # Сайт недоступен
      - alert: WebsiteDown
        expr: probe_success == 0
        for: 1m
        labels:
          severity: critical
          service: web
        annotations:
          summary: "Сайт {{ \$labels.instance }} недоступен"
          description: "Сайт не отвечает более 1 минуты"

      # Медленный ответ сайта
      - alert: SlowWebsite
        expr: probe_duration_seconds > 3
        for: 5m
        labels:
          severity: warning
          service: web
        annotations:
          summary: "Медленный ответ сайта {{ \$labels.instance }}"
          description: "Время ответа: {{ \$value }}s"

      # SSL сертификат истекает
      - alert: SSLCertExpiringSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
        for: 1h
        labels:
          severity: warning
          service: ssl
        annotations:
          summary: "SSL сертификат {{ \$labels.instance }} истекает скоро"
          description: "Сертификат истекает через {{ \$value | humanizeDuration }}"

      # Nginx недоступен
      - alert: NginxDown
        expr: up{job="nginx-exporter"} == 0
        for: 1m
        labels:
          severity: critical
          service: nginx
        annotations:
          summary: "Nginx недоступен на {{ \$labels.instance }}"
          description: "Nginx не отвечает более 1 минуты"

  - name: database.rules
    rules:
      # PostgreSQL недоступен
      - alert: PostgreSQLDown
        expr: up{job="postgres-exporter"} == 0
        for: 1m
        labels:
          severity: critical
          service: postgresql
        annotations:
          summary: "PostgreSQL недоступен на {{ \$labels.instance }}"
          description: "PostgreSQL не отвечает более 1 минуты"

      # Много активных подключений
      - alert: PostgreSQLTooManyConnections
        expr: pg_stat_activity_count > 100
        for: 5m
        labels:
          severity: warning
          service: postgresql
        annotations:
          summary: "Много подключений к PostgreSQL на {{ \$labels.instance }}"
          description: "Активных подключений: {{ \$value }}"

  - name: cache.rules
    rules:
      # Redis недоступен
      - alert: RedisDown
        expr: up{job="redis-exporter"} == 0
        for: 1m
        labels:
          severity: critical
          service: redis
        annotations:
          summary: "Redis недоступен на {{ \$labels.instance }}"
          description: "Redis не отвечает более 1 минуты"

      # Высокое использование памяти Redis
      - alert: RedisHighMemoryUsage
        expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
          service: redis
        annotations:
          summary: "Высокое использование памяти Redis на {{ \$labels.instance }}"
          description: "Память Redis использована на {{ \$value }}%"
EOF

echo "8. Создание Docker Compose конфигурации..."

cat > $DOCKER_COMPOSE_DIR/docker-compose.yml << EOF
# Docker Compose для RTTI мониторинга
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_ROLE)

version: '3.8'

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:

services:
  # Prometheus - основная система мониторинга
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - $PROMETHEUS_DIR/config:/etc/prometheus
      - $PROMETHEUS_DIR/data:/prometheus
      - $PROMETHEUS_DIR/rules:/etc/prometheus/rules
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=90d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
      - '--storage.tsdb.wal-compression'
    networks:
      - monitoring
    depends_on:
      - node-exporter

  # Node Exporter - системные метрики
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
      - /etc/hostname:/etc/nodename:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
      - '--collector.textfile.directory=/var/lib/node_exporter/textfile_collector'
    networks:
      - monitoring

  # Nginx Exporter - метрики веб-сервера
  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: nginx-exporter
    restart: unless-stopped
    ports:
      - "9113:9113"
    environment:
      - SCRAPE_URI=http://host.docker.internal:8080/nginx_status
      - TELEMETRY_PATH=/metrics
      - NGINX_RETRIES=10
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

  # PostgreSQL Exporter - метрики базы данных
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: postgres-exporter
    restart: unless-stopped
    ports:
      - "9187:9187"
    environment:
      - DATA_SOURCE_NAME=postgresql://monitoring_user:monitoring_password@host.docker.internal:5432/postgres?sslmode=disable
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

  # Redis Exporter - метрики кэша
  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: redis-exporter
    restart: unless-stopped
    ports:
      - "9121:9121"
    environment:
      - REDIS_ADDR=redis://host.docker.internal:6379
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

  # Blackbox Exporter - внешние проверки
  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox-exporter
    restart: unless-stopped
    ports:
      - "9115:9115"
    volumes:
      - $MONITORING_DIR/blackbox:/etc/blackbox_exporter
    networks:
      - monitoring

  # cAdvisor - метрики контейнеров
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    networks:
      - monitoring
EOF

echo "9. Настройка Blackbox Exporter..."

mkdir -p $MONITORING_DIR/blackbox
cat > $MONITORING_DIR/blackbox/config.yml << EOF
# Конфигурация Blackbox Exporter
# Дата: $(date)

modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      method: GET
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200]
      follow_redirects: true
      preferred_ip_protocol: "ip4"

  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST
      valid_status_codes: [200]

  tcp_connect:
    prober: tcp
    timeout: 5s

  pop3s_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - expect: "^+OK"
      tls: true
      tls_config:
        insecure_skip_verify: false

  ssh_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - expect: "^SSH-2.0-"

  irc_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - send: "NICK prober"
        - send: "USER prober prober prober :prober"
        - expect: "PING :([^ ]+)"
          send: "PONG :\${1}"
        - expect: "^:[^ ]+ 001"
EOF

echo "10. Создание пользователя мониторинга для PostgreSQL..."

# Создание пользователя для мониторинга PostgreSQL
sudo -u postgres psql << EOF
CREATE USER monitoring_user WITH PASSWORD 'monitoring_password';
GRANT CONNECT ON DATABASE postgres TO monitoring_user;
GRANT pg_monitor TO monitoring_user;
EOF

echo "11. Настройка Nginx для метрик..."

# Добавление location для статистики Nginx
if [ -f "/etc/nginx/sites-available/default" ] || [ -f "/etc/nginx/sites-available/moodle" ] || [ -f "/etc/nginx/sites-available/drupal" ]; then
    # Создание конфигурации для метрик
    cat > /etc/nginx/conf.d/monitoring.conf << EOF
# Конфигурация мониторинга для Nginx
# Дата: $(date)

server {
    listen 8080;
    server_name localhost;
    
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow ::1;
        allow 172.16.0.0/12; # Docker networks
        deny all;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Перезапуск Nginx
    systemctl reload nginx
fi

echo "12. Настройка файрвола для мониторинга..."

# Открытие портов для мониторинга (только локально)
ufw allow from 127.0.0.1 to any port 9090 comment "Prometheus"
ufw allow from 127.0.0.1 to any port 9100 comment "Node Exporter"
ufw allow from 127.0.0.1 to any port 9113 comment "Nginx Exporter"
ufw allow from 127.0.0.1 to any port 9187 comment "PostgreSQL Exporter"
ufw allow from 127.0.0.1 to any port 9121 comment "Redis Exporter"
ufw allow from 127.0.0.1 to any port 9115 comment "Blackbox Exporter"

# Если это Moodle сервер, открываем доступ для Drupal
if [ "$SERVER_ROLE" == "moodle" ]; then
    ufw allow from 92.242.61.204 to any port 9100 comment "Node Exporter from Drupal"
fi

# Если это Drupal сервер, открываем доступ для Moodle
if [ "$SERVER_ROLE" == "drupal" ]; then
    ufw allow from 92.242.60.172 to any port 9100 comment "Node Exporter from Moodle"
fi

echo "13. Создание systemd сервиса для мониторинга..."

cat > /etc/systemd/system/rtti-monitoring.service << EOF
[Unit]
Description=RTTI Monitoring Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DOCKER_COMPOSE_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable rtti-monitoring

echo "14. Создание скрипта управления мониторингом..."

cat > /root/monitoring-control.sh << 'EOF'
#!/bin/bash
# Управление системой мониторинга RTTI

DOCKER_COMPOSE_DIR="/opt/monitoring/docker"
MONITORING_DIR="/opt/monitoring"

case "$1" in
    start)
        echo "Запуск системы мониторинга..."
        cd $DOCKER_COMPOSE_DIR
        docker-compose up -d
        echo "✅ Система мониторинга запущена"
        ;;
    stop)
        echo "Остановка системы мониторинга..."
        cd $DOCKER_COMPOSE_DIR
        docker-compose down
        echo "✅ Система мониторинга остановлена"
        ;;
    restart)
        echo "Перезапуск системы мониторинга..."
        cd $DOCKER_COMPOSE_DIR
        docker-compose restart
        echo "✅ Система мониторинга перезапущена"
        ;;
    status)
        echo "=== Статус мониторинга ==="
        cd $DOCKER_COMPOSE_DIR
        docker-compose ps
        echo
        echo "=== Использование ресурсов ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        ;;
    logs)
        if [ -z "$2" ]; then
            echo "Использование: $0 logs [prometheus|grafana|alertmanager|node-exporter]"
            exit 1
        fi
        cd $DOCKER_COMPOSE_DIR
        docker-compose logs -f $2
        ;;
    update)
        echo "Обновление образов мониторинга..."
        cd $DOCKER_COMPOSE_DIR
        docker-compose pull
        docker-compose up -d
        echo "✅ Образы обновлены"
        ;;
    backup)
        BACKUP_DIR="/var/backups/monitoring/$(date +%Y%m%d-%H%M%S)"
        mkdir -p $BACKUP_DIR
        echo "Создание резервной копии..."
        cp -r $MONITORING_DIR/prometheus/config $BACKUP_DIR/
        cp -r $MONITORING_DIR/grafana $BACKUP_DIR/ 2>/dev/null || true
        tar -czf $BACKUP_DIR/data.tar.gz -C $MONITORING_DIR prometheus/data
        echo "✅ Резервная копия создана: $BACKUP_DIR"
        ;;
    cleanup)
        echo "Очистка старых данных мониторинга..."
        docker system prune -f
        find /var/backups/monitoring -type d -mtime +30 -exec rm -rf {} + 2>/dev/null
        echo "✅ Очистка завершена"
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|logs|update|backup|cleanup}"
        echo
        echo "Команды:"
        echo "  start    - Запустить мониторинг"
        echo "  stop     - Остановить мониторинг"
        echo "  restart  - Перезапустить мониторинг"
        echo "  status   - Показать статус"
        echo "  logs     - Показать логи (укажите сервис)"
        echo "  update   - Обновить образы"
        echo "  backup   - Создать резервную копию"
        echo "  cleanup  - Очистить старые данные"
        exit 1
        ;;
esac
EOF

chmod +x /root/monitoring-control.sh

echo "15. Настройка прав доступа..."

# Установка правильных прав для Prometheus
chown -R 65534:65534 $PROMETHEUS_DIR/data
chmod -R 755 $PROMETHEUS_DIR

echo "16. Запуск системы мониторинга..."

cd $DOCKER_COMPOSE_DIR
docker-compose up -d

echo "17. Создание отчета о настройке..."

cat > /root/monitoring-setup-report.txt << EOF
# ОТЧЕТ О НАСТРОЙКЕ СИСТЕМЫ МОНИТОРИНГА RTTI
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===

✅ Docker: $(docker --version)
✅ Docker Compose: $(docker-compose --version)
✅ Prometheus: порт 9090
✅ Node Exporter: порт 9100 
✅ Nginx Exporter: порт 9113
✅ PostgreSQL Exporter: порт 9187
✅ Redis Exporter: порт 9121
✅ Blackbox Exporter: порт 9115
✅ cAdvisor: порт 8080

=== КОНФИГУРАЦИЯ ===

Директория мониторинга: $MONITORING_DIR
Конфигурация Prometheus: $PROMETHEUS_DIR/config/prometheus.yml
Правила алертов: $PROMETHEUS_DIR/rules/alerts.yml
Docker Compose: $DOCKER_COMPOSE_DIR/docker-compose.yml

=== МЕТРИКИ И АЛЕРТЫ ===

Системные метрики:
- CPU, память, диск, сеть
- Загрузка системы
- Файловые системы

Веб-сервер:
- Статус Nginx
- Время ответа
- Количество запросов

База данных:
- Статус PostgreSQL
- Количество подключений
- Производительность запросов

Кэширование:
- Статус Redis
- Использование памяти
- Количество ключей

Внешние проверки:
- Доступность сайтов
- SSL сертификаты
- TCP подключения

=== УПРАВЛЕНИЕ ===

Управление мониторингом:
/root/monitoring-control.sh [start|stop|restart|status|logs|update|backup|cleanup]

Системный сервис:
systemctl [start|stop|restart|status] rtti-monitoring

Доступ к интерфейсам:
- Prometheus: http://localhost:9090
- cAdvisor: http://localhost:8080
- Node Exporter: http://localhost:9100/metrics

=== СЕТЕВАЯ КОНФИГУРАЦИЯ ===

Открытые порты (локально):
EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/monitoring-setup-report.txt << EOF
- 9100: доступен с Drupal сервера (92.242.61.204)

Мониторируемые внешние цели:
- Drupal сервер: 92.242.61.204:9100
- library.rtti.tj: HTTPS проверки
EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/monitoring-setup-report.txt << EOF
- 9100: доступен с Moodle сервера (92.242.60.172)

Мониторируемые внешние цели:
- Moodle сервер: 92.242.60.172:9100
- lms.rtti.tj: HTTPS проверки
EOF
fi

cat >> /root/monitoring-setup-report.txt << EOF

=== СЛЕДУЮЩИЕ ШАГИ ===

1. Установите Grafana (шаг 03-install-grafana.sh)
2. Настройте Alertmanager (шаг 04-configure-alertmanager.sh)
3. Создайте дашборды
4. Настройте уведомления
5. Проведите тестирование

=== КОМАНДЫ ПРОВЕРКИ ===

Статус контейнеров:
docker-compose -f $DOCKER_COMPOSE_DIR/docker-compose.yml ps

Логи Prometheus:
docker logs prometheus

Проверка метрик:
curl http://localhost:9090/metrics

Проверка правил:
curl http://localhost:9090/api/v1/rules

=== РЕКОМЕНДАЦИИ ===

- Регулярно обновляйте образы Docker
- Мониторьте использование дискового пространства
- Создавайте резервные копии конфигурации
- Настройте ротацию логов
- Оптимизируйте правила алертов

Мониторинг готов к работе!
EOF

echo "18. Удаление временных файлов..."
# Очистка не требуется - все файлы нужны

echo
echo "✅ Шаг 2 завершен успешно!"
echo "🐳 Docker установлен и настроен"
echo "📊 Prometheus запущен на порту 9090"
echo "📈 Экспортеры метрик активны"
echo "🔍 Blackbox проверки настроены"
echo "⚙️ Управление: /root/monitoring-control.sh"
echo "📋 Отчет: /root/monitoring-setup-report.txt"
echo "🌐 Доступ: http://localhost:9090"
echo "📌 Следующий шаг: ./03-install-grafana.sh"
echo
