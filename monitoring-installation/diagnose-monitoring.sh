#!/bin/bash

# RTTI Monitoring System Diagnostics Script
# Полная диагностика системы мониторинга

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                     Monitoring System Diagnostics                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

echo "📅 Дата диагностики: $(date)"
echo "🖥️  Сервер: $(hostname)"
echo "🌐 IP адрес: $(hostname -I | awk '{print $1}')"
echo

# Функция проверки сервиса
check_service() {
    local service=$1
    local port=$2
    local description=$3
    
    echo "🔍 Проверка $description..."
    
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service: Активен"
        
        # Проверка порта
        if netstat -tlnp | grep ":$port " > /dev/null; then
            echo "✅ Порт $port: Открыт"
        else
            echo "❌ Порт $port: Закрыт"
        fi
        
        # Проверка HTTP ответа
        if curl -s "http://localhost:$port" > /dev/null; then
            echo "✅ HTTP ответ: OK"
        else
            echo "❌ HTTP ответ: Не отвечает"
        fi
    else
        echo "❌ $service: Не активен"
    fi
    echo
}

# Проверка основных компонентов
echo "🔧 ОСНОВНЫЕ КОМПОНЕНТЫ МОНИТОРИНГА"
echo "═══════════════════════════════════════════════════════════════════════════════"

check_service "prometheus" "9090" "Prometheus Server"
check_service "grafana-server" "3000" "Grafana Dashboard"
check_service "alertmanager" "9093" "Alertmanager"

# Проверка экспортеров
echo "📊 ЭКСПОРТЕРЫ МЕТРИК"
echo "═══════════════════════════════════════════════════════════════════════════════"

check_service "node_exporter" "9100" "Node Exporter (системные метрики)"

if systemctl is-active --quiet nginx; then
    check_service "nginx_exporter" "9113" "Nginx Exporter"
fi

if systemctl is-active --quiet postgresql; then
    check_service "postgres_exporter" "9187" "PostgreSQL Exporter"
fi

if systemctl is-active --quiet redis-server; then
    check_service "redis_exporter" "9121" "Redis Exporter"
fi

# Проверка конфигураций
echo "⚙️  КОНФИГУРАЦИИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Prometheus
if [ -f "/etc/prometheus/prometheus.yml" ]; then
    echo "✅ Prometheus config: Найден"
    
    if promtool check config /etc/prometheus/prometheus.yml > /dev/null 2>&1; then
        echo "✅ Prometheus config: Валидный"
    else
        echo "❌ Prometheus config: Ошибки валидации"
        promtool check config /etc/prometheus/prometheus.yml 2>&1 | head -5
    fi
    
    # Количество целей
    TARGETS=$(grep -E "targets:" /etc/prometheus/prometheus.yml | wc -l)
    echo "🎯 Целей мониторинга: $TARGETS"
else
    echo "❌ Prometheus config: Не найден"
fi

# Grafana
if [ -f "/etc/grafana/grafana.ini" ]; then
    echo "✅ Grafana config: Найден"
    
    # Проверка основных настроек
    HTTP_PORT=$(grep "http_port" /etc/grafana/grafana.ini | cut -d'=' -f2 | xargs)
    DOMAIN=$(grep "domain" /etc/grafana/grafana.ini | cut -d'=' -f2 | xargs)
    
    echo "🌐 Grafana порт: ${HTTP_PORT:-3000}"
    echo "🌍 Grafana домен: ${DOMAIN:-localhost}"
else
    echo "❌ Grafana config: Не найден"
fi

# Alertmanager
if [ -f "/etc/alertmanager/alertmanager.yml" ]; then
    echo "✅ Alertmanager config: Найден"
    
    if amtool check-config /etc/alertmanager/alertmanager.yml > /dev/null 2>&1; then
        echo "✅ Alertmanager config: Валидный"
    else
        echo "❌ Alertmanager config: Ошибки валидации"
    fi
else
    echo "❌ Alertmanager config: Не найден"
fi
echo

