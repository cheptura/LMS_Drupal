#!/bin/bash

# RTTI Remote Monitoring Agents Installation
# Установка агентов мониторинга на удаленные серверы

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    Remote Monitoring Agents Installer                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./install-remote-agents.sh [IP_ADDRESS]"
    exit 1
fi

# Получение IP адреса удаленного сервера
REMOTE_IP=$1
if [ -z "$REMOTE_IP" ]; then
    read -p "📝 Введите IP адрес удаленного сервера: " REMOTE_IP
fi

if [ -z "$REMOTE_IP" ]; then
    echo "❌ IP адрес не указан"
    exit 1
fi

MONITORING_SERVER=$(hostname -I | awk '{print $1}')

echo "📊 Установка агентов мониторинга..."
echo "🎯 Удаленный сервер: $REMOTE_IP"
echo "📡 Сервер мониторинга: $MONITORING_SERVER"
echo "📅 Дата: $(date)"
echo

# Функция установки агента через SSH
install_remote_agent() {
    local remote_ip=$1
    local agent_name=$2
    local port=$3
    
    echo "📦 Установка $agent_name на $remote_ip..."
    
    # Создание скрипта установки
    cat > "/tmp/install_${agent_name}.sh" << EOF
#!/bin/bash

# Обновление системы
apt update

# Установка $agent_name
case "$agent_name" in
    "node_exporter")
        # Node Exporter
        wget https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-*linux-amd64.tar.gz
        tar xvfz node_exporter-*linux-amd64.tar.gz
        mv node_exporter-*linux-amd64/node_exporter /usr/local/bin/
        rm -rf node_exporter-*
        
        # Создание пользователя
        useradd --no-create-home --shell /bin/false node_exporter
        
        # Создание systemd сервиса
        cat > /etc/systemd/system/node_exporter.service << EOL
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOL
        
        systemctl daemon-reload
        systemctl enable node_exporter
        systemctl start node_exporter
        ;;
        
    "nginx_exporter")
        # Nginx Exporter
        if systemctl is-active --quiet nginx; then
            # Включение stub_status в Nginx
            cat > /etc/nginx/sites-available/nginx-status << EOL
server {
    listen 127.0.0.1:8080;
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOL
            ln -sf /etc/nginx/sites-available/nginx-status /etc/nginx/sites-enabled/
            nginx -t && systemctl reload nginx
            
            # Установка Nginx Exporter
            wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/latest/download/nginx-prometheus-exporter_linux_amd64.tar.gz
            tar xvfz nginx-prometheus-exporter_linux_amd64.tar.gz
            mv nginx-prometheus-exporter /usr/local/bin/
            rm nginx-prometheus-exporter_linux_amd64.tar.gz
            
            # Создание systemd сервиса
            cat > /etc/systemd/system/nginx_exporter.service << EOL
[Unit]
Description=Nginx Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=nobody
Group=nogroup
Type=simple
ExecStart=/usr/local/bin/nginx-prometheus-exporter -nginx.scrape-uri=http://127.0.0.1:8080/nginx_status

[Install]
WantedBy=multi-user.target
EOL
            
            systemctl daemon-reload
            systemctl enable nginx_exporter
            systemctl start nginx_exporter
        fi
        ;;
        
    "postgres_exporter")
        # PostgreSQL Exporter
        if systemctl is-active --quiet postgresql; then
            wget https://github.com/prometheus-community/postgres_exporter/releases/latest/download/postgres_exporter-*linux-amd64.tar.gz
            tar xvfz postgres_exporter-*linux-amd64.tar.gz
            mv postgres_exporter-*linux-amd64/postgres_exporter /usr/local/bin/
            rm -rf postgres_exporter-*
            
            # Создание пользователя для мониторинга
            sudo -u postgres createuser --no-createdb --no-createrole --no-superuser postgres_exporter || true
            
            # Создание systemd сервиса
            cat > /etc/systemd/system/postgres_exporter.service << EOL
[Unit]
Description=PostgreSQL Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=postgres
Group=postgres
Type=simple
Environment=DATA_SOURCE_NAME="postgresql://postgres_exporter@localhost:5432/postgres?sslmode=disable"
ExecStart=/usr/local/bin/postgres_exporter

[Install]
WantedBy=multi-user.target
EOL
            
            systemctl daemon-reload
            systemctl enable postgres_exporter
            systemctl start postgres_exporter
        fi
        ;;
esac

# Настройка файрвола
ufw allow $port/tcp

echo "✅ $agent_name установлен и запущен на порту $port"
EOF

    # Копирование и выполнение скрипта на удаленном сервере
    scp "/tmp/install_${agent_name}.sh" "root@$remote_ip:/tmp/"
    ssh "root@$remote_ip" "chmod +x /tmp/install_${agent_name}.sh && /tmp/install_${agent_name}.sh"
    
    # Проверка установки
    if ssh "root@$remote_ip" "systemctl is-active --quiet $agent_name"; then
        echo "✅ $agent_name успешно установлен на $remote_ip"
    else
        echo "❌ Ошибка установки $agent_name на $remote_ip"
    fi
}

# Проверка доступности удаленного сервера
echo "🔍 Проверка доступности сервера $REMOTE_IP..."
if ! ping -c 3 "$REMOTE_IP" > /dev/null; then
    echo "❌ Сервер $REMOTE_IP недоступен"
    exit 1
fi

