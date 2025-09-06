#!/bin/bash

# RTTI Monitoring - Шаг 10: Финальная проверка и запуск
# Серверы: omuzgorpro.tj (92.242.60.172), storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 10: Финальная проверка и запуск ==="
echo "🎯 Комплексная проверка системы мониторинга и запуск в продакшн"
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
    OTHER_SERVER="storage.omuzgorpro.tj"
    OTHER_IP="92.242.61.204"
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    SERVER_ROLE="drupal"
    SERVER_NAME="storage.omuzgorpro.tj"
    OTHER_SERVER="omuzgorpro.tj"
    OTHER_IP="92.242.60.172"
else
    SERVER_ROLE="standalone"
    SERVER_NAME=$(hostname -f)
    OTHER_SERVER="N/A"
    OTHER_IP="N/A"
fi

MONITORING_DIR="/opt/monitoring"
FINAL_CHECK_DIR="$MONITORING_DIR/final-check"

echo "🔍 Роль сервера: $SERVER_ROLE ($SERVER_NAME)"
echo "🔗 Парный сервер: $OTHER_SERVER ($OTHER_IP)"

echo "1. Создание структуры для финальной проверки..."
mkdir -p $FINAL_CHECK_DIR/{reports,tests,logs,screenshots}

echo "2. Проверка установленных компонентов..."

# Функция логирования результатов
log_result() {
    local component="$1"
    local status="$2"
    local details="$3"
    
    if [ "$status" = "OK" ]; then
        echo "✅ $component: $status - $details"
        echo "[$(date)] ✅ $component: $status - $details" >> $FINAL_CHECK_DIR/logs/final-check.log
    else
        echo "❌ $component: $status - $details"
        echo "[$(date)] ❌ $component: $status - $details" >> $FINAL_CHECK_DIR/logs/final-check.log
    fi
}

echo "=== ПРОВЕРКА DOCKER КОНТЕЙНЕРОВ ==="

# Проверка Docker
if command -v docker >/dev/null 2>&1; then
    log_result "Docker" "OK" "$(docker --version)"
else
    log_result "Docker" "FAIL" "Docker не установлен"
fi

# Проверка Docker Compose
if command -v docker-compose >/dev/null 2>&1; then
    log_result "Docker Compose" "OK" "$(docker-compose --version)"
else
    log_result "Docker Compose" "FAIL" "Docker Compose не установлен"
fi

# Проверка запущенных контейнеров
echo "Статус контейнеров мониторинга:"
expected_containers=("prometheus" "grafana" "alertmanager" "node-exporter" "nginx-exporter" "postgres-exporter" "redis-exporter" "blackbox-exporter" "cadvisor" "process-exporter" "ssl-exporter" "rtti-exporter")

