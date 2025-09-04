#!/bin/bash

# RTTI Monitoring - Шаг 1: Подготовка системы мониторинга
# Серверы: lms.rtti.tj (92.242.60.172) + library.rtti.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 1: Подготовка системы мониторинга ==="
echo "📊 Настройка инфраструктуры мониторинга для RTTI"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Определение роли сервера..."
SERVER_IP=$(hostname -I | awk '{print $1}')
if [[ "$SERVER_IP" == "92.242.60.172" ]]; then
    SERVER_ROLE="moodle"
    SERVER_NAME="lms.rtti.tj"
    echo "🎓 Сервер Moodle LMS обнаружен"
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    SERVER_ROLE="drupal"
    SERVER_NAME="library.rtti.tj"
    echo "📚 Сервер Drupal Library обнаружен"
else
    echo "⚠️  Неизвестный сервер, будет настроен как общий сервер мониторинга"
    SERVER_ROLE="monitoring"
    SERVER_NAME=$(hostname)
fi

echo "2. Обновление системы..."
apt update && apt upgrade -y

echo "3. Установка базовых пакетов для мониторинга..."
apt install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    jq \
    htop \
    iotop \
    nethogs \
    ncdu \
    tree \
    git

echo "4. Создание пользователей для мониторинга..."
# Пользователь для Prometheus
if ! id "prometheus" &>/dev/null; then
    useradd --no-create-home --shell /bin/false prometheus
    echo "✅ Пользователь prometheus создан"
fi

# Пользователь для Node Exporter
if ! id "node_exporter" &>/dev/null; then
    useradd --no-create-home --shell /bin/false node_exporter
    echo "✅ Пользователь node_exporter создан"
fi

# Пользователь для Grafana (если будет устанавливаться)
if ! id "grafana" &>/dev/null; then
    useradd --no-create-home --shell /bin/false grafana
    echo "✅ Пользователь grafana создан"
fi

echo "5. Создание каталогов для мониторинга..."
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus
mkdir -p /etc/alertmanager
mkdir -p /var/lib/alertmanager
mkdir -p /var/log/prometheus
mkdir -p /var/log/grafana
mkdir -p /opt/monitoring

# Установка прав доступа
chown prometheus:prometheus /etc/prometheus
chown prometheus:prometheus /var/lib/prometheus
chown prometheus:prometheus /var/log/prometheus

echo "6. Настройка часового пояса..."
timedatectl set-timezone Asia/Dushanbe
echo "✅ Часовой пояс: $(timedatectl | grep "Time zone")"

echo "7. Настройка файрвола для мониторинга..."
ufw allow 9090/tcp comment "Prometheus"
ufw allow 3000/tcp comment "Grafana"
ufw allow 9093/tcp comment "Alertmanager"
ufw allow 9100/tcp comment "Node Exporter"

# Специфичные порты для каждого сервера
if [ "$SERVER_ROLE" = "moodle" ]; then
    ufw allow 9117/tcp comment "Moodle Exporter"
    ufw allow 9187/tcp comment "PostgreSQL Exporter"
    ufw allow 9121/tcp comment "Redis Exporter"
elif [ "$SERVER_ROLE" = "drupal" ]; then
    ufw allow 9187/tcp comment "PostgreSQL Exporter"
    ufw allow 9121/tcp comment "Redis Exporter"
    ufw allow 9113/tcp comment "Nginx Exporter"
fi

echo "8. Установка Docker для контейнеризованного мониторинга..."
# Добавление репозитория Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Запуск и включение Docker
systemctl start docker
systemctl enable docker

# Добавление пользователя в группу docker
usermod -aG docker $USER

echo "9. Создание конфигурации для системной информации..."
cat > /opt/monitoring/system-info.sh << EOF
#!/bin/bash
# Скрипт сбора системной информации для мониторинга

