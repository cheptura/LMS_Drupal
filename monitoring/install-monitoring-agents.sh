#!/bin/bash
# Установка агентов мониторинга для существующих серверов Moodle/Drupal
# Поддерживает Node Exporter (Prometheus) и Zabbix Agent

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
NODE_EXPORTER_VERSION="1.6.1"
MONITORING_USER="monitoring"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен запускаться с правами root"
   exit 1
fi

info "🚀 Установка агентов мониторинга для серверов RTTI LMS"

# Выбор типа мониторинга
select_monitoring_type() {
    echo ""
    info "Выберите тип мониторинга для установки:"
    echo "1) Node Exporter (для Prometheus)"
    echo "2) Zabbix Agent"
    echo "3) Оба (Node Exporter + Zabbix Agent)"
    echo ""
    read -p "Введите номер (1-3): " choice
    
    case $choice in
        1) INSTALL_TYPE="node_exporter" ;;
        2) INSTALL_TYPE="zabbix_agent" ;;
        3) INSTALL_TYPE="both" ;;
        *) error "Неверный выбор"; exit 1 ;;
    esac
    
    log "Выбран тип установки: $INSTALL_TYPE"
}

# Получение конфигурации серверов мониторинга
get_monitoring_servers() {
    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        read -p "IP адрес Prometheus сервера: " PROMETHEUS_SERVER
    fi
    
    if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        read -p "IP адрес Zabbix сервера: " ZABBIX_SERVER
    fi
}

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
        ca-certificates \
        gnupg
}

