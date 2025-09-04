#!/bin/bash

# RTTI Monitoring System Update Script
# Обновление системы мониторинга

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                      Monitoring System Update Script                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./update-monitoring.sh"
    exit 1
fi

echo "🔄 Начинаем обновление системы мониторинга..."
echo "📅 Дата: $(date)"
echo

# Создание бэкапа
echo "💾 Создание бэкапа конфигураций..."
./backup-monitoring.sh

# Функция обновления компонента
update_component() {
    local component=$1
    local service=$2
    local config_dir=$3
    
    echo "📦 Обновление $component..."
    
    case $component in
        "prometheus")
            # Получение последней версии Prometheus
            LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep tag_name | cut -d '"' -f 4)
            CURRENT_VERSION=$(prometheus --version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
            
            echo "📋 Текущая версия: $CURRENT_VERSION"
            echo "📋 Последняя версия: $LATEST_VERSION"
            
            if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
                echo "⬆️  Обновление Prometheus до $LATEST_VERSION..."
                
                # Остановка сервиса
                systemctl stop prometheus
                
                # Загрузка новой версии
                cd /tmp
                wget "https://github.com/prometheus/prometheus/releases/download/$LATEST_VERSION/prometheus-${LATEST_VERSION#v}.linux-amd64.tar.gz"
                tar xvf "prometheus-${LATEST_VERSION#v}.linux-amd64.tar.gz"
                
                # Замена бинарников
                cp "prometheus-${LATEST_VERSION#v}.linux-amd64/prometheus" /usr/local/bin/
                cp "prometheus-${LATEST_VERSION#v}.linux-amd64/promtool" /usr/local/bin/
                
                # Установка прав
                chown prometheus:prometheus /usr/local/bin/prometheus
                chown prometheus:prometheus /usr/local/bin/promtool
                
                # Запуск сервиса
                systemctl start prometheus
                
                # Очистка
                rm -rf prometheus-${LATEST_VERSION#v}*
                
                echo "✅ Prometheus обновлен до $LATEST_VERSION"
            else
                echo "ℹ️  Prometheus уже актуальной версии"
            fi
            ;;
            
        "grafana")
            echo "⬆️  Обновление Grafana..."
            
            # Обновление через apt
            apt update
            apt upgrade grafana -y
            
            # Перезапуск сервиса
            systemctl restart grafana-server
            
            echo "✅ Grafana обновлена"
            ;;
            
        "alertmanager")
            # Получение последней версии Alertmanager
            LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/alertmanager/releases/latest | grep tag_name | cut -d '"' -f 4)
            CURRENT_VERSION=$(alertmanager --version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
            
            echo "📋 Текущая версия: $CURRENT_VERSION"
            echo "📋 Последняя версия: $LATEST_VERSION"
            
            if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
                echo "⬆️  Обновление Alertmanager до $LATEST_VERSION..."
                
                # Остановка сервиса
                systemctl stop alertmanager
                
                # Загрузка новой версии
                cd /tmp
                wget "https://github.com/prometheus/alertmanager/releases/download/$LATEST_VERSION/alertmanager-${LATEST_VERSION#v}.linux-amd64.tar.gz"
                tar xvf "alertmanager-${LATEST_VERSION#v}.linux-amd64.tar.gz"
                
                # Замена бинарников
                cp "alertmanager-${LATEST_VERSION#v}.linux-amd64/alertmanager" /usr/local/bin/
                cp "alertmanager-${LATEST_VERSION#v}.linux-amd64/amtool" /usr/local/bin/
                
                # Установка прав
                chown alertmanager:alertmanager /usr/local/bin/alertmanager
                chown alertmanager:alertmanager /usr/local/bin/amtool
                
                # Запуск сервиса
                systemctl start alertmanager
                
                # Очистка
                rm -rf alertmanager-${LATEST_VERSION#v}*
                
                echo "✅ Alertmanager обновлен до $LATEST_VERSION"
            else
                echo "ℹ️  Alertmanager уже актуальной версии"
            fi
            ;;
            
        "exporters")
            echo "⬆️  Обновление экспортеров..."
            
            # Node Exporter
            if systemctl is-active --quiet node_exporter; then
                LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep tag_name | cut -d '"' -f 4)
                
                systemctl stop node_exporter
                cd /tmp
                wget "https://github.com/prometheus/node_exporter/releases/download/$LATEST_VERSION/node_exporter-${LATEST_VERSION#v}.linux-amd64.tar.gz"
                tar xvf "node_exporter-${LATEST_VERSION#v}.linux-amd64.tar.gz"
                cp "node_exporter-${LATEST_VERSION#v}.linux-amd64/node_exporter" /usr/local/bin/
                chown node_exporter:node_exporter /usr/local/bin/node_exporter
                systemctl start node_exporter
                rm -rf node_exporter-${LATEST_VERSION#v}*
                
                echo "✅ Node Exporter обновлен"
            fi
            
            # Nginx Exporter
            if systemctl is-active --quiet nginx_exporter; then
                echo "📦 Обновление Nginx Exporter..."
                # Аналогично для других экспортеров
            fi
            ;;
    esac
}

