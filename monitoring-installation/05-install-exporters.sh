#!/bin/bash

# 05-install-exporters.sh
# Установка экспортеров метрик для системы мониторинга RTTI
# Серверы: lms.rtti.tj (92.242.60.172), library.rtti.tj (92.242.61.204)

set -e

echo "=== RTTI Monitoring - Шаг 5: Установка экспортеров ==="
echo "📊 Установка экспортеров метрик для мониторинга"
echo "📅 Дата: $(date)"
echo

# Определение роли сервера по IP
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

echo "🔍 Сервер: $SERVER_ROLE ($SERVER_NAME - $SERVER_IP)"
echo

# Функция установки Node Exporter
install_node_exporter() {
    echo "Установка Node Exporter..."
    
    NODE_EXPORTER_VERSION="1.6.1"
    NODE_EXPORTER_USER="node_exporter"
    
    # Создание пользователя
    sudo useradd --no-create-home --shell /bin/false $NODE_EXPORTER_USER || true
    
    # Загрузка и установка
    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
    tar xzf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
    sudo cp node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin/
    sudo chown $NODE_EXPORTER_USER:$NODE_EXPORTER_USER /usr/local/bin/node_exporter
    
    # Создание systemd service
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
Group=$NODE_EXPORTER_USER
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
    
    # Очистка
    rm -rf /tmp/node_exporter-$NODE_EXPORTER_VERSION*
    
    # Запуск службы
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
    
    echo "✅ Node Exporter установлен (порт 9100)"
}

# Функция установки Nginx Exporter (если nginx установлен)
install_nginx_exporter() {
    if ! command -v nginx &> /dev/null; then
        echo "⚠️ Nginx не установлен, пропускаем Nginx Exporter"
        return
    fi
    
    echo "Установка Nginx Exporter..."
    
    # Включение модуля статистики в nginx
    echo "Настройка nginx status для $SERVER_ROLE сервера..."
    
    # Создание конфигурации в зависимости от роли сервера
    if [[ "$SERVER_ROLE" == "moodle" ]]; then
        # Для Moodle сервера (lms.rtti.tj)
        sudo tee /etc/nginx/conf.d/status.conf > /dev/null <<EOF
server {
    listen 8080;
    server_name $SERVER_NAME localhost;
    
    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        allow $SERVER_IP;
        allow 92.242.61.204;  # Разрешить мониторинг с Drupal сервера
        deny all;
    }
}
EOF
    elif [[ "$SERVER_ROLE" == "drupal" ]]; then
        # Для Drupal сервера (library.rtti.tj)
        sudo tee /etc/nginx/conf.d/status.conf > /dev/null <<EOF
server {
    listen 8080;
    server_name $SERVER_NAME localhost;
    
    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        allow $SERVER_IP;
        allow 92.242.60.172;  # Разрешить мониторинг с Moodle сервера
        deny all;
    }
}
EOF
    else
        # Для standalone сервера
        sudo tee /etc/nginx/conf.d/status.conf > /dev/null <<EOF
server {
    listen 8080;
    server_name localhost;
    
    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
EOF
    fi
    
    sudo nginx -t && sudo systemctl reload nginx
    
    # Установка nginx-prometheus-exporter
    NGINX_EXPORTER_VERSION="0.11.0"
    cd /tmp
    wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v$NGINX_EXPORTER_VERSION/nginx-prometheus-exporter_${NGINX_EXPORTER_VERSION}_linux_amd64.tar.gz
    tar xzf nginx-prometheus-exporter_${NGINX_EXPORTER_VERSION}_linux_amd64.tar.gz
    sudo cp nginx-prometheus-exporter /usr/local/bin/
    
    # Создание пользователя и service
    sudo useradd --no-create-home --shell /bin/false nginx_exporter || true
    sudo chown nginx_exporter:nginx_exporter /usr/local/bin/nginx-prometheus-exporter
    
    sudo tee /etc/systemd/system/nginx_exporter.service > /dev/null <<EOF
[Unit]
Description=Nginx Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=nginx_exporter
Group=nginx_exporter
Type=simple
ExecStart=/usr/local/bin/nginx-prometheus-exporter -nginx.scrape-uri=http://localhost:8080/nginx_status

[Install]
WantedBy=multi-user.target
EOF
    
    rm -rf /tmp/nginx-prometheus-exporter*
    
    sudo systemctl daemon-reload
    sudo systemctl enable nginx_exporter
    sudo systemctl start nginx_exporter
    
    echo "✅ Nginx Exporter установлен (порт 9113)"
}