echo "=== System Information for Monitoring ==="
echo "Server Role: $SERVER_ROLE"
echo "Server Name: $SERVER_NAME"
echo "Server IP: $SERVER_IP"
echo "Date: \$(date)"
echo "Uptime: \$(uptime -p)"
echo "OS: \$(lsb_release -d | cut -f2)"
echo "Kernel: \$(uname -r)"
echo "CPU: \$(nproc) cores"
echo "Memory: \$(free -h | grep Mem | awk '{print \$2}')"
echo "Disk: \$(df -h / | tail -1 | awk '{print \$2 " total, " \$4 " free"}')"
echo

if [ "$SERVER_ROLE" = "moodle" ]; then
    echo "=== Moodle Services ==="
    systemctl is-active nginx php8.3-fpm postgresql redis-server
elif [ "$SERVER_ROLE" = "drupal" ]; then
    echo "=== Drupal Services ==="
    systemctl is-active nginx php8.3-fpm postgresql redis-server memcached
fi
EOF

chmod +x /opt/monitoring/system-info.sh

echo "10. Создание базового конфига Prometheus..."
cat > /etc/prometheus/prometheus.yml << EOF
# Prometheus configuration for RTTI
# Generated: $(date)

global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'rtti'
    server_role: '$SERVER_ROLE'

rule_files:
  - "rtti_alerts.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          server: '$SERVER_NAME'
          role: 'monitoring'

  # Node Exporter
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          server: '$SERVER_NAME'
          role: '$SERVER_ROLE'

EOF

# Добавление специфичных экспортеров для каждого сервера
if [ "$SERVER_ROLE" = "moodle" ]; then
    cat >> /etc/prometheus/prometheus.yml << EOF
  # PostgreSQL Exporter for Moodle
  - job_name: 'postgresql-moodle'
    static_configs:
      - targets: ['localhost:9187']
        labels:
          server: '$SERVER_NAME'
          database: 'moodle'

  # Redis Exporter for Moodle
  - job_name: 'redis-moodle'
    static_configs:
      - targets: ['localhost:9121']
        labels:
          server: '$SERVER_NAME'
          service: 'redis'

  # Nginx Exporter for Moodle
  - job_name: 'nginx-moodle'
    static_configs:
      - targets: ['localhost:9113']
        labels:
          server: '$SERVER_NAME'
          service: 'nginx'
EOF

elif [ "$SERVER_ROLE" = "drupal" ]; then
    cat >> /etc/prometheus/prometheus.yml << EOF
  # PostgreSQL Exporter for Drupal
  - job_name: 'postgresql-drupal'
    static_configs:
      - targets: ['localhost:9187']
        labels:
          server: '$SERVER_NAME'
          database: 'drupal_library'

  # Redis Exporter for Drupal
  - job_name: 'redis-drupal'
    static_configs:
      - targets: ['localhost:9121']
        labels:
          server: '$SERVER_NAME'
          service: 'redis'

  # Nginx Exporter for Drupal
  - job_name: 'nginx-drupal'
    static_configs:
      - targets: ['localhost:9113']
        labels:
          server: '$SERVER_NAME'
          service: 'nginx'

  # Memcached Exporter for Drupal
  - job_name: 'memcached-drupal'
    static_configs:
      - targets: ['localhost:9150']
        labels:
          server: '$SERVER_NAME'
          service: 'memcached'
EOF
fi

chown prometheus:prometheus /etc/prometheus/prometheus.yml

echo "11. Создание базовых правил алертинга..."
cat > /etc/prometheus/rtti_alerts.yml << EOF
# RTTI Alerting Rules
# Generated: $(date)

groups:
  - name: rtti.rules
    rules:
      # Высокое использование CPU
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Высокое использование CPU на {{ \$labels.instance }}"
          description: "CPU использование {{ \$value }}% более 5 минут"

      # Высокое использование памяти
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Высокое использование памяти на {{ \$labels.instance }}"
          description: "Память использована на {{ \$value }}%"

      # Мало свободного места на диске
      - alert: LowDiskSpace
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
        for: 5m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "Мало места на диске {{ \$labels.device }} на {{ \$labels.instance }}"
          description: "Использовано {{ \$value }}% дискового пространства"

      # Сервис недоступен
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Сервис {{ \$labels.job }} недоступен"
          description: "Сервис {{ \$labels.job }} на {{ \$labels.instance }} недоступен более 1 минуты"
