#!/bin/bash

# RTTI Monitoring - Шаг 4: Настройка Alertmanager
# Серверы: omuzgorpro.tj (92.242.60.172), storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 4: Система уведомлений Alertmanager ==="
echo "🚨 Настройка алертов и уведомлений"
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
ALERTMANAGER_DIR="$MONITORING_DIR/alertmanager"
DOCKER_COMPOSE_DIR="$MONITORING_DIR/docker"

echo "🔍 Роль сервера: $SERVER_ROLE ($SERVER_NAME)"

echo "1. Проверка установки Prometheus и Grafana..."

if ! docker ps | grep -q prometheus; then
    echo "❌ Prometheus не запущен. Сначала выполните ./02-install-prometheus.sh"
    exit 1
fi

if ! docker ps | grep -q grafana; then
    echo "❌ Grafana не запущена. Сначала выполните ./03-install-grafana.sh"
    exit 1
fi

echo "✅ Prometheus и Grafana работают"

echo "2. Создание структуры директорий для Alertmanager..."

mkdir -p $ALERTMANAGER_DIR/{config,data,templates}

echo "3. Настройка конфигурации Alertmanager..."

cat > $ALERTMANAGER_DIR/config/alertmanager.yml << EOF
# Конфигурация Alertmanager для RTTI
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_ROLE)

global:
  # Глобальные настройки SMTP
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'monitoring@omuzgorpro.tj'
  smtp_auth_username: 'monitoring@omuzgorpro.tj'
  smtp_auth_password: 'your_app_password_here'
  smtp_auth_identity: 'monitoring@omuzgorpro.tj'
  
  # Глобальные настройки уведомлений
  resolve_timeout: 5m

# Шаблоны уведомлений
templates:
  - '/etc/alertmanager/templates/*.tmpl'

# Маршрутизация алертов
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'rtti-admin'
  
  routes:
    # Критические алерты - немедленно
    - match:
        severity: critical
      receiver: 'critical-alerts'
      group_wait: 10s
      group_interval: 1m
      repeat_interval: 1h
    
    # Алерты веб-сервисов
    - match:
        service: web
      receiver: 'web-admin'
      group_interval: 2m
      repeat_interval: 4h
    
    # Алерты базы данных
    - match:
        service: postgresql
      receiver: 'db-admin'
      group_interval: 2m
      repeat_interval: 6h
    
    # Системные алерты
    - match:
        service: system
      receiver: 'system-admin'
      group_interval: 5m
      repeat_interval: 8h