# Функция установки PostgreSQL Exporter (если postgresql установлен)
install_postgres_exporter() {
    if ! command -v psql &> /dev/null; then
        echo "⚠️ PostgreSQL не установлен, пропускаем PostgreSQL Exporter"
        return
    fi
    
    echo "Установка PostgreSQL Exporter..."
    
    POSTGRES_EXPORTER_VERSION="0.13.2"
    cd /tmp
    wget https://github.com/prometheus-community/postgres_exporter/releases/download/v$POSTGRES_EXPORTER_VERSION/postgres_exporter-$POSTGRES_EXPORTER_VERSION.linux-amd64.tar.gz
    tar xzf postgres_exporter-$POSTGRES_EXPORTER_VERSION.linux-amd64.tar.gz
    sudo cp postgres_exporter-$POSTGRES_EXPORTER_VERSION.linux-amd64/postgres_exporter /usr/local/bin/
    
    # Создание пользователя
    sudo useradd --no-create-home --shell /bin/false postgres_exporter || true
    sudo chown postgres_exporter:postgres_exporter /usr/local/bin/postgres_exporter
    
    # Создание конфигурации подключения к PostgreSQL
    echo "Создание конфигурации для PostgreSQL..."
    
    # Получение пароля PostgreSQL из существующих конфигураций
    if [[ "$SERVER_ROLE" == "moodle" ]]; then
        # Для Moodle сервера извлекаем пароль из config.php
        if [ -f "/var/www/html/moodle/config.php" ]; then
            DB_PASSWORD=$(grep "dbpass" /var/www/html/moodle/config.php | cut -d"'" -f4)
            DB_NAME="moodle"
        else
            DB_PASSWORD="moodle_password"
            DB_NAME="moodle"
        fi
    elif [[ "$SERVER_ROLE" == "drupal" ]]; then
        # Для Drupal сервера извлекаем пароль из settings.php
        if [ -f "/var/www/html/drupal/web/sites/default/settings.php" ]; then
            DB_PASSWORD=$(grep "password" /var/www/html/drupal/web/sites/default/settings.php | head -1 | cut -d"'" -f4)
            DB_NAME="drupal"
        else
            DB_PASSWORD="drupal_password"
            DB_NAME="drupal"
        fi
    else
        DB_PASSWORD="postgres"
        DB_NAME="postgres"
    fi
    
    sudo tee /etc/postgres_exporter.env > /dev/null <<EOF
DATA_SOURCE_NAME="postgresql://postgres:$DB_PASSWORD@localhost:5432/$DB_NAME?sslmode=disable"
EOF
    
    sudo chown postgres_exporter:postgres_exporter /etc/postgres_exporter.env
    sudo chmod 600 /etc/postgres_exporter.env
    
    # Создание systemd service
    sudo tee /etc/systemd/system/postgres_exporter.service > /dev/null <<EOF
[Unit]
Description=PostgreSQL Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
Type=simple
EnvironmentFile=/etc/postgres_exporter.env
ExecStart=/usr/local/bin/postgres_exporter

[Install]
WantedBy=multi-user.target
EOF
    
    rm -rf /tmp/postgres_exporter-$POSTGRES_EXPORTER_VERSION*
    
    sudo systemctl daemon-reload
    sudo systemctl enable postgres_exporter
    sudo systemctl start postgres_exporter
    
    echo "✅ PostgreSQL Exporter установлен (порт 9187)"
}