if ! ssh -o ConnectTimeout=5 "root@$REMOTE_IP" "echo 'SSH подключение успешно'" > /dev/null 2>&1; then
    echo "❌ SSH подключение к $REMOTE_IP недоступно"
    echo "🔧 Убедитесь, что:"
    echo "   1. SSH ключи настроены"
    echo "   2. Root доступ разрешен"
    echo "   3. Порт 22 открыт"
    exit 1
fi

echo "✅ Сервер $REMOTE_IP доступен"
echo

# Определение типа сервера
echo "🔍 Определение установленных сервисов на $REMOTE_IP..."
SERVICES_INFO=$(ssh "root@$REMOTE_IP" "systemctl list-units --type=service --state=active --no-pager | grep -E '(nginx|postgresql|redis|apache|mysql)' || true")

if echo "$SERVICES_INFO" | grep -q nginx; then
    NGINX_DETECTED=true
    echo "🌐 Обнаружен Nginx"
fi

if echo "$SERVICES_INFO" | grep -q postgresql; then
    POSTGRES_DETECTED=true
    echo "🗄️  Обнаружен PostgreSQL"
fi

if echo "$SERVICES_INFO" | grep -q redis; then
    REDIS_DETECTED=true
    echo "🔄 Обнаружен Redis"
fi

echo

# Установка базовых агентов
echo "📦 Установка базовых агентов мониторинга..."

# Node Exporter (системные метрики) - обязательно для всех серверов
install_remote_agent "$REMOTE_IP" "node_exporter" "9100"

# Nginx Exporter - если обнаружен Nginx
if [ "$NGINX_DETECTED" = true ]; then
    install_remote_agent "$REMOTE_IP" "nginx_exporter" "9113"
fi

# PostgreSQL Exporter - если обнаружен PostgreSQL
if [ "$POSTGRES_DETECTED" = true ]; then
    install_remote_agent "$REMOTE_IP" "postgres_exporter" "9187"
fi

# Обновление конфигурации Prometheus
echo "⚙️  Обновление конфигурации Prometheus..."

PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"
TEMP_CONFIG="/tmp/prometheus_update.yml"

# Создание бэкапа
cp "$PROMETHEUS_CONFIG" "$PROMETHEUS_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"

# Добавление новых целей
cat > "$TEMP_CONFIG" << EOF
# Добавление удаленного сервера $REMOTE_IP
  - job_name: 'node-$REMOTE_IP'
    static_configs:
      - targets: ['$REMOTE_IP:9100']
        labels:
          instance: 'server-$REMOTE_IP'
          type: 'node'
EOF

if [ "$NGINX_DETECTED" = true ]; then
    cat >> "$TEMP_CONFIG" << EOF

  - job_name: 'nginx-$REMOTE_IP'
    static_configs:
      - targets: ['$REMOTE_IP:9113']
        labels:
          instance: 'nginx-$REMOTE_IP'
          type: 'nginx'
EOF
fi

if [ "$POSTGRES_DETECTED" = true ]; then
    cat >> "$TEMP_CONFIG" << EOF

  - job_name: 'postgres-$REMOTE_IP'
    static_configs:
      - targets: ['$REMOTE_IP:9187']
        labels:
          instance: 'postgres-$REMOTE_IP'
          type: 'postgres'
EOF
fi

# Добавление в основной конфиг
if ! grep -q "server-$REMOTE_IP" "$PROMETHEUS_CONFIG"; then
    # Найти секцию scrape_configs и добавить новые задания
    sed -i "/scrape_configs:/r $TEMP_CONFIG" "$PROMETHEUS_CONFIG"
    echo "✅ Prometheus конфигурация обновлена"
else
    echo "ℹ️  Сервер $REMOTE_IP уже есть в конфигурации"
fi

rm "$TEMP_CONFIG"

# Перезагрузка Prometheus
echo "🔄 Перезагрузка Prometheus..."
systemctl reload prometheus

# Проверка подключения
echo "🔍 Проверка подключения к агентам..."
sleep 5

curl -s "http://$REMOTE_IP:9100/metrics" | head -1 > /dev/null && echo "✅ Node Exporter доступен" || echo "❌ Node Exporter недоступен"

if [ "$NGINX_DETECTED" = true ]; then
    curl -s "http://$REMOTE_IP:9113/metrics" | head -1 > /dev/null && echo "✅ Nginx Exporter доступен" || echo "❌ Nginx Exporter недоступен"
fi

if [ "$POSTGRES_DETECTED" = true ]; then
    curl -s "http://$REMOTE_IP:9187/metrics" | head -1 > /dev/null && echo "✅ PostgreSQL Exporter доступен" || echo "❌ PostgreSQL Exporter недоступен"
fi

echo
echo "🎉 Установка агентов мониторинга завершена!"
echo "📊 Удаленный сервер $REMOTE_IP добавлен в систему мониторинга"
echo "🌐 Проверьте метрики в Grafana: http://$MONITORING_SERVER:3000"
echo
echo "📋 Установленные агенты:"
echo "   • Node Exporter (порт 9100) - системные метрики"
[ "$NGINX_DETECTED" = true ] && echo "   • Nginx Exporter (порт 9113) - метрики веб-сервера"
[ "$POSTGRES_DETECTED" = true ] && echo "   • PostgreSQL Exporter (порт 9187) - метрики базы данных"
echo
echo "🔧 Для удаления агентов используйте:"
echo "   ssh root@$REMOTE_IP 'systemctl stop node_exporter && systemctl disable node_exporter'"