# Получатели уведомлений
receivers:
  # Основной администратор
  - name: 'rtti-admin'
    email_configs:
      - to: 'admin@omuzgorpro.tj'
        from: 'monitoring@omuzgorpro.tj'
        subject: '[RTTI Monitoring] {{ .GroupLabels.alertname }}'
        html: |
          <!DOCTYPE html>
          <html>
          <head>
              <meta charset="UTF-8">
              <title>RTTI Alert</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 20px; }
                  .alert { padding: 15px; margin: 10px 0; border-radius: 5px; }
                  .critical { background-color: #ffebee; border-left: 5px solid #f44336; }
                  .warning { background-color: #fff3e0; border-left: 5px solid #ff9800; }
                  .resolved { background-color: #e8f5e8; border-left: 5px solid #4caf50; }
                  .header { background-color: #f5f5f5; padding: 10px; border-radius: 5px; }
                  .details { margin: 10px 0; }
                  .timestamp { color: #666; font-size: 0.9em; }
              </style>
          </head>
          <body>
              <div class="header">
                  <h2>🚨 RTTI Monitoring Alert</h2>
                  <p><strong>Сервер:</strong> $SERVER_NAME ($SERVER_ROLE)</p>
                  <p><strong>Время:</strong> {{ .CommonAnnotations.timestamp }}</p>
              </div>
              
              {{ range .Alerts }}
              <div class="alert {{ if eq .Status "firing" }}{{ if eq .Labels.severity "critical" }}critical{{ else }}warning{{ end }}{{ else }}resolved{{ end }}">
                  <h3>{{ .Annotations.summary }}</h3>
                  <div class="details">
                      <p><strong>Описание:</strong> {{ .Annotations.description }}</p>
                      <p><strong>Сервис:</strong> {{ .Labels.service }}</p>
                      <p><strong>Инстанс:</strong> {{ .Labels.instance }}</p>
                      <p><strong>Критичность:</strong> {{ .Labels.severity }}</p>
                      <p class="timestamp"><strong>Время начала:</strong> {{ .StartsAt.Format "2006-01-02 15:04:05" }}</p>
                      {{ if ne .Status "firing" }}
                      <p class="timestamp"><strong>Время завершения:</strong> {{ .EndsAt.Format "2006-01-02 15:04:05" }}</p>
                      {{ end }}
                  </div>
              </div>
              {{ end }}
              
              <div class="header">
                  <p><small>Это автоматическое сообщение от системы мониторинга RTTI</small></p>
                  <p><small>Grafana: https://$SERVER_NAME/grafana/</small></p>
              </div>
          </body>
          </html>

  # Критические алерты (дополнительные получатели)
  - name: 'critical-alerts'
    email_configs:
      - to: 'admin@omuzgorpro.tj'
        from: 'monitoring@omuzgorpro.tj'
        subject: '🚨 [КРИТИЧНО] {{ .GroupLabels.alertname }} - $SERVER_NAME'
        body: |
          КРИТИЧЕСКИЙ АЛЕРТ НА СЕРВЕРЕ $SERVER_NAME
          
          Алерт: {{ .GroupLabels.alertname }}
          Время: {{ .CommonAnnotations.timestamp }}
          
          {{ range .Alerts }}
          - {{ .Annotations.summary }}
            Описание: {{ .Annotations.description }}
            Сервис: {{ .Labels.service }}
            Инстанс: {{ .Labels.instance }}
            Время начала: {{ .StartsAt.Format "15:04:05 02/01/2006" }}
          {{ end }}
          
          Немедленно проверьте систему!
          Grafana: https://$SERVER_NAME/grafana/
      
      # Telegram уведомления (если настроен)
      # webhook_configs:
      #   - url: 'https://api.telegram.org/bot<BOT_TOKEN>/sendMessage'
      #     send_resolved: true

  # Веб-администратор
  - name: 'web-admin'
    email_configs:
      - to: 'webadmin@omuzgorpro.tj'
        from: 'monitoring@omuzgorpro.tj'
        subject: '[WEB] {{ .GroupLabels.alertname }} - $SERVER_NAME'
        body: |
          Алерт веб-сервиса на $SERVER_NAME
          
          {{ range .Alerts }}
          Алерт: {{ .Annotations.summary }}
          Описание: {{ .Annotations.description }}
          URL: {{ .Labels.instance }}
          Время: {{ .StartsAt.Format "15:04:05 02/01/2006" }}
          {{ end }}

  # Администратор БД
  - name: 'db-admin'
    email_configs:
      - to: 'dbadmin@omuzgorpro.tj'
        from: 'monitoring@omuzgorpro.tj'
        subject: '[DATABASE] {{ .GroupLabels.alertname }} - $SERVER_NAME'
        body: |
          Алерт базы данных на $SERVER_NAME
          
          {{ range .Alerts }}
          Алерт: {{ .Annotations.summary }}
          Описание: {{ .Annotations.description }}
          Инстанс: {{ .Labels.instance }}
          Время: {{ .StartsAt.Format "15:04:05 02/01/2006" }}
          {{ end }}

  # Системный администратор
  - name: 'system-admin'
    email_configs:
      - to: 'sysadmin@omuzgorpro.tj'
        from: 'monitoring@omuzgorpro.tj'
        subject: '[SYSTEM] {{ .GroupLabels.alertname }} - $SERVER_NAME'
        body: |
          Системный алерт на $SERVER_NAME
          
          {{ range .Alerts }}
          Алерт: {{ .Annotations.summary }}
          Описание: {{ .Annotations.description }}
          Инстанс: {{ .Labels.instance }}
          Время: {{ .StartsAt.Format "15:04:05 02/01/2006" }}
          {{ end }}

# Подавление алертов
inhibit_rules:
  # Если сервер недоступен, не отправлять алерты о его сервисах
  - source_match:
      alertname: 'InstanceDown'
    target_match_re:
      service: '.*'
    equal: ['instance']
  
  # Если сайт недоступен, не отправлять алерты о медленном ответе
  - source_match:
      alertname: 'WebsiteDown'
    target_match:
      alertname: 'SlowWebsite'
    equal: ['instance']
  
  # Если критический алерт памяти, подавить предупреждение
  - source_match:
      alertname: 'CriticalMemoryUsage'
    target_match:
      alertname: 'HighMemoryUsage'
    equal: ['instance']

EOF

echo "4. Создание шаблонов уведомлений..."

cat > $ALERTMANAGER_DIR/templates/default.tmpl << 'EOF'
{{ define "__alert_severity_prefix" }}{{ if eq .Labels.severity "critical" }}🚨{{ else if eq .Labels.severity "warning" }}⚠️{{ else }}ℹ️{{ end }}{{ end }}

{{ define "__alert_severity_color" }}{{ if eq .Labels.severity "critical" }}danger{{ else if eq .Labels.severity "warning" }}warning{{ else }}good{{ end }}{{ end }}

{{ define "rtti.title" }}
{{ range .Alerts }}
{{ template "__alert_severity_prefix" . }} {{ .Annotations.summary }}
{{ end }}
{{ end }}

{{ define "rtti.text" }}
{{ range .Alerts }}
**Alert:** {{ .Annotations.summary }}
**Description:** {{ .Annotations.description }}
**Service:** {{ .Labels.service }}
**Instance:** {{ .Labels.instance }}
**Severity:** {{ .Labels.severity }}
**Time:** {{ .StartsAt.Format "2006-01-02 15:04:05" }}
{{ if ne .Status "firing" }}**Resolved:** {{ .EndsAt.Format "2006-01-02 15:04:05" }}{{ end }}

{{ end }}
{{ end }}

{{ define "slack.rtti.text" }}
{{ range .Alerts }}
{{ template "__alert_severity_prefix" . }} *{{ .Annotations.summary }}*
{{ .Annotations.description }}
*Service:* {{ .Labels.service }} | *Instance:* {{ .Labels.instance }}
*Time:* {{ .StartsAt.Format "15:04:05 02/01/2006" }}
{{ end }}
{{ end }}
EOF

echo "5. Добавление Alertmanager в Docker Compose..."

cat >> $DOCKER_COMPOSE_DIR/docker-compose.yml << EOF

  # Alertmanager - система уведомлений
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - $ALERTMANAGER_DIR/config:/etc/alertmanager
      - $ALERTMANAGER_DIR/data:/alertmanager
      - $ALERTMANAGER_DIR/templates:/etc/alertmanager/templates
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=https://$SERVER_NAME/alertmanager/'
      - '--web.route-prefix=/'
      - '--cluster.listen-address='
      - '--log.level=info'
    networks:
      - monitoring
    depends_on:
      - prometheus
EOF

echo "6. Настройка Nginx для Alertmanager..."

cat > /etc/nginx/conf.d/alertmanager.conf << EOF
# Конфигурация Nginx для Alertmanager
# Дата: $(date)

location /alertmanager/ {
    proxy_pass http://127.0.0.1:9093/;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    
    # Основные настройки прокси
    proxy_redirect off;
    proxy_buffering off;
    proxy_request_buffering off;
    
    # Таймауты
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Безопасность
    proxy_set_header X-Frame-Options SAMEORIGIN;
    proxy_set_header X-Content-Type-Options nosniff;
    proxy_set_header X-XSS-Protection "1; mode=block";
}

# API для внешних интеграций
location /alertmanager/api/ {
    proxy_pass http://127.0.0.1:9093/api/;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
}
EOF

echo "7. Настройка файрвола..."

# Alertmanager доступен только локально через nginx proxy
ufw allow from 127.0.0.1 to any port 9093 comment "Alertmanager"

echo "8. Создание дополнительных правил алертов..."

cat > $MONITORING_DIR/prometheus/rules/rtti-alerts.yml << EOF
# Специфичные алерты для RTTI инфраструктуры
# Дата: $(date)

groups:
  - name: rtti.critical
    rules:
      # Полная недоступность сервера
      - alert: ServerDown
        expr: up{job="node-exporter"} == 0
        for: 1m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "Сервер {{ \$labels.instance }} недоступен"
          description: "Сервер {{ \$labels.instance }} не отвечает более 1 минуты"

      # Критически мало места в корне
      - alert: RootPartitionFull
        expr: (1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100 > 95
        for: 1m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "Корневая файловая система заполнена на {{ \$labels.instance }}"
          description: "Свободного места менее 5% на корневом разделе {{ \$labels.instance }}"

      # Критически мало места в /var
      - alert: VarPartitionFull
        expr: (1 - (node_filesystem_avail_bytes{mountpoint="/var"} / node_filesystem_size_bytes{mountpoint="/var"})) * 100 > 90
        for: 5m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "Раздел /var заполнен на {{ \$labels.instance }}"
          description: "Свободного места менее 10% на разделе /var {{ \$labels.instance }}"

EOF

# Добавление специфичных алертов в зависимости от роли
if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> $MONITORING_DIR/prometheus/rules/rtti-alerts.yml << EOF
  - name: rtti.moodle
    rules:
      # Moodle LMS недоступен
      - alert: MoodleDown
        expr: probe_success{instance="https://omuzgorpro.tj"} == 0
        for: 2m
        labels:
          severity: critical
          service: moodle
        annotations:
          summary: "Система обучения Moodle недоступна"
          description: "LMS система omuzgorpro.tj не отвечает более 2 минут"

      # Медленный ответ Moodle
      - alert: MoodleSlow
        expr: probe_duration_seconds{instance="https://omuzgorpro.tj"} > 5
        for: 10m
        labels:
          severity: warning
          service: moodle
        annotations:
          summary: "Медленный ответ Moodle LMS"
          description: "Время ответа Moodle: {{ \$value }}s более 10 минут"

      # Проблемы с Drupal сервером (мониторинг с Moodle)
      - alert: DrupalServerIssue
        expr: up{instance="storage.omuzgorpro.tj"} == 0
        for: 5m
        labels:
          severity: warning
          service: drupal
        annotations:
          summary: "Проблемы с Drupal сервером"
          description: "Drupal сервер storage.omuzgorpro.tj недоступен с Moodle сервера"

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> $MONITORING_DIR/prometheus/rules/rtti-alerts.yml << EOF
  - name: rtti.drupal
    rules:
      # Drupal Library недоступна
      - alert: DrupalDown
        expr: probe_success{instance="https://storage.omuzgorpro.tj"} == 0
        for: 2m
        labels:
          severity: critical
          service: drupal
        annotations:
          summary: "Цифровая библиотека Drupal недоступна"
          description: "Библиотечная система storage.omuzgorpro.tj не отвечает более 2 минут"

      # Медленный ответ Drupal
      - alert: DrupalSlow
        expr: probe_duration_seconds{instance="https://storage.omuzgorpro.tj"} > 5
        for: 10m
        labels:
          severity: warning
          service: drupal
        annotations:
          summary: "Медленный ответ Drupal Library"
          description: "Время ответа библиотеки: {{ \$value }}s более 10 минут"

      # Проблемы с Moodle сервером (мониторинг с Drupal)
      - alert: MoodleServerIssue
        expr: up{instance="omuzgorpro.tj"} == 0
        for: 5m
        labels:
          severity: warning
          service: moodle
        annotations:
          summary: "Проблемы с Moodle сервером"
          description: "Moodle сервер omuzgorpro.tj недоступен с Drupal сервера"

EOF
fi

echo "9. Создание скрипта тестирования алертов..."

cat > /root/test-alerts.sh << 'EOF'
#!/bin/bash
# Тестирование системы алертов RTTI

ALERTMANAGER_URL="http://localhost:9093"
PROMETHEUS_URL="http://localhost:9090"

echo "=== Тестирование системы алертов RTTI ==="

# Функция для отправки тестового алерта
send_test_alert() {
    local severity=$1
    local message=$2
    
    curl -X POST "$ALERTMANAGER_URL/api/v1/alerts" \
         -H "Content-Type: application/json" \
         -d "[{
             \"labels\": {
                 \"alertname\": \"TestAlert\",
                 \"severity\": \"$severity\",
                 \"service\": \"test\",
                 \"instance\": \"test-instance\"
             },
             \"annotations\": {
                 \"summary\": \"$message\",
                 \"description\": \"Это тестовый алерт для проверки системы уведомлений\"
             },
             \"startsAt\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
             \"endsAt\": \"$(date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%S.000Z)\"
         }]"
}

case "$1" in
    warning)
        echo "Отправка тестового предупреждения..."
        send_test_alert "warning" "Тестовое предупреждение"
        ;;
    critical)
        echo "Отправка тестового критического алерта..."
        send_test_alert "critical" "Тестовый критический алерт"
        ;;
    status)
        echo "=== Статус Alertmanager ==="
        curl -s "$ALERTMANAGER_URL/api/v1/status" | jq .
        echo
        echo "=== Активные алерты ==="
        curl -s "$ALERTMANAGER_URL/api/v1/alerts" | jq '.data[] | {alertname: .labels.alertname, status: .status.state, instance: .labels.instance}'
        ;;
    config)
        echo "=== Проверка конфигурации ==="
        curl -s "$ALERTMANAGER_URL/api/v1/status" | jq .data.configYAML
        ;;
    silence)
        if [ -z "$2" ]; then
            echo "Использование: $0 silence <alertname>"
            exit 1
        fi
        echo "Создание тишины для алерта $2..."
        curl -X POST "$ALERTMANAGER_URL/api/v1/silences" \
             -H "Content-Type: application/json" \
             -d "{
                 \"matchers\": [{
                     \"name\": \"alertname\",
                     \"value\": \"$2\",
                     \"isRegex\": false
                 }],
                 \"startsAt\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
                 \"endsAt\": \"$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%S.000Z)\",
                 \"createdBy\": \"admin\",
                 \"comment\": \"Тестовая тишина\"
             }"
        ;;
    reload)
        echo "Перезагрузка конфигурации Alertmanager..."
        curl -X POST "$ALERTMANAGER_URL/-/reload"
        echo "✅ Конфигурация перезагружена"
        ;;
    *)
        echo "Использование: $0 {warning|critical|status|config|silence|reload}"
        echo
        echo "Команды:"
        echo "  warning  - Отправить тестовое предупреждение"
        echo "  critical - Отправить тестовый критический алерт"
        echo "  status   - Показать статус и активные алерты"
        echo "  config   - Показать конфигурацию"
        echo "  silence  - Создать тишину для алерта"
        echo "  reload   - Перезагрузить конфигурацию"
        exit 1
        ;;