# Функция установки Redis Exporter (если redis установлен)
install_redis_exporter() {
    if ! command -v redis-cli &> /dev/null; then
        echo "⚠️ Redis не установлен, пропускаем Redis Exporter"
        return
    fi
    
    echo "Установка Redis Exporter..."
    
    REDIS_EXPORTER_VERSION="1.53.0"
    cd /tmp
    wget https://github.com/oliver006/redis_exporter/releases/download/v$REDIS_EXPORTER_VERSION/redis_exporter-v$REDIS_EXPORTER_VERSION.linux-amd64.tar.gz
    tar xzf redis_exporter-v$REDIS_EXPORTER_VERSION.linux-amd64.tar.gz
    sudo cp redis_exporter-v$REDIS_EXPORTER_VERSION.linux-amd64/redis_exporter /usr/local/bin/
    
    # Создание пользователя
    sudo useradd --no-create-home --shell /bin/false redis_exporter || true
    sudo chown redis_exporter:redis_exporter /usr/local/bin/redis_exporter
    
    # Создание systemd service
    sudo tee /etc/systemd/system/redis_exporter.service > /dev/null <<EOF
[Unit]
Description=Redis Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=redis_exporter
Group=redis_exporter
Type=simple
ExecStart=/usr/local/bin/redis_exporter

[Install]
WantedBy=multi-user.target
EOF
    
    rm -rf /tmp/redis_exporter-v$REDIS_EXPORTER_VERSION*
    
    sudo systemctl daemon-reload
    sudo systemctl enable redis_exporter
    sudo systemctl start redis_exporter
    
    echo "✅ Redis Exporter установлен (порт 9121)"
}

# Основной процесс установки
echo "🚀 Начинаем установку экспортеров для $SERVER_ROLE сервера..."
echo "📊 IP: $SERVER_IP, Домен: $SERVER_NAME"
echo

# Установка экспортеров
install_node_exporter
install_nginx_exporter
install_postgres_exporter
install_redis_exporter

echo "🔍 Проверка статуса всех экспортеров..."
sleep 5

# Проверка Node Exporter (обязательный для всех серверов)
if curl -s http://localhost:9100/metrics > /dev/null; then
    echo "✅ Node Exporter работает корректно на $SERVER_IP:9100"
else
    echo "❌ Проблема с Node Exporter на $SERVER_IP"
fi

# Проверка других экспортеров с учетом роли сервера
for port in 9113 9187 9121; do
    if curl -s http://localhost:$port/metrics > /dev/null 2>&1; then
        case $port in
            9113) service_name="Nginx Exporter" ;;
            9187) service_name="PostgreSQL Exporter" ;;
            9121) service_name="Redis Exporter" ;;
        esac
        echo "✅ $service_name работает корректно на $SERVER_IP:$port"
    else
        case $port in
            9113) service_name="Nginx Exporter" ;;
            9187) service_name="PostgreSQL Exporter" ;;
            9121) service_name="Redis Exporter" ;;
        esac
        echo "⚠️ $service_name недоступен на $SERVER_IP:$port (возможно, соответствующий сервис не установлен)"
    fi
done

echo
echo "=== Установка экспортеров завершена ==="
echo "🎯 Сервер: $SERVER_ROLE ($SERVER_NAME - $SERVER_IP)"
echo "📊 Доступные экспортеры:"
echo "   - Node Exporter: http://$SERVER_IP:9100/metrics"
echo "   - Nginx Exporter: http://$SERVER_IP:9113/metrics (если nginx установлен)"
echo "   - PostgreSQL Exporter: http://$SERVER_IP:9187/metrics (если postgres установлен)"
echo "   - Redis Exporter: http://$SERVER_IP:9121/metrics (если redis установлен)"
echo
echo "🔗 Для внешнего мониторинга используйте:"
if [[ "$SERVER_ROLE" == "moodle" ]]; then
    echo "   - lms.rtti.tj:9100/metrics"
elif [[ "$SERVER_ROLE" == "drupal" ]]; then
    echo "   - library.rtti.tj:9100/metrics"
fi
echo
