#!/bin/bash
# Установка Zabbix Server + Agent для мониторинга Moodle 5.0.2 + Drupal 11 RTTI
# Включает мониторинг веб-приложений, баз данных и системных ресурсов

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
ZABBIX_VERSION="6.4"
ZABBIX_DB_NAME="zabbix"
ZABBIX_DB_USER="zabbix"
ZABBIX_DB_PASSWORD="zabbix_secure_password_2025"
ZABBIX_ADMIN_PASSWORD="rtti_zabbix_2025"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен запускаться с правами root"
   exit 1
fi

info "🚀 Начинаем установку Zabbix $ZABBIX_VERSION для мониторинга RTTI LMS"

# Определение режима установки
select_installation_mode() {
    echo ""
    info "Выберите режим установки:"
    echo "1) Zabbix Server (полная установка с веб-интерфейсом)"
    echo "2) Zabbix Agent только (для дополнительных серверов)"
    echo ""
    read -p "Введите номер (1-2): " mode
    
    case $mode in
        1) INSTALL_MODE="server" ;;
        2) INSTALL_MODE="agent" ;;
        *) error "Неверный выбор"; exit 1 ;;
    esac
    
    log "Выбран режим: $INSTALL_MODE"
}

# Установка зависимостей
install_dependencies() {
    log "Установка зависимостей..."
    
    apt update
    apt install -y \
        wget \
        curl \
        gnupg \
        ca-certificates \
        software-properties-common \
        apt-transport-https
}

# Добавление репозитория Zabbix
add_zabbix_repository() {
    log "Добавление репозитория Zabbix..."
    
    cd /tmp
    wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
    dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb
    apt update
}

# Установка Zabbix Server
install_zabbix_server() {
    log "Установка Zabbix Server с PostgreSQL..."
    
    # Установка пакетов
    apt install -y \
        zabbix-server-pgsql \
        zabbix-frontend-php \
        php8.1-pgsql \
        zabbix-apache-conf \
        zabbix-sql-scripts \
        apache2 \
        postgresql-14
    
    # Создание базы данных
    log "Создание базы данных Zabbix..."
    
    sudo -u postgres createuser --pwprompt $ZABBIX_DB_USER << EOF
$ZABBIX_DB_PASSWORD
$ZABBIX_DB_PASSWORD
EOF
    
    sudo -u postgres createdb -O $ZABBIX_DB_USER $ZABBIX_DB_NAME
    
    # Импорт схемы
    log "Импорт схемы базы данных..."
    zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | \
        sudo -u $ZABBIX_DB_USER psql $ZABBIX_DB_NAME
    
    # Настройка конфигурации сервера
    configure_zabbix_server
}

# Настройка Zabbix Server
configure_zabbix_server() {
    log "Настройка Zabbix Server..."
    
    # Backup оригинального файла
    cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.backup
    
    # Конфигурация подключения к БД
    cat > /etc/zabbix/zabbix_server.conf << EOF
# Database configuration
DBHost=localhost
DBName=$ZABBIX_DB_NAME
DBUser=$ZABBIX_DB_USER
DBPassword=$ZABBIX_DB_PASSWORD

# Server configuration
ListenPort=10051
SourceIP=
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
PidFile=/run/zabbix/zabbix_server.pid
SocketDir=/var/run/zabbix

# Cache configuration
StartPollers=5
StartPollersUnreachable=1
StartTrappers=5
StartPingers=1
StartDiscoverers=1
StartHTTPPollers=1
StartTimers=1
StartEscalators=1
StartAlerters=3

# Performance tuning
CacheSize=32M
ValueCacheSize=8M
HistoryCacheSize=16M
HistoryIndexCacheSize=4M
TrendCacheSize=4M

# Timeouts
Timeout=4
TrapperTimeout=300
UnreachablePeriod=45
UnavailableDelay=60
UnreachableDelay=15

# Alerts
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts

# Logging
LogSlowQueries=3000
StatsAllowedIP=127.0.0.1
EOF

    # Настройка PHP для веб-интерфейса
    log "Настройка PHP для Zabbix..."
    
    sed -i 's/; date.timezone =/date.timezone = Europe\/Dushanbe/' /etc/php/8.1/apache2/php.ini
    sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/apache2/php.ini
    sed -i 's/max_input_time = 60/max_input_time = 300/' /etc/php/8.1/apache2/php.ini
    sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/apache2/php.ini
    sed -i 's/post_max_size = 8M/post_max_size = 16M/' /etc/php/8.1/apache2/php.ini
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2M/' /etc/php/8.1/apache2/php.ini
    
    # Запуск сервисов
    systemctl restart apache2
    systemctl restart zabbix-server
    systemctl enable zabbix-server apache2
    
    log "Zabbix Server настроен и запущен"
}