esac
EOF

chmod +x /root/test-alerts.sh

echo "10. Настройка прав доступа..."

# Установка правильных прав для Alertmanager
chown -R 65534:65534 $ALERTMANAGER_DIR/data
chmod -R 755 $ALERTMANAGER_DIR

echo "11. Перезапуск Docker Compose с Alertmanager..."

cd $DOCKER_COMPOSE_DIR
docker-compose up -d

echo "12. Перезапуск Nginx..."
systemctl reload nginx

echo "13. Перезагрузка конфигурации Prometheus..."
# Отправка сигнала SIGHUP для перезагрузки правил
docker exec prometheus kill -HUP 1

echo "14. Ожидание запуска Alertmanager..."
sleep 20

echo "15. Создание скрипта настройки email уведомлений..."

cat > /root/setup-email-alerts.sh << 'EOF'
#!/bin/bash
# Настройка email уведомлений для RTTI

ALERTMANAGER_CONFIG="/opt/monitoring/alertmanager/config/alertmanager.yml"

echo "=== Настройка Email уведомлений ==="
echo
echo "Текущие email адреса в конфигурации:"
grep -E "to:|smtp_from:" $ALERTMANAGER_CONFIG

echo
echo "Для полной настройки email уведомлений:"
echo "1. Создайте приложение Gmail App Password"
echo "2. Отредактируйте файл: $ALERTMANAGER_CONFIG"
echo "3. Замените следующие параметры:"
echo "   - smtp_auth_password: 'your_app_password_here'"
echo "   - Все email адреса admin@omuzgorpro.tj, webadmin@omuzgorpro.tj и т.д."
echo "4. Перезапустите Alertmanager: docker-compose restart alertmanager"
echo
echo "Пример настройки Gmail:"
echo "  smtp_smarthost: 'smtp.gmail.com:587'"
echo "  smtp_from: 'your-email@gmail.com'"
echo "  smtp_auth_username: 'your-email@gmail.com'"
echo "  smtp_auth_password: 'your-16-char-app-password'"
echo
echo "Для Telegram уведомлений:"
echo "1. Создайте бота через @BotFather"
echo "2. Получите токен бота"
echo "3. Раскомментируйте webhook_configs в конфигурации"
echo "4. Замените <BOT_TOKEN> на реальный токен"
echo
echo "Тестирование:"
echo "/root/test-alerts.sh warning  # Тестовое предупреждение"
echo "/root/test-alerts.sh critical # Критический тест"
EOF