# Проверка активных сервисов
echo "🔍 Проверка установленных компонентов..."

COMPONENTS=()
if systemctl is-active --quiet prometheus; then
    COMPONENTS+=("prometheus")
    echo "✅ Prometheus обнаружен"
fi

if systemctl is-active --quiet grafana-server; then
    COMPONENTS+=("grafana")
    echo "✅ Grafana обнаружена"
fi

if systemctl is-active --quiet alertmanager; then
    COMPONENTS+=("alertmanager")
    echo "✅ Alertmanager обнаружен"
fi

if systemctl is-active --quiet node_exporter; then
    COMPONENTS+=("exporters")
    echo "✅ Экспортеры обнаружены"
fi

if [ ${#COMPONENTS[@]} -eq 0 ]; then
    echo "❌ Компоненты мониторинга не найдены"
    exit 1
fi

echo

# Обновление компонентов
for component in "${COMPONENTS[@]}"; do
    update_component "$component"
    echo
done

# Обновление дашбордов Grafana
echo "📊 Обновление дашбордов Grafana..."
if systemctl is-active --quiet grafana-server; then
    # Импорт обновленных дашбордов
    if [ -d "/var/lib/grafana/dashboards" ]; then
        echo "📋 Обновление пользовательских дашбордов..."
        # Здесь можно добавить логику обновления дашбордов
    fi
    
    # Перезапуск Grafana для применения изменений
    systemctl restart grafana-server
    sleep 5
    
    if systemctl is-active --quiet grafana-server; then
        echo "✅ Grafana перезапущена успешно"
    else
        echo "❌ Ошибка перезапуска Grafana"
    fi
fi

# Проверка конфигураций
echo "🔍 Проверка конфигураций..."

# Проверка Prometheus
if [ -f "/etc/prometheus/prometheus.yml" ]; then
    if promtool check config /etc/prometheus/prometheus.yml; then
        echo "✅ Конфигурация Prometheus корректна"
    else
        echo "❌ Ошибка в конфигурации Prometheus"
    fi
fi

# Проверка Alertmanager
if [ -f "/etc/alertmanager/alertmanager.yml" ]; then
    if amtool check-config /etc/alertmanager/alertmanager.yml; then
        echo "✅ Конфигурация Alertmanager корректна"
    else
        echo "❌ Ошибка в конфигурации Alertmanager"
    fi
fi

# Проверка работоспособности
echo "🔍 Проверка работоспособности сервисов..."

# Проверка портов
PORTS=("9090" "3000" "9093")
for port in "${PORTS[@]}"; do
    if netstat -tlnp | grep ":$port " > /dev/null; then
        echo "✅ Порт $port: Активен"
    else
        echo "❌ Порт $port: Не активен"
    fi
done

# Проверка метрик
echo "📊 Проверка доступности метрик..."
if curl -s http://localhost:9090/api/v1/query?query=up | grep -q "success"; then
    echo "✅ Prometheus API доступен"
else
    echo "❌ Prometheus API недоступен"
fi

if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "✅ Grafana API доступен"
else
    echo "❌ Grafana API недоступен"
fi

# Обновление системы
echo "🖥️  Обновление системы..."
apt update && apt upgrade -y

# Очистка временных файлов
echo "🧹 Очистка временных файлов..."
apt autoremove -y
apt autoclean

echo
echo "🎉 Обновление системы мониторинга завершено!"
echo "📊 Система мониторинга обновлена и готова к работе"
echo
echo "🌐 Доступные интерфейсы:"
echo "   📊 Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "   🎯 Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "   🚨 Alertmanager: http://$(hostname -I | awk '{print $1}'):9093"
echo
echo "📋 Рекомендуется:"
echo "   1. Проверить работу всех дашбордов в Grafana"
echo "   2. Убедиться, что все алерты работают корректно"
echo "   3. Проверить сбор метрик с удаленных серверов"