# Установка Zabbix Agent
install_zabbix_agent() {
    log "Установка Zabbix Agent..."
    
    apt install -y zabbix-agent2 zabbix-agent2-plugin-*
    
    # Настройка агента
    configure_zabbix_agent
}

# Настройка Zabbix Agent
configure_zabbix_agent() {
    log "Настройка Zabbix Agent..."
    
    # Определение сервера
    if [ "$INSTALL_MODE" == "agent" ]; then
        read -p "IP адрес Zabbix Server: " ZABBIX_SERVER_IP
    else
        ZABBIX_SERVER_IP="127.0.0.1"
    fi
    
    # Backup оригинального файла
    cp /etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf.backup
    
    # Конфигурация агента
    cat > /etc/zabbix/zabbix_agent2.conf << EOF
# Zabbix Agent 2 configuration for RTTI LMS
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0

# Server configuration
Server=$ZABBIX_SERVER_IP
ServerActive=$ZABBIX_SERVER_IP
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

# Custom parameters for LMS monitoring
UserParameter=moodle.status,curl -s -o /dev/null -w "%{http_code}" http://localhost/login/index.php
UserParameter=drupal.status,curl -s -o /dev/null -w "%{http_code}" http://localhost/user/login
UserParameter=postgres.connections,sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;" | tr -d ' '
UserParameter=nginx.status,curl -s http://localhost/nginx_status | grep 'Active connections' | awk '{print \$3}'
UserParameter=php.fpm.status,systemctl is-active php8.2-fpm php8.3-fpm | grep -c active
UserParameter=nas.mount.status,mountpoint -q /mnt/nas && echo 1 || echo 0
UserParameter=moodle.users.online,mysql -u monitoring -pmonitoring_password -e "SELECT COUNT(*) FROM mdl_sessions WHERE timemodified > UNIX_TIMESTAMP() - 300;" moodle 2>/dev/null | tail -1
EOF

    # Создание пользовательских скриптов
    create_custom_monitoring_scripts
    
    # Запуск и включение агента
    systemctl restart zabbix-agent2
    systemctl enable zabbix-agent2
    
    log "Zabbix Agent настроен и запущен"
}

# Создание пользовательских скриптов мониторинга
create_custom_monitoring_scripts() {
    log "Создание пользовательских скриптов мониторинга..."
    
    mkdir -p /etc/zabbix/scripts
    
    # Скрипт проверки здоровья Moodle
    cat > /etc/zabbix/scripts/check_moodle_health.sh << 'EOF'
#!/bin/bash
# Проверка здоровья Moodle

# Проверка доступности главной страницы
MAIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/login/index.php)

# Проверка доступности API
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/webservice/rest/server.php)

# Проверка базы данных
DB_STATUS=$(sudo -u postgres psql -t -c "SELECT 1;" moodle 2>/dev/null | grep -c 1)

# Проверка файловой системы moodledata
if [ -d "/var/moodledata" ] && [ -w "/var/moodledata" ]; then
    MOODLEDATA_STATUS=1
else
    MOODLEDATA_STATUS=0
fi

# Вывод результата в формате JSON
echo "{\"main_page\":$MAIN_PAGE,\"api\":$API_STATUS,\"database\":$DB_STATUS,\"moodledata\":$MOODLEDATA_STATUS}"
EOF

    # Скрипт проверки здоровья Drupal
    cat > /etc/zabbix/scripts/check_drupal_health.sh << 'EOF'
#!/bin/bash
# Проверка здоровья Drupal

# Проверка доступности главной страницы
MAIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)

# Проверка страницы входа
LOGIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/user/login)