chmod +x /root/setup-email-alerts.sh

echo "16. Создание отчета о настройке Alertmanager..."

cat > /root/alertmanager-setup-report.txt << EOF
# ОТЧЕТ О НАСТРОЙКЕ ALERTMANAGER
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===

✅ Alertmanager: порт 9093 (через nginx proxy)
✅ Правила алертов: обновлены в Prometheus
✅ Шаблоны уведомлений: настроены
✅ Маршрутизация: настроена по типам

=== КОНФИГУРАЦИЯ ===

Директория: $ALERTMANAGER_DIR
Конфигурация: $ALERTMANAGER_DIR/config/alertmanager.yml
Шаблоны: $ALERTMANAGER_DIR/templates/
Правила: $MONITORING_DIR/prometheus/rules/rtti-alerts.yml
Nginx конфигурация: /etc/nginx/conf.d/alertmanager.conf

=== НАСТРОЕННЫЕ АЛЕРТЫ ===

Системные алерты:
- Высокая загрузка CPU (>80% 5мин, >95% 2мин)
- Высокое использование памяти (>85% 5мин, >95% 2мин)
- Мало места на диске (>85% 5мин, >95% 2мин)
- Высокая загрузка системы
- Недоступность сервера

Веб-алерты:
- Сайт недоступен (1мин)
- Медленный ответ (>3сек 5мин)
- Проблемы с SSL сертификатом
- Nginx недоступен