EOF

chown prometheus:prometheus /etc/prometheus/rtti_alerts.yml

echo "12. Создание docker-compose для мониторинга..."
cat > /opt/monitoring/docker-compose.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - /etc/prometheus:/etc/prometheus
      - /var/lib/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    user: "$(id -u prometheus):$(id -g prometheus)"

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
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - /etc/alertmanager:/etc/alertmanager
      - /var/lib/alertmanager:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
      - /var/log/grafana:/var/log/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123!RTTI
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_DOMAIN=$SERVER_NAME
      - GF_SMTP_ENABLED=true
      - GF_SMTP_HOST=localhost:587
      - GF_SMTP_FROM_ADDRESS=monitoring@rtti.tj

volumes:
  grafana-storage:
EOF

echo "13. Создание скрипта управления мониторингом..."
cat > /opt/monitoring/monitoring-control.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "Запуск мониторинга..."
        cd /opt/monitoring
        docker compose up -d
        echo "✅ Мониторинг запущен"
        ;;
    stop)
        echo "Остановка мониторинга..."
        cd /opt/monitoring
        docker compose down
        echo "✅ Мониторинг остановлен"
        ;;
    restart)
        echo "Перезапуск мониторинга..."
        cd /opt/monitoring
        docker compose restart
        echo "✅ Мониторинг перезапущен"
        ;;
    status)
        echo "Статус мониторинга:"
        cd /opt/monitoring
        docker compose ps
        ;;
    logs)
        echo "Логи мониторинга:"
        cd /opt/monitoring
        docker compose logs --tail=50 -f
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

chmod +x /opt/monitoring/monitoring-control.sh

echo "14. Создание информационного файла..."
cat > /root/monitoring-system-info.txt << EOF
# Информация о системе мониторинга RTTI
# Дата подготовки: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== КОМПОНЕНТЫ МОНИТОРИНГА ===
✅ Prometheus (метрики)
✅ Grafana (визуализация)
✅ Alertmanager (уведомления)
✅ Node Exporter (системные метрики)
✅ Docker & Docker Compose

=== ПОРТЫ СЕРВИСОВ ===
Prometheus: 9090
Grafana: 3000
Alertmanager: 9093
Node Exporter: 9100

=== ФАЙЛЫ КОНФИГУРАЦИИ ===
Prometheus: /etc/prometheus/prometheus.yml
Алерты: /etc/prometheus/rtti_alerts.yml
Docker Compose: /opt/monitoring/docker-compose.yml

=== КОМАНДЫ УПРАВЛЕНИЯ ===
Запуск: /opt/monitoring/monitoring-control.sh start
Остановка: /opt/monitoring/monitoring-control.sh stop
Статус: /opt/monitoring/monitoring-control.sh status
Логи: /opt/monitoring/monitoring-control.sh logs

=== WEB ИНТЕРФЕЙСЫ ===
Prometheus: http://$SERVER_IP:9090
Grafana: http://$SERVER_IP:3000 (admin/admin123!RTTI)
Alertmanager: http://$SERVER_IP:9093

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Запустите: ./02-install-prometheus.sh
2. Настройте экспортеры: ./03-install-exporters.sh
3. Настройте Grafana: ./04-configure-grafana.sh
4. Настройте алерты: ./05-configure-alerts.sh

=== БЕЗОПАСНОСТЬ ===
- Файрвол настроен для портов мониторинга
- Пользователи созданы для сервисов
- Конфигурации защищены правами доступа
EOF

echo
echo "✅ Шаг 1 завершен успешно!"
echo "📌 Система подготовлена для мониторинга"
echo "📌 Роль сервера: $SERVER_ROLE ($SERVER_NAME)"
echo "📌 Docker установлен и настроен"
echo "📌 Пользователи и каталоги созданы"
echo "📌 Базовые конфигурации готовы"
echo "📌 Информация: /root/monitoring-system-info.txt"
echo "📌 Управление: /opt/monitoring/monitoring-control.sh"
echo "📌 Следующий шаг: ./02-install-prometheus.sh"
echo