# Проверка статуса сайта
STATUS_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/admin/reports/status)

# Проверка базы данных
DB_STATUS=$(sudo -u postgres psql -t -c "SELECT 1;" drupal_library 2>/dev/null | grep -c 1)

# Проверка файловой системы
if [ -d "/var/www/drupal/sites/default/files" ] && [ -w "/var/www/drupal/sites/default/files" ]; then
    FILES_STATUS=1
else
    FILES_STATUS=0
fi

echo "{\"main_page\":$MAIN_PAGE,\"login\":$LOGIN_PAGE,\"status\":$STATUS_PAGE,\"database\":$DB_STATUS,\"files\":$FILES_STATUS}"
EOF

    # Скрипт мониторинга NAS
    cat > /etc/zabbix/scripts/check_nas_status.sh << 'EOF'
#!/bin/bash
# Проверка статуса NAS

# Проверка монтирования
if mountpoint -q /mnt/nas; then
    MOUNT_STATUS=1
    # Проверка доступности для записи
    if touch /mnt/nas/.test_write 2>/dev/null; then
        WRITE_STATUS=1
        rm -f /mnt/nas/.test_write
    else
        WRITE_STATUS=0
    fi
    # Проверка свободного места
    FREE_SPACE=$(df /mnt/nas | tail -1 | awk '{print $4}')
else
    MOUNT_STATUS=0
    WRITE_STATUS=0
    FREE_SPACE=0
fi