База данных:
- PostgreSQL недоступен (1мин)
- Много подключений (>100 5мин)

Кэширование:
- Redis недоступен (1мин)
- Высокое использование памяти Redis (>85%)

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/alertmanager-setup-report.txt << EOF
Специфичные для Moodle:
- Moodle LMS недоступен (2мин)
- Медленный ответ Moodle (>5сек 10мин)
- Проблемы с Drupal сервером

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/alertmanager-setup-report.txt << EOF
Специфичные для Drupal:
- Drupal Library недоступна (2мин)
- Медленный ответ Drupal (>5сек 10мин)
- Проблемы с Moodle сервером

EOF
fi

cat >> /root/alertmanager-setup-report.txt << EOF
=== ПОЛУЧАТЕЛИ УВЕДОМЛЕНИЙ ===

По умолчанию (требует настройки email):
- rtti-admin: admin@omuzgorpro.tj
- critical-alerts: admin@omuzgorpro.tj (критические)
- web-admin: webadmin@omuzgorpro.tj
- db-admin: dbadmin@omuzgorpro.tj
- system-admin: sysadmin@omuzgorpro.tj

=== МАРШРУТИЗАЦИЯ ===

- Критические алерты: 10сек группировка, 1мин интервал, 1час повтор
- Веб-сервисы: 30сек группировка, 2мин интервал, 4час повтор
- База данных: 30сек группировка, 2мин интервал, 6час повтор
- Система: 30сек группировка, 5мин интервал, 8час повтор