# Установка Node Exporter
install_node_exporter() {
    log "Установка Node Exporter $NODE_EXPORTER_VERSION..."
    
    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    
    mkdir -p /opt/node_exporter
    cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /opt/node_exporter/
    chown -R $MONITORING_USER:$MONITORING_USER /opt/node_exporter
    
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
ExecStart=/opt/node_exporter/node_exporter \\
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

# Установка Zabbix Agent
install_zabbix_agent() {
    log "Установка Zabbix Agent..."
    
    # Добавление репозитория Zabbix
    cd /tmp
    wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
    dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb
    apt update
    
    # Установка агента
    apt install -y zabbix-agent2 zabbix-agent2-plugin-*
    
    configure_zabbix_agent
}

# Настройка Zabbix Agent
configure_zabbix_agent() {
    log "Настройка Zabbix Agent..."
    
    # Backup оригинального файла
    cp /etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf.backup
    
    # Конфигурация агента
    cat > /etc/zabbix/zabbix_agent2.conf << EOF
# Zabbix Agent 2 configuration for RTTI LMS
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0

# Server configuration
Server=$ZABBIX_SERVER
ServerActive=$ZABBIX_SERVER
Hostname=$(hostname -f)

# Network configuration
ListenPort=10050
ListenIP=0.0.0.0

# Buffer settings
BufferSend=5
BufferSize=100

# Timeouts
Timeout=3

# Include user parameter files
Include=/etc/zabbix/zabbix_agent2.d/*.conf

# System parameters
AllowKey=system.run[*]

# Plugin configuration
Plugins.SystemRun.LogRemoteCommands=1
EOF

    # Создание пользовательских скриптов
    create_monitoring_scripts
    
    # Запуск и включение агента
    systemctl restart zabbix-agent2
    systemctl enable zabbix-agent2
    
    log "Zabbix Agent настроен и запущен"
}

# Создание скриптов мониторинга
create_monitoring_scripts() {
    log "Создание скриптов мониторинга LMS..."
    
    mkdir -p /etc/zabbix/scripts
    
    # Определение типа сервера (Moodle или Drupal)
    if [ -d "/var/www/moodle" ] || [ -d "/opt/moodle" ]; then
        SERVER_TYPE="moodle"
        create_moodle_monitoring_scripts
    elif [ -d "/var/www/drupal" ] || [ -d "/opt/drupal" ]; then
        SERVER_TYPE="drupal"
        create_drupal_monitoring_scripts
    else
        SERVER_TYPE="generic"
        create_generic_monitoring_scripts
    fi
    
    log "Созданы скрипты мониторинга для типа сервера: $SERVER_TYPE"
}

# Скрипты мониторинга Moodle
create_moodle_monitoring_scripts() {
    # Проверка здоровья Moodle
    cat > /etc/zabbix/scripts/check_moodle_health.sh << 'EOF'
#!/bin/bash
# Проверка здоровья Moodle

# Определение пути к Moodle
MOODLE_PATH="/var/www/moodle"
[ ! -d "$MOODLE_PATH" ] && MOODLE_PATH="/opt/moodle"

# Проверка доступности главной страницы
MAIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/login/index.php)

# Проверка config.php
if [ -f "$MOODLE_PATH/config.php" ]; then
    CONFIG_STATUS=1
else
    CONFIG_STATUS=0
fi

# Проверка директории moodledata
MOODLEDATA_PATH=$(grep -o "'/[^']*moodledata[^']*'" $MOODLE_PATH/config.php 2>/dev/null | tr -d "'")
if [ -d "$MOODLEDATA_PATH" ] && [ -w "$MOODLEDATA_PATH" ]; then
    MOODLEDATA_STATUS=1
else
    MOODLEDATA_STATUS=0
fi

# Проверка cron задач (последний запуск)
if [ -f "/var/log/moodle-cron.log" ]; then
    LAST_CRON=$(stat -c %Y /var/log/moodle-cron.log)
    CURRENT_TIME=$(date +%s)
    CRON_DELAY=$((CURRENT_TIME - LAST_CRON))
else
    CRON_DELAY=999999
fi

echo "{\"main_page\":$MAIN_PAGE,\"config\":$CONFIG_STATUS,\"moodledata\":$MOODLEDATA_STATUS,\"cron_delay\":$CRON_DELAY}"
EOF

    # Мониторинг производительности Moodle
    cat > /etc/zabbix/scripts/moodle_performance.sh << 'EOF'
#!/bin/bash
# Мониторинг производительности Moodle

# Время отклика главной страницы
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost/login/index.php)

# Количество активных PHP процессов
PHP_PROCESSES=$(ps aux | grep -c "php.*fpm")

# Использование памяти PHP
PHP_MEMORY=$(ps -eo pmem,comm | grep php | awk '{sum += $1} END {print sum}')

# Количество подключений к базе данных
DB_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='moodle';" 2>/dev/null | tr -d ' ')

echo "{\"response_time\":$RESPONSE_TIME,\"php_processes\":$PHP_PROCESSES,\"php_memory\":${PHP_MEMORY:-0},\"db_connections\":${DB_CONNECTIONS:-0}}"
EOF

    # Пользовательские параметры для Moodle
    cat > /etc/zabbix/zabbix_agent2.d/moodle_custom.conf << EOF
# Moodle specific monitoring parameters
UserParameter=moodle.health,/etc/zabbix/scripts/check_moodle_health.sh
UserParameter=moodle.performance,/etc/zabbix/scripts/moodle_performance.sh
UserParameter=moodle.users.online,mysql -u monitoring -pmonitoring_password -e "SELECT COUNT(*) FROM mdl_sessions WHERE timemodified > UNIX_TIMESTAMP() - 300;" moodle 2>/dev/null | tail -1
UserParameter=moodle.courses.count,mysql -u monitoring -pmonitoring_password -e "SELECT COUNT(*) FROM mdl_course WHERE visible=1;" moodle 2>/dev/null | tail -1
UserParameter=moodle.disk.usage,du -sb /var/moodledata 2>/dev/null | awk '{print \$1}'
EOF
}

# Скрипты мониторинга Drupal
create_drupal_monitoring_scripts() {
    # Проверка здоровья Drupal
    cat > /etc/zabbix/scripts/check_drupal_health.sh << 'EOF'
#!/bin/bash
# Проверка здоровья Drupal

# Определение пути к Drupal
DRUPAL_PATH="/var/www/drupal"
[ ! -d "$DRUPAL_PATH" ] && DRUPAL_PATH="/opt/drupal"

# Проверка доступности главной страницы
MAIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)

# Проверка страницы входа
LOGIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/user/login)

# Проверка settings.php
if [ -f "$DRUPAL_PATH/sites/default/settings.php" ]; then
    SETTINGS_STATUS=1
else
    SETTINGS_STATUS=0
fi

# Проверка директории files
FILES_PATH="$DRUPAL_PATH/sites/default/files"
if [ -d "$FILES_PATH" ] && [ -w "$FILES_PATH" ]; then
    FILES_STATUS=1
else
    FILES_STATUS=0
fi

# Проверка Drush
if command -v drush &> /dev/null; then
    DRUSH_STATUS=$(cd $DRUPAL_PATH && drush status --field=bootstrap 2>/dev/null | grep -c "Successful")
else
    DRUSH_STATUS=0
fi

echo "{\"main_page\":$MAIN_PAGE,\"login\":$LOGIN_PAGE,\"settings\":$SETTINGS_STATUS,\"files\":$FILES_STATUS,\"drush\":$DRUSH_STATUS}"
EOF

    # Мониторинг производительности Drupal
    cat > /etc/zabbix/scripts/drupal_performance.sh << 'EOF'
#!/bin/bash
# Мониторинг производительности Drupal

# Время отклика главной страницы
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost/)

# Размер кэша Drupal
CACHE_SIZE=$(find /tmp/drupal* -type f 2>/dev/null | wc -l)

# Количество файлов в files директории
FILES_COUNT=$(find /var/www/drupal/sites/default/files -type f 2>/dev/null | wc -l)

# Количество подключений к базе данных
DB_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='drupal_library';" 2>/dev/null | tr -d ' ')

echo "{\"response_time\":$RESPONSE_TIME,\"cache_size\":$CACHE_SIZE,\"files_count\":$FILES_COUNT,\"db_connections\":${DB_CONNECTIONS:-0}}"
EOF

    # Пользовательские параметры для Drupal
    cat > /etc/zabbix/zabbix_agent2.d/drupal_custom.conf << EOF
# Drupal specific monitoring parameters
UserParameter=drupal.health,/etc/zabbix/scripts/check_drupal_health.sh
UserParameter=drupal.performance,/etc/zabbix/scripts/drupal_performance.sh
UserParameter=drupal.nodes.count,sudo -u postgres psql -t -c "SELECT COUNT(*) FROM node WHERE status=1;" drupal_library 2>/dev/null | tr -d ' '
UserParameter=drupal.users.count,sudo -u postgres psql -t -c "SELECT COUNT(*) FROM users WHERE status=1;" drupal_library 2>/dev/null | tr -d ' '
UserParameter=drupal.disk.usage,du -sb /var/www/drupal/sites/default/files 2>/dev/null | awk '{print \$1}'
EOF
}

# Общие скрипты мониторинга
create_generic_monitoring_scripts() {
    cat > /etc/zabbix/zabbix_agent2.d/generic_custom.conf << EOF
# Generic LMS monitoring parameters
UserParameter=web.response,curl -s -o /dev/null -w "%{http_code}" http://localhost/
UserParameter=web.response.time,curl -s -o /dev/null -w "%{time_total}" http://localhost/
UserParameter=nginx.status,curl -s http://localhost/nginx_status 2>/dev/null | grep 'Active connections' | awk '{print \$3}' || echo 0
UserParameter=php.fpm.status,systemctl is-active php8.2-fpm php8.3-fpm | grep -c active
EOF
}

# Общие скрипты для всех типов серверов
create_common_scripts() {
    # Проверка статуса NAS
    cat > /etc/zabbix/scripts/check_nas_status.sh << 'EOF'
#!/bin/bash
# Проверка статуса NAS

if mountpoint -q /mnt/nas 2>/dev/null; then
    MOUNT_STATUS=1
    # Проверка доступности для записи
    if touch /mnt/nas/.test_write 2>/dev/null; then
        WRITE_STATUS=1
        rm -f /mnt/nas/.test_write
    else
        WRITE_STATUS=0
    fi
    # Проверка свободного места (в KB)
    FREE_SPACE=$(df /mnt/nas 2>/dev/null | tail -1 | awk '{print $4}')
else
    MOUNT_STATUS=0
    WRITE_STATUS=0
    FREE_SPACE=0
fi

echo "{\"mounted\":$MOUNT_STATUS,\"writable\":$WRITE_STATUS,\"free_space\":${FREE_SPACE:-0}}"
EOF

    # SSL сертификат
    cat > /etc/zabbix/scripts/check_ssl_cert.sh << 'EOF'
#!/bin/bash
# Проверка SSL сертификата

HOSTNAME=$(hostname -f)

if echo | timeout 5 openssl s_client -servername $HOSTNAME -connect localhost:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
    CERT_DAYS=$(echo | openssl s_client -servername $HOSTNAME -connect localhost:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2 | xargs -I {} date -d "{}" +%s | awk -v now=$(date +%s) '{print int(($1 - now) / 86400)}')
    SSL_STATUS=1
else
    CERT_DAYS=0
    SSL_STATUS=0
fi

echo "{\"ssl_available\":$SSL_STATUS,\"days_until_expire\":$CERT_DAYS}"
EOF

    chmod +x /etc/zabbix/scripts/*.sh
    chown zabbix:zabbix /etc/zabbix/scripts/*.sh 2>/dev/null || true
    
    # Общие пользовательские параметры
    cat > /etc/zabbix/zabbix_agent2.d/common_custom.conf << EOF
# Common monitoring parameters for all LMS servers
UserParameter=lms.nas.status,/etc/zabbix/scripts/check_nas_status.sh
UserParameter=lms.ssl.cert,/etc/zabbix/scripts/check_ssl_cert.sh
UserParameter=lms.backup.last,find /mnt/nas/lms-backups -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | awk '{print \$1}' || echo 0
UserParameter=system.services.failed,systemctl --failed --no-legend | wc -l
UserParameter=system.uptime.days,awk '{print int(\$1/86400)}' /proc/uptime
EOF
}

# Настройка firewall
configure_firewall() {
    log "Настройка firewall..."
    
    if command -v ufw &> /dev/null; then
        if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
            ufw allow from $PROMETHEUS_SERVER to any port 9100 comment "Node Exporter"
            log "Открыт порт 9100 для Prometheus сервера $PROMETHEUS_SERVER"
        fi
        
        if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
            ufw allow from $ZABBIX_SERVER to any port 10050 comment "Zabbix Agent"
            log "Открыт порт 10050 для Zabbix сервера $ZABBIX_SERVER"
        fi
    else
        warning "UFW не найден, настройте firewall вручную"
        if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
            warning "Откройте порт 9100 для $PROMETHEUS_SERVER"
        fi
        if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
            warning "Откройте порт 10050 для $ZABBIX_SERVER"
        fi
    fi
}

# Создание отчета об установке
create_installation_report() {
    log "Создание отчета об установке..."
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    cat > /root/monitoring-agents-report.txt << EOF
=== MONITORING AGENTS INSTALLATION REPORT ===
Дата установки: $(date)
Сервер: $(hostname -f) ($server_ip)
Тип установки: $INSTALL_TYPE

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===
EOF

    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
✅ Node Exporter $NODE_EXPORTER_VERSION (порт 9100)
   Prometheus сервер: $PROMETHEUS_SERVER
EOF
    fi

    if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
✅ Zabbix Agent 2 (порт 10050)
   Zabbix сервер: $ZABBIX_SERVER
EOF
    fi

    cat >> /root/monitoring-agents-report.txt << EOF

=== МОНИТОРИНГ ===
📊 Тип сервера: $SERVER_TYPE
📊 Доступные метрики:
   - Системные ресурсы (CPU, память, диск, сеть)
   - Состояние сервисов
   - Доступность веб-приложений
   - Статус NAS подключения
   - SSL сертификаты
   - Резервные копии
EOF

    if [ "$SERVER_TYPE" == "moodle" ]; then
        cat >> /root/monitoring-agents-report.txt << EOF
   - Здоровье Moodle
   - Производительность Moodle
   - Онлайн пользователи
   - Количество курсов
EOF
    elif [ "$SERVER_TYPE" == "drupal" ]; then
        cat >> /root/monitoring-agents-report.txt << EOF
   - Здоровье Drupal
   - Производительность Drupal
   - Количество узлов
   - Количество пользователей
EOF
    fi

    cat >> /root/monitoring-agents-report.txt << EOF

=== ФАЙЛЫ КОНФИГУРАЦИИ ===
EOF

    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
📁 Node Exporter: /etc/systemd/system/node_exporter.service
EOF
    fi

    if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
📁 Zabbix Agent: /etc/zabbix/zabbix_agent2.conf
📁 Пользовательские параметры: /etc/zabbix/zabbix_agent2.d/
📁 Скрипты мониторинга: /etc/zabbix/scripts/
EOF
    fi

    cat >> /root/monitoring-agents-report.txt << EOF

=== ДОСТУПНЫЕ ЭНДПОИНТЫ ===
EOF

    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
🌐 Node Exporter метрики: http://$server_ip:9100/metrics
EOF
    fi

    cat >> /root/monitoring-agents-report.txt << EOF

=== ПРОВЕРКА РАБОТЫ ===
EOF

    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
# Проверка Node Exporter
curl http://localhost:9100/metrics | head -10
systemctl status node_exporter
EOF
    fi

    if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF

# Проверка Zabbix Agent
systemctl status zabbix-agent2
zabbix_agent2 -t system.uptime
EOF

        if [ "$SERVER_TYPE" == "moodle" ]; then
            cat >> /root/monitoring-agents-report.txt << EOF
zabbix_agent2 -t moodle.health
EOF
        elif [ "$SERVER_TYPE" == "drupal" ]; then
            cat >> /root/monitoring-agents-report.txt << EOF
zabbix_agent2 -t drupal.health
EOF
        fi
    fi

    cat >> /root/monitoring-agents-report.txt << EOF

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Добавьте этот сервер в систему мониторинга
EOF

    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
   - В Prometheus: добавьте $server_ip:9100 в targets
EOF
    fi

    if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        cat >> /root/monitoring-agents-report.txt << EOF
   - В Zabbix: создайте хост с IP $server_ip
EOF
    fi

    cat >> /root/monitoring-agents-report.txt << EOF
2. Настройте алерты для критических метрик
3. Создайте дашборды для визуализации
4. Протестируйте все пользовательские метрики
EOF

    log "Отчет об установке создан: /root/monitoring-agents-report.txt"
}

# Основная функция
main() {
    log "🚀 Установка агентов мониторинга для RTTI LMS"
    
    select_monitoring_type
    get_monitoring_servers
    create_monitoring_user
    install_dependencies
    
    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        install_node_exporter
    fi
    
    if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        install_zabbix_agent
    fi
    
    create_monitoring_scripts
    create_common_scripts
    configure_firewall
    create_installation_report
    
    log "✅ Установка агентов мониторинга завершена успешно!"
    
    echo ""
    info "📋 Полный отчет: /root/monitoring-agents-report.txt"
    echo ""
    info "🔍 Эндпоинты мониторинга:"
    if [[ "$INSTALL_TYPE" == "node_exporter" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        info "   Node Exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
    fi
    if [[ "$INSTALL_TYPE" == "zabbix_agent" ]] || [[ "$INSTALL_TYPE" == "both" ]]; then
        info "   Zabbix Agent: порт 10050"
    fi
}

# Запуск
main "$@"