# Проверка данных
echo "📊 ДАННЫЕ И МЕТРИКИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Prometheus данные
if [ -d "/var/lib/prometheus" ]; then
    PROMETHEUS_SIZE=$(du -sh /var/lib/prometheus | awk '{print $1}')
    echo "📈 Размер данных Prometheus: $PROMETHEUS_SIZE"
    
    # Количество серий
    if curl -s http://localhost:9090/api/v1/query?query=prometheus_tsdb_symbol_table_size_bytes > /dev/null; then
        SERIES_COUNT=$(curl -s "http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "Unknown")
        echo "📊 Временных рядов: $SERIES_COUNT"
    fi
else
    echo "❌ Данные Prometheus не найдены"
fi

# Grafana данные
if [ -d "/var/lib/grafana" ]; then
    GRAFANA_SIZE=$(du -sh /var/lib/grafana | awk '{print $1}')
    echo "📊 Размер данных Grafana: $GRAFANA_SIZE"
    
    # Количество дашбордов
    if [ -f "/var/lib/grafana/grafana.db" ]; then
        DASHBOARD_COUNT=$(sqlite3 /var/lib/grafana/grafana.db "SELECT COUNT(*) FROM dashboard;" 2>/dev/null || echo "Unknown")
        echo "📋 Дашбордов: $DASHBOARD_COUNT"
    fi
else
    echo "❌ Данные Grafana не найдены"
fi
echo

# Проверка подключений и целей
echo "🎯 ЦЕЛИ МОНИТОРИНГА"
echo "═══════════════════════════════════════════════════════════════════════════════"

if curl -s http://localhost:9090/api/v1/targets > /dev/null; then
    echo "📡 Получение статуса целей..."
    
    # Получение статуса через API
    TARGETS_JSON=$(curl -s http://localhost:9090/api/v1/targets)
    
    if command -v jq > /dev/null; then
        UP_TARGETS=$(echo "$TARGETS_JSON" | jq '.data.activeTargets[] | select(.health=="up") | .labels.instance' 2>/dev/null | wc -l)
        DOWN_TARGETS=$(echo "$TARGETS_JSON" | jq '.data.activeTargets[] | select(.health=="down") | .labels.instance' 2>/dev/null | wc -l)
        
        echo "✅ Активных целей: $UP_TARGETS"
        echo "❌ Недоступных целей: $DOWN_TARGETS"
        
        if [ "$DOWN_TARGETS" -gt 0 ]; then
            echo "⚠️  Недоступные цели:"
            echo "$TARGETS_JSON" | jq -r '.data.activeTargets[] | select(.health=="down") | "   - " + .labels.instance + " (" + .labels.job + ")"' 2>/dev/null
        fi
    else
        echo "ℹ️  Установите jq для детального анализа целей"
    fi
else
    echo "❌ Не удалось получить статус целей"
fi
echo

# Проверка алертов
echo "🚨 СИСТЕМА АЛЕРТОВ"
echo "═══════════════════════════════════════════════════════════════════════════════"

if curl -s http://localhost:9090/api/v1/rules > /dev/null; then
    RULES_JSON=$(curl -s http://localhost:9090/api/v1/rules)
    
    if command -v jq > /dev/null; then
        TOTAL_RULES=$(echo "$RULES_JSON" | jq '.data.groups[].rules | length' 2>/dev/null | awk '{sum+=$1} END {print sum}')
        ACTIVE_ALERTS=$(echo "$RULES_JSON" | jq '.data.groups[].rules[] | select(.type=="alerting" and .alerts) | .alerts | length' 2>/dev/null | awk '{sum+=$1} END {print sum}')
        
        echo "📋 Правил алертов: ${TOTAL_RULES:-0}"
        echo "🔥 Активных алертов: ${ACTIVE_ALERTS:-0}"
        
        if [ "${ACTIVE_ALERTS:-0}" -gt 0 ]; then
            echo "⚠️  Активные алерты:"
            echo "$RULES_JSON" | jq -r '.data.groups[].rules[] | select(.type=="alerting" and .alerts) | .alerts[] | "   - " + .labels.alertname + " (" + .state + ")"' 2>/dev/null
        fi
    fi
else
    echo "❌ Не удалось получить правила алертов"
fi

# Проверка Alertmanager
if curl -s http://localhost:9093/api/v1/status > /dev/null; then
    echo "✅ Alertmanager API доступен"
    
    # Получение статуса алертов
    ALERTS_JSON=$(curl -s http://localhost:9093/api/v1/alerts)
    if command -v jq > /dev/null; then
        FIRING_ALERTS=$(echo "$ALERTS_JSON" | jq '.data[] | select(.status.state=="active")' 2>/dev/null | wc -l)
        echo "🔥 Срабатывающих алертов: $FIRING_ALERTS"
    fi
else
    echo "❌ Alertmanager API недоступен"
fi
echo

# Проверка производительности
echo "⚡ ПРОИЗВОДИТЕЛЬНОСТЬ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Использование ресурсов
echo "💾 Использование памяти процессами:"
ps aux | grep -E "(prometheus|grafana|alertmanager)" | grep -v grep | awk '{print "   " $11 ": " $4 "% RAM, " $3 "% CPU"}'

# Использование диска
DISK_USAGE=$(df /var/lib | awk 'NR==2 {print $5}')
echo "💽 Использование диска /var/lib: $DISK_USAGE"

# Сетевые подключения
PROMETHEUS_CONN=$(netstat -an | grep :9090 | grep ESTABLISHED | wc -l)
GRAFANA_CONN=$(netstat -an | grep :3000 | grep ESTABLISHED | wc -l)

echo "🌐 Активных подключений к Prometheus: $PROMETHEUS_CONN"
echo "🌐 Активных подключений к Grafana: $GRAFANA_CONN"
echo

# Проверка логов
echo "📋 ЛОГИ И ОШИБКИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Последние ошибки в логах
echo "🔍 Последние ошибки в системных логах:"

for service in prometheus grafana-server alertmanager; do
    if systemctl is-active --quiet "$service"; then
        ERROR_COUNT=$(journalctl -u "$service" --since="24 hours ago" | grep -i error | wc -l)
        echo "   $service: $ERROR_COUNT ошибок за последние 24 часа"
        
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo "   Последние ошибки:"
            journalctl -u "$service" --since="24 hours ago" | grep -i error | tail -3 | sed 's/^/     /'
        fi
    fi
done
echo

# Рекомендации
echo "💡 РЕКОМЕНДАЦИИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Проверка доступного места
AVAILABLE_SPACE=$(df /var/lib | awk 'NR==2 {print $4}')
TOTAL_SPACE=$(df /var/lib | awk 'NR==2 {print $2}')
USAGE_PERCENT=$(echo "scale=2; $AVAILABLE_SPACE * 100 / $TOTAL_SPACE" | bc 2>/dev/null || echo "Unknown")

if [ ! -z "$USAGE_PERCENT" ] && [ "$(echo "$USAGE_PERCENT > 90" | bc 2>/dev/null)" = "1" ]; then
    echo "⚠️  Мало места на диске - рекомендуется очистка старых данных"
fi

# Проверка версий
echo "📦 Рекомендуется проверить обновления:"
echo "   sudo ./update-monitoring.sh"

# Проверка бэкапов
if [ -d "/var/backups/monitoring" ]; then
    LATEST_BACKUP=$(ls -t /var/backups/monitoring/monitoring_backup_*.tar.gz 2>/dev/null | head -1)
    if [ ! -z "$LATEST_BACKUP" ]; then
        BACKUP_AGE=$(stat -c %Y "$LATEST_BACKUP")
        CURRENT_TIME=$(date +%s)
        AGE_DAYS=$(( (CURRENT_TIME - BACKUP_AGE) / 86400 ))
        
        if [ "$AGE_DAYS" -gt 7 ]; then
            echo "⚠️  Последний бэкап создан $AGE_DAYS дней назад - рекомендуется создать новый"
            echo "   sudo ./backup-monitoring.sh"
        else
            echo "✅ Последний бэкап создан $AGE_DAYS дней назад"
        fi
    else
        echo "⚠️  Бэкапы не найдены - рекомендуется создать:"
        echo "   sudo ./backup-monitoring.sh"
    fi
else
    echo "⚠️  Директория бэкапов не найдена"
fi

echo
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                           Диагностика завершена                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "🌐 Веб-интерфейсы:"
echo "   📊 Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "   🎯 Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "   🚨 Alertmanager: http://$(hostname -I | awk '{print $1}'):9093"
echo
echo "📋 Полезные команды:"
echo "   journalctl -u prometheus -f     # Логи Prometheus в реальном времени"
echo "   journalctl -u grafana-server -f # Логи Grafana в реальном времени"
echo "   promtool query instant 'up'     # Проверка доступности целей"