=== ПОДАВЛЕНИЕ АЛЕРТОВ ===

- При недоступности сервера подавляются алерты его сервисов
- При недоступности сайта подавляются алерты о медленном ответе
- При критических алертах подавляются предупреждения

=== ДОСТУП ===

URL: https://$SERVER_NAME/alertmanager/
Локальный: http://localhost:9093
API: https://$SERVER_NAME/alertmanager/api/

=== УПРАВЛЕНИЕ ===

Тестирование алертов:
/root/test-alerts.sh [warning|critical|status|config|silence|reload]

Настройка email:
/root/setup-email-alerts.sh

Перезапуск Alertmanager:
docker-compose -f $DOCKER_COMPOSE_DIR/docker-compose.yml restart alertmanager

Логи Alertmanager:
docker logs alertmanager

=== ТРЕБУЕТСЯ НАСТРОЙКА ===

1. Email уведомления:
   - Настройте SMTP параметры в $ALERTMANAGER_DIR/config/alertmanager.yml
   - Замените email адреса на реальные
   - Настройте App Password для Gmail

2. Telegram (опционально):
   - Создайте бота через @BotFather
   - Получите токен и chat ID
   - Раскомментируйте webhook_configs

3. Slack (опционально):
   - Создайте Slack приложение
   - Получите webhook URL
   - Добавьте slack_configs в receivers