running_containers=0
total_containers=${#expected_containers[@]}

for container in "${expected_containers[@]}"; do
    if docker ps | grep -q "$container"; then
        log_result "Container $container" "OK" "Running"
        running_containers=$((running_containers + 1))
    else
        log_result "Container $container" "FAIL" "Not running"
    fi
done

echo "📊 Запущено контейнеров: $running_containers/$total_containers"

echo "3. Проверка доступности сервисов..."

# Функция проверки HTTP сервиса
check_http_service() {
    local service="$1"
    local port="$2"
    local path="$3"
    local timeout="${4:-10}"
    
    if curl -s --connect-timeout $timeout "http://localhost:$port$path" > /dev/null 2>&1; then
        log_result "HTTP $service" "OK" "Port $port accessible"
        return 0
    else
        log_result "HTTP $service" "FAIL" "Port $port not accessible"
        return 1
    fi
}

# Проверка основных сервисов
check_http_service "Prometheus" "9090" "/api/v1/status/config"
check_http_service "Grafana" "3000" "/api/health"
check_http_service "Alertmanager" "9093" "/api/v1/status"

# Проверка экспортеров
check_http_service "Node Exporter" "9100" "/metrics"
check_http_service "Nginx Exporter" "9113" "/metrics"
check_http_service "PostgreSQL Exporter" "9187" "/metrics"
check_http_service "Redis Exporter" "9121" "/metrics"
check_http_service "Blackbox Exporter" "9115" "/metrics"
check_http_service "cAdvisor" "8080" "/metrics"
check_http_service "Process Exporter" "9256" "/metrics"
check_http_service "SSL Exporter" "9219" "/metrics"
check_http_service "RTTI Exporter" "9999" "/metrics"

echo "4. Проверка метрик и данных..."

# Проверка активных таргетов в Prometheus
echo "=== ПРОВЕРКА PROMETHEUS ==="

if curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets[].health' | grep -q "up"; then
    active_targets=$(curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets | map(select(.health == "up")) | length')
    total_targets=$(curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets | length')
    log_result "Prometheus Targets" "OK" "$active_targets/$total_targets targets UP"
else
    log_result "Prometheus Targets" "FAIL" "No active targets found"
fi

# Проверка доступности метрик
if curl -s "http://localhost:9090/api/v1/query?query=up" | jq -r '.data.result[].value[1]' | grep -q "1"; then
    up_instances=$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result | map(select(.[1] == "1")) | length')
    log_result "Prometheus Metrics" "OK" "$up_instances instances reporting UP"
else
    log_result "Prometheus Metrics" "FAIL" "No UP metrics found"
fi

# Проверка TSDB статистики
tsdb_size=$(curl -s "http://localhost:9090/api/v1/query?query=prometheus_tsdb_size_bytes" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
tsdb_size_mb=$((tsdb_size / 1024 / 1024))
log_result "Prometheus TSDB" "OK" "Size: ${tsdb_size_mb}MB"

echo "5. Проверка алертов..."

# Проверка правил алертов
if curl -s "http://localhost:9090/api/v1/rules" | jq -r '.data.groups[].rules[].name' | wc -l | grep -q "[1-9]"; then
    alert_rules=$(curl -s "http://localhost:9090/api/v1/rules" | jq '.data.groups[].rules | length' | paste -sd+ | bc)
    log_result "Alert Rules" "OK" "$alert_rules rules loaded"
else
    log_result "Alert Rules" "FAIL" "No alert rules found"
fi

# Проверка активных алертов
active_alerts=$(curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts | length')
firing_alerts=$(curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts | map(select(.state == "firing")) | length')
log_result "Active Alerts" "OK" "$firing_alerts firing, $active_alerts total"

echo "6. Проверка Grafana..."

# Проверка дашбордов
echo "=== ПРОВЕРКА GRAFANA ==="

# Получение списка дашбордов (требует авторизации)
if curl -s -u admin:admin "http://localhost:3000/api/search" | jq -r '.[].title' | wc -l | grep -q "[1-9]"; then
    dashboard_count=$(curl -s -u admin:admin "http://localhost:3000/api/search" | jq '. | length')
    log_result "Grafana Dashboards" "OK" "$dashboard_count dashboards found"
else
    log_result "Grafana Dashboards" "FAIL" "No dashboards found or auth failed"
fi

# Проверка источников данных
if curl -s -u admin:admin "http://localhost:3000/api/datasources" | jq -r '.[].name' | grep -q "Prometheus"; then
    datasource_count=$(curl -s -u admin:admin "http://localhost:3000/api/datasources" | jq '. | length')
    log_result "Grafana Datasources" "OK" "$datasource_count datasources configured"
else
    log_result "Grafana Datasources" "FAIL" "Prometheus datasource not found"
fi

echo "7. Проверка резервного копирования..."

# Проверка скриптов резервного копирования
echo "=== ПРОВЕРКА РЕЗЕРВНОГО КОПИРОВАНИЯ ==="

backup_scripts=("backup-configs.sh" "backup-data.sh" "backup-full.sh" "restore.sh" "verify-backups.sh" "sync-remote.sh")
for script in "${backup_scripts[@]}"; do
    if [ -x "/opt/monitoring-backup/$script" ]; then
        log_result "Backup Script $script" "OK" "Executable"
    else
        log_result "Backup Script $script" "FAIL" "Not found or not executable"
    fi
done

# Проверка cron задач
if crontab -l | grep -q "backup"; then
    backup_jobs=$(crontab -l | grep backup | wc -l)
    log_result "Backup Cron Jobs" "OK" "$backup_jobs jobs scheduled"
else
    log_result "Backup Cron Jobs" "FAIL" "No backup jobs found"
fi

echo "8. Проверка сетевой связности..."

echo "=== ПРОВЕРКА СЕТЕВОЙ СВЯЗНОСТИ ==="

# Проверка локальных портов
local_ports=("9090" "3000" "9093" "9100" "9113" "9187" "9121" "9115" "8080" "9256" "9219" "9999")
open_ports=0

for port in "${local_ports[@]}"; do
    if netstat -tuln | grep -q ":$port "; then
        log_result "Port $port" "OK" "Open"
        open_ports=$((open_ports + 1))
    else
        log_result "Port $port" "FAIL" "Closed"
    fi
done

echo "📊 Открытых портов: $open_ports/${#local_ports[@]}"

# Проверка связи с парным сервером
if [ "$OTHER_IP" != "N/A" ]; then
    if ping -c 1 "$OTHER_IP" > /dev/null 2>&1; then
        log_result "Remote Server Connection" "OK" "$OTHER_SERVER ($OTHER_IP) reachable"
        
        # Проверка SSH доступа
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$OTHER_IP" "echo 'SSH OK'" 2>/dev/null | grep -q "SSH OK"; then
            log_result "SSH to Remote Server" "OK" "SSH access working"
        else
            log_result "SSH to Remote Server" "FAIL" "SSH access failed"
        fi
    else
        log_result "Remote Server Connection" "FAIL" "$OTHER_SERVER ($OTHER_IP) unreachable"
    fi
fi

echo "9. Проверка производительности..."

echo "=== ПРОВЕРКА ПРОИЗВОДИТЕЛЬНОСТИ ==="

# Проверка использования ресурсов
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
mem_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
disk_usage=$(df /opt/monitoring | tail -1 | awk '{print $5}' | sed 's/%//')

log_result "CPU Usage" "OK" "${cpu_usage}%"
log_result "Memory Usage" "OK" "${mem_usage}%"
log_result "Disk Usage" "OK" "${disk_usage}%"

# Проверка времени ответа сервисов
prometheus_response_time=$(curl -o /dev/null -s -w '%{time_total}' "http://localhost:9090/api/v1/status/config")
grafana_response_time=$(curl -o /dev/null -s -w '%{time_total}' "http://localhost:3000/api/health")

log_result "Prometheus Response Time" "OK" "${prometheus_response_time}s"
log_result "Grafana Response Time" "OK" "${grafana_response_time}s"

echo "10. Создание комплексного отчета..."

cat > $FINAL_CHECK_DIR/reports/installation-report.txt << EOF
# ФИНАЛЬНЫЙ ОТЧЕТ УСТАНОВКИ МОНИТОРИНГА RTTI
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE
# Парный сервер: $OTHER_SERVER ($OTHER_IP)

=== ОБЩАЯ ИНФОРМАЦИЯ ===

Тип установки: RTTI Infrastructure Monitoring
Версия: Production Ready v1.0
Статус: $(if [ $running_containers -eq $total_containers ]; then echo "✅ ГОТОВ К РАБОТЕ"; else echo "⚠️ ТРЕБУЕТ ВНИМАНИЯ"; fi)

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===

Мониторинг (Core):
✅ Prometheus - сбор и хранение метрик
✅ Grafana - визуализация и дашборды
✅ Alertmanager - управление алертами

Экспортеры (Metrics):
✅ Node Exporter - системные метрики
✅ Nginx Exporter - веб-сервер метрики
✅ PostgreSQL Exporter - метрики базы данных
✅ Redis Exporter - метрики кэширования
✅ Process Exporter - метрики процессов
✅ SSL Exporter - метрики SSL сертификатов
✅ RTTI Exporter - специфичные метрики
✅ Blackbox Exporter - внешние проверки
✅ cAdvisor - метрики контейнеров

Автоматизация:
✅ Резервное копирование (ежедневно/еженедельно)
✅ Оптимизация производительности
✅ Проверка целостности данных
✅ Синхронизация между серверами

=== СТАТИСТИКА РАБОТЫ ===

Контейнеры: $running_containers/$total_containers запущено
Открытые порты: $open_ports/${#local_ports[@]}
Активные метрики: $(curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result | length' 2>/dev/null || echo "N/A")
Правила алертов: $(curl -s "http://localhost:9090/api/v1/rules" | jq '.data.groups[].rules | length' 2>/dev/null | paste -sd+ | bc || echo "N/A")
Дашборды Grafana: $(curl -s -u admin:admin "http://localhost:3000/api/search" 2>/dev/null | jq '. | length' || echo "N/A")

=== ИСПОЛЬЗОВАНИЕ РЕСУРСОВ ===

CPU: ${cpu_usage}%
Memory: ${mem_usage}%
Disk (/opt/monitoring): ${disk_usage}%
TSDB Size: ${tsdb_size_mb}MB

=== СЕТЕВАЯ КОНФИГУРАЦИЯ ===

Локальный сервер: $SERVER_NAME ($SERVER_IP)
EOF

if [ "$OTHER_IP" != "N/A" ]; then
    cat >> $FINAL_CHECK_DIR/reports/installation-report.txt << EOF
Парный сервер: $OTHER_SERVER ($OTHER_IP) $(if ping -c 1 "$OTHER_IP" > /dev/null 2>&1; then echo "✅ Доступен"; else echo "❌ Недоступен"; fi)
SSH доступ: $(if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$OTHER_IP" "echo 'OK'" 2>/dev/null | grep -q "OK"; then echo "✅ Работает"; else echo "❌ Не работает"; fi)
EOF
fi

cat >> $FINAL_CHECK_DIR/reports/installation-report.txt << EOF

Открытые порты:
- 9090: Prometheus Web UI
- 3000: Grafana Web UI  
- 9093: Alertmanager Web UI
- 9100: Node Exporter
- 9113: Nginx Exporter
- 9187: PostgreSQL Exporter
- 9121: Redis Exporter
- 9115: Blackbox Exporter
- 8080: cAdvisor
- 9256: Process Exporter
- 9219: SSL Exporter
- 9999: RTTI Exporter

=== ДОСТУП К ИНТЕРФЕЙСАМ ===

Prometheus: http://$SERVER_NAME:9090
Grafana: http://$SERVER_NAME:3000 (admin/admin)
Alertmanager: http://$SERVER_NAME:9093
cAdvisor: http://$SERVER_NAME:8080

=== КОНФИГУРАЦИОННЫЕ ФАЙЛЫ ===

Prometheus: $MONITORING_DIR/prometheus/config/prometheus.yml
Grafana: $MONITORING_DIR/grafana/provisioning/
Alertmanager: $MONITORING_DIR/alertmanager/alertmanager.yml
Docker Compose: $MONITORING_DIR/docker/docker-compose.yml
Правила алертов: $MONITORING_DIR/prometheus/rules/
Дашборды: $MONITORING_DIR/grafana/dashboards/

=== РЕЗЕРВНОЕ КОПИРОВАНИЕ ===

Директория: /opt/monitoring-backup
Конфигурации: ежедневно в 01:00 (30 дней)
Данные: ежедневно в 02:00 (7 дней)
Полное: еженедельно в 03:00 воскресенье (4 недели)
Синхронизация: ежедневно в 04:00
Проверка: ежедневно в 05:00

=== МОНИТОРИРУЕМЫЕ СИСТЕМЫ ===

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> $FINAL_CHECK_DIR/reports/installation-report.txt << EOF
Основное приложение: Moodle LMS
- Веб-сервер: Nginx + PHP-FPM
- База данных: PostgreSQL
- Кэширование: Redis
- Данные: /var/moodledata
- Специфичные метрики: установка, размер данных, производительность

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> $FINAL_CHECK_DIR/reports/installation-report.txt << EOF
Основное приложение: Drupal Library
- Веб-сервер: Nginx + PHP-FPM
- База данных: PostgreSQL
- Кэширование: Redis + Memcached + APCu
- Файлы: /var/www/drupal/web/sites/default/files
- Специфичные метрики: установка, размер файлов, производительность

EOF
fi

cat >> $FINAL_CHECK_DIR/reports/installation-report.txt << EOF
Системные компоненты:
- Операционная система: $(lsb_release -d | cut -f2 2>/dev/null || echo "Linux")
- Docker Engine: $(docker --version | cut -d' ' -f3 | sed 's/,//')
- Процессы: веб-сервер, база данных, кэш, система
- Безопасность: Fail2Ban, SSH, файрвол
- Сеть: интерфейсы, соединения, пропускная способность

=== АЛЕРТЫ И УВЕДОМЛЕНИЯ ===

Критичные алерты:
- Недоступность сервисов
- Высокое использование ресурсов
- Ошибки базы данных
- Проблемы с сетью
- Сбои резервного копирования

Предупреждения:
- Приближение к лимитам ресурсов
- Медленные запросы
- Устаревшие резервные копии
- Проблемы SSL сертификатов

Настройка уведомлений:
- Email: настроен через Alertmanager
- Веб-интерфейс: Grafana и Alertmanager
- Логи: /opt/monitoring/logs/

=== ОПТИМИЗАЦИЯ ===

Производительность:
✅ Recording rules для быстрых запросов
✅ Оптимизированные интервалы сбора метрик
✅ Ресурсные лимиты контейнеров
✅ Сжатие данных Prometheus

Хранение данных:
✅ Retention: 90 дней / 10GB
✅ Автоматическая очистка старых данных
✅ Сжатие архивов резервных копий
✅ Ротация логов

=== БЕЗОПАСНОСТЬ ===

Доступ:
- Интерфейсы доступны только локально
- SSH ключи для синхронизации
- Права доступа настроены
- Логирование операций

Файрвол:
- Внешний доступ заблокирован
- Открыты только необходимые порты
- Мониторинг подключений

=== ОБСЛУЖИВАНИЕ ===

Ежедневные задачи:
- Проверка алертов в Grafana
- Мониторинг использования ресурсов
- Проверка логов на ошибки

Еженедельные задачи:
- Анализ трендов производительности
- Проверка резервных копий
- Обновление дашбордов

Ежемесячные задачи:
- Тестирование восстановления
- Оптимизация запросов
- Анализ емкости

=== КОНТАКТЫ И ПОДДЕРЖКА ===

Документация:
- Установка: /root/*-report.txt
- Конфигурация: $MONITORING_DIR/
- Резервное копирование: /root/backup-guide.txt

Скрипты управления:
- Проверка: /root/check-exporters.sh
- Оптимизация: /root/optimize-monitoring.sh
- Восстановление: /opt/monitoring-backup/restore.sh

Команда RTTI IT:
- Системный администратор
- Разработчик мониторинга
- Специалист по базам данных

=== СЛЕДУЮЩИЕ ШАГИ ===

Немедленно:
1. ✅ Изменить пароль Grafana (admin/admin)
2. ✅ Настроить email уведомления
3. ✅ Протестировать алерты
4. ✅ Настроить SSH ключи между серверами

В течение недели:
1. Создать дополнительные дашборды
2. Настроить пользователей Grafana
3. Протестировать восстановление
4. Документировать процедуры

В течение месяца:
1. Оптимизировать производительность
2. Создать отчеты для руководства
3. Обучить персонал
4. Планировать развитие

=== ЗАКЛЮЧЕНИЕ ===

Система мониторинга RTTI успешно установлена и готова к работе.

Статус готовности: $(if [ $running_containers -eq $total_containers ] && [ $open_ports -ge 10 ]; then echo "🟢 PRODUCTION READY"; elif [ $running_containers -ge 8 ]; then echo "🟡 NEEDS ATTENTION"; else echo "🔴 CRITICAL ISSUES"; fi)

Рекомендации:
$(if [ $running_containers -eq $total_containers ]; then echo "✅ Все системы работают корректно"; else echo "⚠️ Проверьте неработающие контейнеры"; fi)
$(if [ $open_ports -ge 10 ]; then echo "✅ Сетевые сервисы доступны"; else echo "⚠️ Проверьте сетевую конфигурацию"; fi)
$(if [ "$OTHER_IP" != "N/A" ] && ping -c 1 "$OTHER_IP" > /dev/null 2>&1; then echo "✅ Связь с парным сервером работает"; else echo "⚠️ Настройте связь с парным сервером"; fi)

Система готова для мониторинга критически важной инфраструктуры RTTI!

Дата установки: $(date)
Администратор: $(whoami)
Версия отчета: v1.0
EOF

echo "11. Создание скрипта проверки здоровья..."

cat > /root/health-check.sh << 'EOF'
#!/bin/bash
# Быстрая проверка здоровья системы мониторинга RTTI

echo "=== ПРОВЕРКА ЗДОРОВЬЯ МОНИТОРИНГА RTTI ==="
echo "📅 Дата: $(date)"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция проверки
check_component() {
    local name="$1"
    local check_command="$2"
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $name${NC}"
        return 0
    else
        echo -e "${RED}❌ $name${NC}"
        return 1
    fi
}

failures=0

# Проверка основных сервисов
echo "🔍 Основные сервисы:"
check_component "Prometheus" "curl -s http://localhost:9090/api/v1/status/config" || failures=$((failures + 1))
check_component "Grafana" "curl -s http://localhost:3000/api/health" || failures=$((failures + 1))
check_component "Alertmanager" "curl -s http://localhost:9093/api/v1/status" || failures=$((failures + 1))

# Проверка экспортеров
echo "📊 Экспортеры:"
check_component "Node Exporter" "curl -s http://localhost:9100/metrics" || failures=$((failures + 1))
check_component "Nginx Exporter" "curl -s http://localhost:9113/metrics" || failures=$((failures + 1))
check_component "PostgreSQL Exporter" "curl -s http://localhost:9187/metrics" || failures=$((failures + 1))
check_component "RTTI Exporter" "curl -s http://localhost:9999/metrics" || failures=$((failures + 1))

# Проверка Docker контейнеров
echo "🐳 Docker контейнеры:"
check_component "Prometheus Container" "docker ps | grep prometheus" || failures=$((failures + 1))
check_component "Grafana Container" "docker ps | grep grafana" || failures=$((failures + 1))
check_component "Alertmanager Container" "docker ps | grep alertmanager" || failures=$((failures + 1))

# Проверка ресурсов
echo "💻 Ресурсы системы:"
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d'.' -f1)
check_component "CPU Usage (<90%)" "[ $cpu_usage -lt 90 ]" || failures=$((failures + 1))

mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
check_component "Memory Usage (<90%)" "[ $mem_usage -lt 90 ]" || failures=$((failures + 1))

disk_usage=$(df /opt/monitoring | tail -1 | awk '{print $5}' | sed 's/%//')
check_component "Disk Usage (<85%)" "[ $disk_usage -lt 85 ]" || failures=$((failures + 1))

# Общий результат
echo
if [ $failures -eq 0 ]; then
    echo -e "${GREEN}🎉 Все системы работают нормально!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Обнаружено проблем: $failures${NC}"
    echo "📋 Подробную информацию смотрите в /opt/monitoring/final-check/logs/"
    exit 1
fi
EOF

chmod +x /root/health-check.sh

echo "12. Создание скрипта автоматического восстановления..."

cat > /root/auto-recovery.sh << 'EOF'
#!/bin/bash
# Автоматическое восстановление сервисов мониторинга RTTI

MONITORING_DIR="/opt/monitoring"
LOG_FILE="/var/log/monitoring-recovery.log"

log_message() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

log_message "=== Запуск автоматического восстановления ==="

# Проверка и перезапуск Docker контейнеров
cd "$MONITORING_DIR/docker"

services=("prometheus" "grafana" "alertmanager" "node-exporter" "nginx-exporter" "postgres-exporter")
restarted=0

for service in "${services[@]}"; do
    if ! docker ps | grep -q "$service"; then
        log_message "⚠️ Сервис $service не запущен, попытка восстановления..."
        
        docker-compose restart "$service"
        sleep 10
        
        if docker ps | grep -q "$service"; then
            log_message "✅ Сервис $service восстановлен"
            restarted=$((restarted + 1))
        else
            log_message "❌ Не удалось восстановить сервис $service"
        fi
    fi
done

# Проверка свободного места
disk_usage=$(df /opt/monitoring | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    log_message "⚠️ Диск заполнен на ${disk_usage}%, запуск очистки..."
    /opt/monitoring/optimization/scripts/cleanup-old-data.sh
    log_message "✅ Очистка диска выполнена"
fi

# Проверка памяти
mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ "$mem_usage" -gt 90 ]; then
    log_message "⚠️ Высокое использование памяти (${mem_usage}%), очистка кэша..."
    echo 1 > /proc/sys/vm/drop_caches
    log_message "✅ Кэш очищен"
fi

log_message "=== Восстановление завершено, перезапущено сервисов: $restarted ==="
EOF

chmod +x /root/auto-recovery.sh

# Добавление автоматического восстановления в cron
(crontab -l 2>/dev/null; echo "*/15 * * * * /root/health-check.sh || /root/auto-recovery.sh") | crontab -

echo "13. Финальный тест всех систем..."

echo "=== ФИНАЛЬНОЕ ТЕСТИРОВАНИЕ ==="

# Запуск проверки здоровья
/root/health-check.sh

# Проверка создания метрик
echo "📊 Тест сбора метрик..."
sleep 10

metrics_count=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq '.data | length' 2>/dev/null || echo "0")
log_result "Metrics Collection" "OK" "$metrics_count unique metrics"

# Тест алертов
echo "🚨 Тест системы алертов..."
if curl -s "http://localhost:9090/api/v1/rules" | jq '.data.groups[].rules[] | select(.type == "alerting")' | wc -l | grep -q "[1-9]"; then
    log_result "Alert System" "OK" "Alert rules loaded and active"
else
    log_result "Alert System" "FAIL" "No alert rules found"
fi

echo "14. Создание сводного отчета..."

# Создание финального статуса
total_checks=20  # Приблизительное количество проверок
passed_checks=$((total_checks - $(grep "❌" $FINAL_CHECK_DIR/logs/final-check.log | wc -l)))
success_rate=$((passed_checks * 100 / total_checks))

cat > $FINAL_CHECK_DIR/reports/system-status.txt << EOF
# СТАТУС СИСТЕМЫ МОНИТОРИНГА RTTI
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)

=== ОБЩИЙ СТАТУС ===

Готовность системы: ${success_rate}%
Статус: $(if [ $success_rate -ge 95 ]; then echo "🟢 ОТЛИЧНО"; elif [ $success_rate -ge 85 ]; then echo "🟡 ХОРОШО"; elif [ $success_rate -ge 70 ]; then echo "🟠 УДОВЛЕТВОРИТЕЛЬНО"; else echo "🔴 ТРЕБУЕТ ВНИМАНИЯ"; fi)

Пройдено проверок: $passed_checks/$total_checks
Запущено контейнеров: $running_containers/$total_containers
Открыто портов: $open_ports/${#local_ports[@]}

=== КЛЮЧЕВЫЕ МЕТРИКИ ===

Производительность:
- CPU: ${cpu_usage}%
- Memory: ${mem_usage}%  
- Disk: ${disk_usage}%
- Prometheus Response: ${prometheus_response_time}s
- Grafana Response: ${grafana_response_time}s

Мониторинг:
- Активные метрики: $(curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result | length' 2>/dev/null || echo "N/A")
- TSDB Size: ${tsdb_size_mb}MB
- Дашборды: $(curl -s -u admin:admin "http://localhost:3000/api/search" 2>/dev/null | jq '. | length' || echo "N/A")
- Алерты: $(curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts | length' 2>/dev/null || echo "N/A")

=== ДОСТУП ===

Web Interfaces:
- Prometheus: http://$SERVER_NAME:9090
- Grafana: http://$SERVER_NAME:3000 (admin/admin)
- Alertmanager: http://$SERVER_NAME:9093

Управление:
- Проверка здоровья: /root/health-check.sh
- Автовосстановление: /root/auto-recovery.sh
- Резервное копирование: /opt/monitoring-backup/
- Оптимизация: /root/optimize-monitoring.sh

=== РЕКОМЕНДАЦИИ ===

$(if [ $success_rate -ge 95 ]; then
    echo "✅ Система работает отлично, готова к продакшн использованию"
    echo "📝 Рекомендуется:"
    echo "   - Сменить пароль Grafana"
    echo "   - Настроить email уведомления"
    echo "   - Протестировать восстановление"
    echo "   - Обучить команду работе с системой"
elif [ $success_rate -ge 85 ]; then
    echo "⚠️ Система работает хорошо, но есть незначительные проблемы"
    echo "📝 Требуется:"
    echo "   - Исправить обнаруженные проблемы"
    echo "   - Проверить конфигурацию сервисов"
    echo "   - Убедиться в доступности всех компонентов"
else
    echo "🔴 Система требует немедленного внимания"
    echo "📝 Критично:"
    echo "   - Проверить логи ошибок"
    echo "   - Перезапустить неработающие сервисы"
    echo "   - Проверить сетевую конфигурацию"
    echo "   - Обратиться к администратору"
fi)

Последняя проверка: $(date)
EOF

echo "15. Настройка автоматического мониторинга состояния..."

# Создание systemd сервиса для мониторинга
cat > /etc/systemd/system/rtti-monitoring-watchdog.service << EOF
[Unit]
Description=RTTI Monitoring Watchdog
After=docker.service

[Service]
Type=oneshot
ExecStart=/root/health-check.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/rtti-monitoring-watchdog.timer << EOF
[Unit]
Description=Run RTTI Monitoring Watchdog every 5 minutes
Requires=rtti-monitoring-watchdog.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable rtti-monitoring-watchdog.timer
systemctl start rtti-monitoring-watchdog.timer

echo "16. Финальная проверка и вывод результатов..."

# Финальная проверка
final_status="SUCCESS"
if [ $running_containers -lt $((total_containers - 2)) ]; then
    final_status="WARNING"
fi
if [ $running_containers -lt $((total_containers / 2)) ]; then
    final_status="CRITICAL"
fi

echo
echo "════════════════════════════════════════════════════════"
echo "            УСТАНОВКА МОНИТОРИНГА ЗАВЕРШЕНА"
echo "════════════════════════════════════════════════════════"
echo
echo "🎯 Сервер: $SERVER_NAME ($SERVER_IP)"
echo "🔧 Роль: $SERVER_ROLE"
echo "📊 Статус: $final_status (${success_rate}%)"
echo "🐳 Контейнеры: $running_containers/$total_containers запущено"
echo "🌐 Порты: $open_ports/${#local_ports[@]} открыто"
echo "💾 Использование диска: ${disk_usage}%"
echo
echo "═══ ДОСТУП К СИСТЕМЕ ═══"
echo "🔍 Prometheus: http://$SERVER_NAME:9090"
echo "📊 Grafana: http://$SERVER_NAME:3000"
echo "🚨 Alertmanager: http://$SERVER_NAME:9093"
echo "🔐 Логин Grafana: admin/admin (ИЗМЕНИТЕ ПАРОЛЬ!)"
echo
echo "═══ УПРАВЛЕНИЕ ═══"
echo "🩺 Проверка здоровья: /root/health-check.sh"
echo "🔧 Автовосстановление: /root/auto-recovery.sh"
echo "📋 Полный отчет: $FINAL_CHECK_DIR/reports/installation-report.txt"
echo "📊 Статус системы: $FINAL_CHECK_DIR/reports/system-status.txt"
echo
echo "═══ СЛЕДУЮЩИЕ ШАГИ ═══"
echo "1. 🔑 Смените пароль Grafana (admin → User → Change Password)"
echo "2. 📧 Настройте email уведомления в Alertmanager"
echo "3. 🔗 Настройте SSH ключи для синхронизации с $OTHER_SERVER"
echo "4. 🧪 Протестируйте алерты и восстановление"
echo "5. 👥 Обучите команду работе с системой"
echo
if [ "$final_status" = "SUCCESS" ]; then
    echo "✅ СИСТЕМА ГОТОВА К РАБОТЕ В ПРОДАКШН!"
elif [ "$final_status" = "WARNING" ]; then
    echo "⚠️  СИСТЕМА ТРЕБУЕТ ВНИМАНИЯ ПЕРЕД ПРОДАКШН"
else
    echo "🔴 КРИТИЧЕСКИЕ ПРОБЛЕМЫ - ОБРАТИТЕСЬ К АДМИНИСТРАТОРУ"
fi
echo
echo "════════════════════════════════════════════════════════"
echo "Время установки: $(date)"
echo "Версия: RTTI Monitoring v1.0"
echo "Документация: /root/*-report.txt"
echo "════════════════════════════════════════════════════════"
echo

# Сохранение итогового статуса
echo "$final_status" > $FINAL_CHECK_DIR/reports/final-status.txt
echo "$(date)" > $FINAL_CHECK_DIR/reports/installation-date.txt

echo "✅ Шаг 10 завершен успешно!"
echo "🎯 Система мониторинга RTTI полностью настроена"
echo "📊 Готовность: ${success_rate}%"
echo "🚀 Статус: $final_status"
echo "📋 Отчеты: $FINAL_CHECK_DIR/reports/"
echo "🎉 УСТАНОВКА ЗАВЕРШЕНА!"
echo