echo "{\"mounted\":$MOUNT_STATUS,\"writable\":$WRITE_STATUS,\"free_space\":$FREE_SPACE}"
EOF

    chmod +x /etc/zabbix/scripts/*.sh
    chown zabbix:zabbix /etc/zabbix/scripts/*.sh
    
    # Дополнительные пользовательские параметры
    cat > /etc/zabbix/zabbix_agent2.d/lms_custom.conf << EOF
# Custom LMS monitoring parameters
UserParameter=lms.moodle.health,/etc/zabbix/scripts/check_moodle_health.sh
UserParameter=lms.drupal.health,/etc/zabbix/scripts/check_drupal_health.sh
UserParameter=lms.nas.status,/etc/zabbix/scripts/check_nas_status.sh
UserParameter=lms.backup.last,find /mnt/nas/lms-backups -name "*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | awk '{print \$1}'
UserParameter=lms.ssl.cert.days,echo | openssl s_client -servername \$(hostname -f) -connect localhost:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2 | xargs -I {} date -d "{}" +%s | awk '{print int((\$1 - systime()) / 86400)}'
EOF
    
    log "Пользовательские скрипты мониторинга созданы"
}

# Создание шаблонов мониторинга
create_monitoring_templates() {
    log "Создание шаблонов мониторинга для импорта в Zabbix..."
    
    mkdir -p /tmp/zabbix_templates
    
    # Шаблон для мониторинга Moodle
    cat > /tmp/zabbix_templates/moodle_template.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<zabbix_export>
    <version>6.4</version>
    <date>2025-09-04T00:00:00Z</date>
    <templates>
        <template>
            <uuid>moodle-lms-template-rtti</uuid>
            <template>Template RTTI Moodle LMS</template>
            <name>Template RTTI Moodle LMS</name>
            <description>Шаблон мониторинга Moodle 5.0.2 для RTTI</description>
            <groups>
                <group>
                    <name>LMS/Education</name>
                </group>
            </groups>
            <items>
                <item>
                    <uuid>moodle-status-main</uuid>
                    <name>Moodle Main Page Status</name>
                    <type>ZABBIX_ACTIVE</type>
                    <key>moodle.status</key>
                    <delay>1m</delay>
                    <description>HTTP status code for Moodle main page</description>
                    <triggers>
                        <trigger>
                            <uuid>moodle-down-trigger</uuid>
                            <expression>{Template RTTI Moodle LMS:moodle.status.last()}&lt;&gt;200</expression>
                            <name>Moodle is down</name>
                            <priority>HIGH</priority>
                        </trigger>
                    </triggers>
                </item>
            </items>
        </template>
    </templates>
</zabbix_export>
EOF

    log "Шаблоны созданы в /tmp/zabbix_templates/"
}

# Настройка веб-интерфейса
configure_web_interface() {
    log "Настройка веб-интерфейса Zabbix..."
    
    # Создание виртуального хоста Apache
    cat > /etc/apache2/sites-available/zabbix.conf << EOF
<VirtualHost *:80>
    ServerName zabbix.rtti.tj
    DocumentRoot /usr/share/zabbix
    
    <Directory "/usr/share/zabbix">
        Options FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    
    <Directory "/usr/share/zabbix/conf">
        Require all denied
    </Directory>
    
    <Directory "/usr/share/zabbix/app">
        Require all denied
    </Directory>
    
    <Directory "/usr/share/zabbix/include">
        Require all denied
    </Directory>
    
    <Directory "/usr/share/zabbix/local">
        Require all denied
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/zabbix_error.log
    CustomLog \${APACHE_LOG_DIR}/zabbix_access.log combined
</VirtualHost>
EOF

    a2ensite zabbix.conf
    systemctl reload apache2
    
    log "Веб-интерфейс настроен на http://zabbix.rtti.tj"
}

# Создание начальной конфигурации
create_initial_configuration() {
    log "Создание начальной конфигурации..."
    
    # Настройка автоматической регистрации агентов
    cat > /tmp/zabbix_autoregistration.sql << EOF
-- Настройки автоматической регистрации
UPDATE config SET discovery_groupid=5 WHERE configid=1;
INSERT INTO actions (actionid, name, eventsource, evaltype, status, esc_period, def_shortdata, def_longdata)
VALUES (100, 'Auto registration RTTI LMS', 2, 0, 0, '1h', '{HOST.NAME}: Auto registration', '{HOST.NAME} has been automatically registered.');
EOF

    log "Конфигурация создана"
}

# Настройка firewall
configure_firewall() {
    log "Настройка firewall для Zabbix..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 10050/tcp comment "Zabbix Agent"
        if [ "$INSTALL_MODE" == "server" ]; then
            ufw allow 10051/tcp comment "Zabbix Server"
            ufw allow 80/tcp comment "Zabbix Web"
        fi
        log "Firewall настроен"
    else
        warning "UFW не найден, настройте firewall manually"
    fi
}

# Создание отчета об установке
create_installation_report() {
    log "Создание отчета об установке..."
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    cat > /root/zabbix-installation-report.txt << EOF
=== ZABBIX MONITORING INSTALLATION REPORT ===
Дата установки: $(date)
Сервер: $(hostname -f)
Режим установки: $INSTALL_MODE

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===
EOF

    if [ "$INSTALL_MODE" == "server" ]; then
        cat >> /root/zabbix-installation-report.txt << EOF
✅ Zabbix Server $ZABBIX_VERSION
✅ Zabbix Web Interface
✅ PostgreSQL Database
✅ Apache Web Server
✅ Zabbix Agent 2
EOF
    else
        cat >> /root/zabbix-installation-report.txt << EOF
✅ Zabbix Agent 2
EOF
    fi

    cat >> /root/zabbix-installation-report.txt << EOF

=== ДОСТУП К ИНТЕРФЕЙСАМ ===
EOF

    if [ "$INSTALL_MODE" == "server" ]; then
        cat >> /root/zabbix-installation-report.txt << EOF
🌐 Zabbix Web: http://$server_ip/zabbix
🌐 Альтернативный URL: http://zabbix.rtti.tj
   
   Первоначальная настройка:
   1. Откройте веб-интерфейс
   2. Следуйте мастеру установки
   3. Используйте данные БД:
      - Тип: PostgreSQL
      - Сервер: localhost
      - База: $ZABBIX_DB_NAME
      - Пользователь: $ZABBIX_DB_USER
      - Пароль: $ZABBIX_DB_PASSWORD
   
   Логин по умолчанию: Admin (без пароля)
   ⚠️  ОБЯЗАТЕЛЬНО смените пароль после первого входа!
EOF
    fi

    cat >> /root/zabbix-installation-report.txt << EOF

=== ФАЙЛЫ КОНФИГУРАЦИИ ===
📁 Zabbix Agent: /etc/zabbix/zabbix_agent2.conf
EOF

    if [ "$INSTALL_MODE" == "server" ]; then
        cat >> /root/zabbix-installation-report.txt << EOF
📁 Zabbix Server: /etc/zabbix/zabbix_server.conf
📁 Apache Virtual Host: /etc/apache2/sites-available/zabbix.conf
EOF
    fi

    cat >> /root/zabbix-installation-report.txt << EOF
📁 Пользовательские параметры: /etc/zabbix/zabbix_agent2.d/lms_custom.conf
📁 Скрипты мониторинга: /etc/zabbix/scripts/

=== СИСТЕМНЫЕ СЕРВИСЫ ===
🔧 zabbix-agent2.service (порт 10050)
EOF

    if [ "$INSTALL_MODE" == "server" ]; then
        cat >> /root/zabbix-installation-report.txt << EOF
🔧 zabbix-server.service (порт 10051)
🔧 apache2.service (порт 80)
🔧 postgresql.service (порт 5432)
EOF
    fi

    cat >> /root/zabbix-installation-report.txt << EOF

=== МОНИТОРИНГ LMS ===
🔍 Автоматический мониторинг:
   - Доступность Moodle и Drupal
   - Состояние системных сервисов
   - Использование ресурсов
   - Статус NAS подключения
   - SSL сертификаты
   - Состояние резервных копий

=== ПОЛЬЗОВАТЕЛЬСКИЕ МЕТРИКИ ===
📊 lms.moodle.health - здоровье Moodle
📊 lms.drupal.health - здоровье Drupal
📊 lms.nas.status - статус NAS
📊 lms.backup.last - время последнего бэкапа
📊 lms.ssl.cert.days - дни до истечения SSL

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Завершите настройку через веб-интерфейс
2. Импортируйте шаблоны из /tmp/zabbix_templates/
3. Добавьте хосты для мониторинга
4. Настройте уведомления (email, SMS, Telegram)
5. Создайте дашборды для LMS
6. Настройте SSL для веб-интерфейса

=== ПОЛЕЗНЫЕ КОМАНДЫ ===
# Проверка статуса сервисов
systemctl status zabbix-agent2
EOF

    if [ "$INSTALL_MODE" == "server" ]; then
        cat >> /root/zabbix-installation-report.txt << EOF
systemctl status zabbix-server

# Просмотр логов
tail -f /var/log/zabbix/zabbix_server.log
EOF
    fi

    cat >> /root/zabbix-installation-report.txt << EOF
tail -f /var/log/zabbix/zabbix_agent2.log

# Тестирование пользовательских параметров
zabbix_agent2 -t lms.moodle.health
zabbix_agent2 -t lms.drupal.health
zabbix_agent2 -t lms.nas.status

# Перезагрузка конфигурации агента
systemctl restart zabbix-agent2
EOF

    log "Отчет об установке создан: /root/zabbix-installation-report.txt"
}

# Основная функция установки
main() {
    log "🚀 Начинаем установку Zabbix для мониторинга RTTI LMS"
    
    select_installation_mode
    install_dependencies
    add_zabbix_repository
    
    if [ "$INSTALL_MODE" == "server" ]; then
        install_zabbix_server
        configure_web_interface
        create_initial_configuration
    fi
    
    install_zabbix_agent
    create_monitoring_templates
    configure_firewall
    create_installation_report
    
    log "✅ Установка Zabbix завершена успешно!"
    
    echo ""
    if [ "$INSTALL_MODE" == "server" ]; then
        info "🌐 Веб-интерфейс Zabbix:"
        info "   http://$(hostname -I | awk '{print $1}')/zabbix"
        info "   Логин: Admin (без пароля)"
        warning "   ⚠️  ОБЯЗАТЕЛЬНО смените пароль после первого входа!"
    fi
    echo ""
    info "📋 Полный отчет: /root/zabbix-installation-report.txt"
    echo ""
    warning "🔧 Не забудьте:"
    warning "   1. Завершить настройку через веб-интерфейс"
    warning "   2. Добавить домен zabbix.rtti.tj в DNS"
    warning "   3. Настроить уведомления"
    warning "   4. Импортировать шаблоны мониторинга"
}

# Запуск
main "$@"