=== СЛЕДУЮЩИЕ ШАГИ ===

1. Настройте email уведомления
2. Протестируйте алерты
3. Настройте дополнительные получатели
4. Создайте пользовательские алерты
5. Интегрируйте с внешними системами

=== КОМАНДЫ ПРОВЕРКИ ===

Статус Alertmanager:
curl -s http://localhost:9093/api/v1/status

Активные алерты:
curl -s http://localhost:9093/api/v1/alerts

Конфигурация:
/root/test-alerts.sh config

Тест критического алерта:
/root/test-alerts.sh critical

Alertmanager готов к работе!
(Требуется настройка email для полной функциональности)
EOF

echo "17. Проверка доступности Alertmanager..."

sleep 10
if curl -s "http://localhost:9093/api/v1/status" | grep -q "success"; then
    echo "✅ Alertmanager успешно запущен и отвечает"
else
    echo "⚠️ Alertmanager может еще запускаться, проверьте через несколько минут"
fi

echo
echo "✅ Шаг 4 завершен успешно!"
echo "🚨 Alertmanager установлен и настроен"
echo "📧 Система уведомлений готова"
echo "⚡ Правила алертов активированы"
echo "🔄 Маршрутизация настроена"
echo "🌐 Веб-доступ: https://$SERVER_NAME/alertmanager/"
echo "📋 Отчет: /root/alertmanager-setup-report.txt"
echo "🧪 Тестирование: /root/test-alerts.sh"
echo "📧 Настройка email: /root/setup-email-alerts.sh"
echo "⚠️ ВНИМАНИЕ: Настройте email в конфигурации для получения уведомлений!"
echo "📌 Следующий шаг: ./05-configure-exporters.sh"
echo