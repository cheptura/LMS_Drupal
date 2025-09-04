#!/bin/bash

# RTTI Infrastructure Diagnostics Script
# Диагностика состояния всех систем RTTI

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                      RTTI Infrastructure Diagnostics                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "📅 Дата проверки: $(date)"
echo "🖥️  Сервер: $(hostname)"
echo "🌐 IP адрес: $(hostname -I | awk '{print $1}')"
echo

# Функция проверки сервиса
check_service() {
    local service=$1
    if systemctl is-active --quiet $service; then
        echo "✅ $service: Активен"
    else
        echo "❌ $service: Не активен"
    fi
}

# Функция проверки порта
check_port() {
    local port=$1
    local service=$2
    if netstat -tlnp | grep -q ":$port "; then
        echo "✅ Порт $port ($service): Открыт"
    else
        echo "❌ Порт $port ($service): Закрыт"
    fi
}

# Системная информация
echo "🖥️  СИСТЕМНАЯ ИНФОРМАЦИЯ"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "ОС: $(lsb_release -d | cut -f2)"
echo "Ядро: $(uname -r)"
echo "Архитектура: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo

# Проверка ресурсов
echo "📊 СИСТЕМНЫЕ РЕСУРСЫ"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "💾 Использование памяти:"
free -h
echo
echo "💽 Использование дисков:"
df -h | grep -E "(Filesystem|/dev/)"
echo
echo "⚡ Нагрузка системы:"
echo "$(uptime)"
echo

# Проверка сервисов
echo "🔧 СТАТУС СЕРВИСОВ"
echo "═══════════════════════════════════════════════════════════════════════════════"
check_service "nginx"
check_service "postgresql"
check_service "redis-server"
check_service "php8.2-fpm"
check_service "php8.3-fpm"
check_service "prometheus" 2>/dev/null || echo "ℹ️  prometheus: Не установлен"
check_service "grafana-server" 2>/dev/null || echo "ℹ️  grafana-server: Не установлен"
check_service "alertmanager" 2>/dev/null || echo "ℹ️  alertmanager: Не установлен"
echo

# Проверка портов
echo "🌐 СЕТЕВЫЕ ПОРТЫ"
echo "═══════════════════════════════════════════════════════════════════════════════"
check_port "80" "HTTP"
check_port "443" "HTTPS"
check_port "22" "SSH"
check_port "5432" "PostgreSQL"
check_port "6379" "Redis"
check_port "9000" "PHP-FPM"
check_port "9090" "Prometheus"
check_port "3000" "Grafana"
check_port "9093" "Alertmanager"
echo

# Проверка веб-сайтов
echo "🌐 ПРОВЕРКА ВЕБ-САЙТОВ"
echo "═══════════════════════════════════════════════════════════════════════════════"
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
    echo "✅ Веб-сервер отвечает"
else
    echo "❌ Веб-сервер не отвечает"
fi

# Проверка Moodle
if [ -d "/var/www/html/moodle" ]; then
    echo "✅ Moodle: Установлен в /var/www/html/moodle"
    if [ -f "/var/www/html/moodle/config.php" ]; then
        echo "✅ Moodle: Конфигурация найдена"
    else
        echo "⚠️  Moodle: Конфигурация отсутствует"
    fi
else
    echo "ℹ️  Moodle: Не установлен"
fi

# Проверка Drupal
if [ -d "/var/www/html/drupal" ]; then
    echo "✅ Drupal: Установлен в /var/www/html/drupal"
    if [ -f "/var/www/html/drupal/sites/default/settings.php" ]; then
        echo "✅ Drupal: Конфигурация найдена"
    else
        echo "⚠️  Drupal: Конфигурация отсутствует"
    fi
else
    echo "ℹ️  Drupal: Не установлен"
fi
echo

# Проверка SSL сертификатов
echo "🔒 SSL СЕРТИФИКАТЫ"
echo "═══════════════════════════════════════════════════════════════════════════════"
if [ -d "/etc/letsencrypt/live" ]; then
    echo "✅ Let's Encrypt найден"
    for cert in /etc/letsencrypt/live/*/cert.pem; do
        if [ -f "$cert" ]; then
            domain=$(basename $(dirname $cert))
            expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
            echo "📜 $domain: действует до $expiry"
        fi
    done
else
    echo "ℹ️  SSL сертификаты: Не найдены"
fi
echo

# Проверка логов
echo "📋 ЛОГИ УСТАНОВКИ"
echo "═══════════════════════════════════════════════════════════════════════════════"
if [ -d "/var/log/rtti-installation" ]; then
    echo "✅ Логи найдены в /var/log/rtti-installation/"
    echo "📁 Последние файлы логов:"
    ls -lt /var/log/rtti-installation/ | head -5
else
    echo "ℹ️  Логи установки: Не найдены"
fi
echo

# Проверка базы данных
echo "🗄️  БАЗЫ ДАННЫХ"
echo "═══════════════════════════════════════════════════════════════════════════════"
if systemctl is-active --quiet postgresql; then
    echo "✅ PostgreSQL активен"
    
    # Проверка баз данных
    databases=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null | grep -v "^$")
    if [ ! -z "$databases" ]; then
        echo "📊 Базы данных:"
        echo "$databases" | sed 's/^/ - /'
    fi
else
    echo "❌ PostgreSQL не активен"
fi

if systemctl is-active --quiet redis-server; then
    echo "✅ Redis активен"
    redis_info=$(redis-cli info server 2>/dev/null | grep "redis_version" | cut -d: -f2)
    if [ ! -z "$redis_info" ]; then
        echo "📊 Redis версия: $redis_info"
    fi
else
    echo "❌ Redis не активен"
fi
echo

# Проверка файрвола
echo "🛡️  БЕЗОПАСНОСТЬ"
echo "═══════════════════════════════════════════════════════════════════════════════"
if systemctl is-active --quiet ufw; then
    echo "✅ UFW (файрвол): Активен"
    echo "📋 Открытые порты:"
    ufw status | grep -E "(80|443|22|5432|6379|9090|3000|9093)" | sed 's/^/   /'
else
    echo "⚠️  UFW (файрвол): Не активен"
fi

if systemctl is-active --quiet fail2ban; then
    echo "✅ Fail2ban: Активен"
    banned_ips=$(fail2ban-client status 2>/dev/null | grep "Currently banned" | awk '{print $3}')
    echo "🚫 Заблокированные IP: $banned_ips"
else
    echo "⚠️  Fail2ban: Не активен"
fi
echo

# Рекомендации
echo "💡 РЕКОМЕНДАЦИИ"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Проверка обновлений
updates=$(apt list --upgradable 2>/dev/null | wc -l)
if [ $updates -gt 1 ]; then
    echo "📦 Доступно обновлений: $((updates-1))"
    echo "   Выполните: sudo apt update && sudo apt upgrade"
fi

# Проверка места на диске
disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $disk_usage -gt 80 ]; then
    echo "⚠️  Диск заполнен на $disk_usage% - рекомендуется очистка"
fi

# Проверка памяти
mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2 }')
if [ $mem_usage -gt 80 ]; then
    echo "⚠️  Память используется на $mem_usage% - требуется мониторинг"
fi

echo
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                           Диагностика завершена                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "📄 Для детального анализа логов используйте:"
echo "   tail -f /var/log/nginx/error.log"
echo "   tail -f /var/log/postgresql/postgresql-16-main.log"
echo "   journalctl -xe"
echo
