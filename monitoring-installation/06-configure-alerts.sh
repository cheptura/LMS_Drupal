#!/bin/bash

# 06-configure-alerts.sh
# Настройка правил алертов и интеграция с Alertmanager

set -e

echo "=== Настройка правил алертов ==="

# Директории для правил алертов
PROMETHEUS_CONFIG_DIR="/etc/prometheus"
RULES_DIR="$PROMETHEUS_CONFIG_DIR/rules"

# Создание директории для правил
echo "Создание директории для правил алертов..."
sudo mkdir -p $RULES_DIR

# Создание базовых правил алертов
echo "Создание правил алертов для системы..."

# Правила для Node Exporter
sudo tee $RULES_DIR/node_alerts.yml > /dev/null <<EOF
groups:
- name: node_alerts
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Высокая загрузка CPU на {{ \$labels.instance }}"
      description: "CPU загружен на {{ \$value }}% более 5 минут"

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Высокое использование памяти на {{ \$labels.instance }}"
      description: "Память используется на {{ \$value }}%"

  - alert: DiskSpaceLow
    expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 90
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "Мало места на диске {{ \$labels.device }} на {{ \$labels.instance }}"
      description: "Диск заполнен на {{ \$value }}%"

  - alert: NodeDown
    expr: up{job="node"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Узел {{ \$labels.instance }} недоступен"
      description: "Node Exporter недоступен более 1 минуты"

  - alert: HighLoadAverage
    expr: node_load5 / count by(instance) (node_cpu_seconds_total{mode="idle"}) > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Высокая нагрузка на {{ \$labels.instance }}"
      description: "Load average (5m): {{ \$value }}"
EOF

# Правила для веб-сервисов
sudo tee $RULES_DIR/web_alerts.yml > /dev/null <<EOF
groups:
- name: web_alerts
  rules:
  - alert: WebServiceDown
    expr: up{job=~"moodle|drupal|nginx"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Веб-сервис {{ \$labels.job }} недоступен"
      description: "Сервис {{ \$labels.job }} на {{ \$labels.instance }} не отвечает"

  - alert: HighResponseTime
    expr: nginx_http_request_duration_seconds_avg > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Медленный отклик веб-сервера"
      description: "Среднее время ответа: {{ \$value }}s на {{ \$labels.instance }}"

  - alert: TooManyHTTPErrors
    expr: rate(nginx_http_requests_total{status=~"4..|5.."}[5m]) > 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Много HTTP ошибок"
      description: "{{ \$value }} ошибок в секунду на {{ \$labels.instance }}"
EOF

# Правила для баз данных
sudo tee $RULES_DIR/database_alerts.yml > /dev/null <<EOF
groups:
- name: database_alerts
  rules:
  - alert: PostgreSQLDown
    expr: up{job="postgres"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "PostgreSQL недоступна"
      description: "PostgreSQL на {{ \$labels.instance }} не отвечает"

  - alert: PostgreSQLTooManyConnections
    expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Много подключений к PostgreSQL"
      description: "{{ \$value }}% от максимального числа подключений"

  - alert: RedisDown
    expr: up{job="redis"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Redis недоступен"
      description: "Redis на {{ \$labels.instance }} не отвечает"

  - alert: RedisHighMemoryUsage
    expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Redis использует много памяти"
      description: "{{ \$value }}% памяти используется Redis"
EOF

# Правила для системы мониторинга
sudo tee $RULES_DIR/monitoring_alerts.yml > /dev/null <<EOF
groups:
- name: monitoring_alerts
  rules:
  - alert: PrometheusTargetDown
    expr: up == 0
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Цель мониторинга недоступна"
      description: "{{ \$labels.job }} на {{ \$labels.instance }} недоступна"

  - alert: PrometheusConfigReload
    expr: prometheus_config_last_reload_successful != 1
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Ошибка перезагрузки конфигурации Prometheus"
      description: "Не удалось перезагрузить конфигурацию Prometheus"

  - alert: AlertmanagerDown
    expr: up{job="alertmanager"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Alertmanager недоступен"
      description: "Alertmanager не отвечает"

  - alert: GrafanaDown
    expr: up{job="grafana"} == 0
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Grafana недоступна"
      description: "Grafana не отвечает"
EOF

# Обновление конфигурации Prometheus для включения правил алертов
echo "Обновление конфигурации Prometheus..."

# Создание резервной копии
sudo cp $PROMETHEUS_CONFIG_DIR/prometheus.yml $PROMETHEUS_CONFIG_DIR/prometheus.yml.backup

# Создание обновленной конфигурации Prometheus
sudo tee $PROMETHEUS_CONFIG_DIR/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['localhost:9093']

  - job_name: 'grafana'
    static_configs:
      - targets: ['localhost:3000']

  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['localhost:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['localhost:9121']
EOF

# Установка правильных прав доступа
echo "Установка прав доступа..."
sudo chown -R prometheus:prometheus $PROMETHEUS_CONFIG_DIR
sudo chown -R prometheus:prometheus $RULES_DIR

# Проверка конфигурации Prometheus
echo "Проверка конфигурации Prometheus..."
if sudo -u prometheus /opt/prometheus/promtool check config $PROMETHEUS_CONFIG_DIR/prometheus.yml; then
    echo "✅ Конфигурация Prometheus корректна"
else
    echo "❌ Ошибка в конфигурации Prometheus"
    echo "Восстанавливаем резервную копию..."
    sudo mv $PROMETHEUS_CONFIG_DIR/prometheus.yml.backup $PROMETHEUS_CONFIG_DIR/prometheus.yml
    exit 1
fi

# Проверка правил алертов
echo "Проверка правил алертов..."
for rule_file in $RULES_DIR/*.yml; do
    if sudo -u prometheus /opt/prometheus/promtool check rules "$rule_file"; then
        echo "✅ Правила в $(basename $rule_file) корректны"
    else
        echo "❌ Ошибка в правилах $(basename $rule_file)"
        exit 1
    fi
done

# Перезагрузка Prometheus
echo "Перезагрузка Prometheus..."
sudo systemctl reload prometheus

# Проверка загрузки правил
echo "Проверка загрузки правил алертов..."
sleep 5

if curl -s http://localhost:9090/api/v1/rules | grep -q "node_alerts"; then
    echo "✅ Правила алертов успешно загружены"
else
    echo "⚠️ Возможна проблема с загрузкой правил"
fi

# Проверка соединения с Alertmanager
echo "Проверка соединения с Alertmanager..."
if curl -s http://localhost:9090/api/v1/alertmanagers | grep -q "localhost:9093"; then
    echo "✅ Prometheus подключен к Alertmanager"
else
    echo "❌ Проблема с подключением к Alertmanager"
fi

echo "=== Настройка алертов завершена ==="
echo ""
echo "Созданы следующие группы правил:"
echo "- node_alerts.yml - алерты для системных метрик"
echo "- web_alerts.yml - алерты для веб-сервисов"
echo "- database_alerts.yml - алерты для баз данных"
echo "- monitoring_alerts.yml - алерты для системы мониторинга"
echo ""
echo "Веб-интерфейсы:"
echo "- Prometheus: http://localhost:9090"
echo "- Alertmanager: http://localhost:9093"
echo ""
echo "Для просмотра активных алертов:"
echo "curl http://localhost:9090/api/v1/alerts"
