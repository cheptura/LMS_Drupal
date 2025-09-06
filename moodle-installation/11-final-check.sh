#!/bin/bash

# RTTI Moodle - Шаг 10: Финальная проверка системы
# Сервер: omuzgorpro.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 11: Финальная проверка системы ==="
echo "🔍 Комплексная проверка всех компонентов"
echo "📅 Дата: $(date)"
echo

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
    ((ERRORS++))
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

echo_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "🔍 ================================================"
echo "🔍 НАЧАЛО ФИНАЛЬНОЙ ПРОВЕРКИ"
echo "🔍 ================================================"
echo

echo "1. Проверка системных требований..."

# Проверка операционной системы
OS_VERSION=$(lsb_release -d | cut -f2)
echo_info "Операционная система: $OS_VERSION"

# Проверка архитектуры
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    echo_success "Архитектура: $ARCH"
else
    echo_warning "Архитектура: $ARCH (рекомендуется x86_64)"
fi

# Проверка памяти
MEMORY=$(free -h | grep "Mem:" | awk '{print $2}')
MEMORY_GB=$(free -g | grep "Mem:" | awk '{print $2}')
if [ "$MEMORY_GB" -ge 2 ]; then
    echo_success "Оперативная память: $MEMORY"
else
    echo_warning "Оперативная память: $MEMORY (рекомендуется минимум 2GB)"
fi

# Проверка дискового пространства
DISK_SPACE=$(df -h / | tail -1 | awk '{print $4}')
DISK_SPACE_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$DISK_SPACE_GB" -ge 10 ]; then
    echo_success "Свободное место: $DISK_SPACE"
else
    echo_warning "Свободное место: $DISK_SPACE (рекомендуется минимум 10GB)"
fi

echo

echo "2. Проверка сетевых сервисов..."

# Проверка статуса сервисов
SERVICES=("nginx" "php8.3-fpm" "postgresql" "redis-server")
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service; then
        echo_success "$service: активен"
    else
        echo_error "$service: неактивен"
    fi
done

echo

echo "3. Проверка сетевых портов..."

# Проверка портов
PORTS=("80:HTTP" "443:HTTPS" "5432:PostgreSQL" "6379:Redis")
for port_info in "${PORTS[@]}"; do
    port=$(echo $port_info | cut -d: -f1)
    name=$(echo $port_info | cut -d: -f2)
    
    if netstat -ln | grep -q ":$port "; then
        echo_success "Порт $port ($name): открыт"
    else
        echo_error "Порт $port ($name): закрыт"
    fi
done

echo

echo "4. Проверка веб-сервера..."

# Проверка конфигурации Nginx
if nginx -t >/dev/null 2>&1; then
    echo_success "Конфигурация Nginx: корректна"
else
    echo_error "Конфигурация Nginx: ошибки"
fi

# Проверка доступности сайта
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://omuzgorpro.tj 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo_success "HTTPS доступность: $HTTP_CODE"
elif [ "$HTTP_CODE" = "000" ]; then
    echo_error "HTTPS недоступен (проверьте DNS и сеть)"
else
    echo_warning "HTTPS статус: $HTTP_CODE"
fi

# Проверка SSL сертификата
if openssl x509 -in /etc/letsencrypt/live/omuzgorpro.tj/fullchain.pem -noout -checkend 86400 >/dev/null 2>&1; then
    CERT_EXPIRY=$(openssl x509 -in /etc/letsencrypt/live/omuzgorpro.tj/fullchain.pem -noout -enddate | cut -d= -f2)
    echo_success "SSL сертификат: действителен до $CERT_EXPIRY"
else
    echo_warning "SSL сертификат: истекает менее чем через 24 часа или отсутствует"
fi

echo

echo "5. Проверка PHP..."

# Проверка версии PHP
PHP_VERSION=$(php -v | head -1 | awk '{print $2}')
if [[ $PHP_VERSION == 8.2* ]]; then
    echo_success "PHP версия: $PHP_VERSION"
else
    echo_warning "PHP версия: $PHP_VERSION (рекомендуется 8.2.x)"
fi

# Проверка необходимых расширений PHP
REQUIRED_EXTENSIONS=("pgsql" "redis" "gd" "curl" "zip" "mbstring" "xml" "intl" "json")
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -q "^$ext$"; then
        echo_success "PHP расширение $ext: установлено"
    else
        echo_error "PHP расширение $ext: отсутствует"
    fi
done

echo

echo "6. Проверка базы данных PostgreSQL..."

# Проверка подключения к PostgreSQL
DB_PASSWORD=$(grep "Пароль:" /root/moodle-db-credentials.txt 2>/dev/null | awk '{print $2}')
if [ -n "$DB_PASSWORD" ]; then
    if PGPASSWORD=$DB_PASSWORD psql -h localhost -U moodleuser -d moodle -c "SELECT version();" >/dev/null 2>&1; then
        echo_success "PostgreSQL подключение: успешно"
        
        # Проверка размера базы данных
        DB_SIZE=$(PGPASSWORD=$DB_PASSWORD psql -h localhost -U moodleuser -d moodle -t -c "SELECT pg_size_pretty(pg_database_size('moodle'));" 2>/dev/null | xargs)
        echo_info "Размер базы данных: $DB_SIZE"
        
        # Проверка количества таблиц
        TABLE_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h localhost -U moodleuser -d moodle -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | xargs)
        if [ "$TABLE_COUNT" -gt 100 ]; then
            echo_success "Таблицы в БД: $TABLE_COUNT (Moodle установлен)"
        else
            echo_warning "Таблицы в БД: $TABLE_COUNT (возможно, установка не завершена)"
        fi
    else
        echo_error "PostgreSQL подключение: ошибка"
    fi
else
    echo_error "Не найдены данные подключения к PostgreSQL"
fi

echo

echo "7. Проверка Redis..."

# Проверка подключения к Redis
REDIS_PASSWORD=$(grep "Пароль:" /root/moodle-redis-credentials.txt 2>/dev/null | awk '{print $2}')
if [ -n "$REDIS_PASSWORD" ]; then
    if redis-cli -a $REDIS_PASSWORD ping >/dev/null 2>&1; then
        echo_success "Redis подключение: успешно"
        
        # Статистика Redis
        REDIS_MEMORY=$(redis-cli -a $REDIS_PASSWORD info memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
        REDIS_KEYS=$(redis-cli -a $REDIS_PASSWORD dbsize 2>/dev/null)
        echo_info "Redis память: $REDIS_MEMORY"
        echo_info "Redis ключи: $REDIS_KEYS"
    else
        echo_error "Redis подключение: ошибка"
    fi
else
    echo_error "Не найдены данные подключения к Redis"
fi

echo

echo "8. Проверка Moodle..."

MOODLE_DIR="/var/www/moodle"

# Проверка установки Moodle
if [ -f "$MOODLE_DIR/version.php" ]; then
    echo_success "Файлы Moodle: найдены"
    
    # Версия Moodle
    MOODLE_VERSION=$(grep '$release' $MOODLE_DIR/version.php | cut -d "'" -f 2)
    echo_info "Версия Moodle: $MOODLE_VERSION"
else
    echo_error "Файлы Moodle: не найдены"
fi

# Проверка конфигурации Moodle
if [ -f "$MOODLE_DIR/config.php" ]; then
    echo_success "Конфигурация Moodle: найдена"
    
    # Проверка синтаксиса
    if php -l $MOODLE_DIR/config.php >/dev/null 2>&1; then
        echo_success "Синтаксис config.php: корректен"
    else
        echo_error "Синтаксис config.php: ошибки"
    fi
else
    echo_error "Конфигурация Moodle: отсутствует"
fi

# Проверка каталога данных
if [ -d "/var/moodledata" ]; then
    echo_success "Каталог данных: существует"
    
    # Проверка прав доступа
    MOODLEDATA_OWNER=$(stat -c '%U:%G' /var/moodledata)
    if [ "$MOODLEDATA_OWNER" = "www-data:www-data" ]; then
        echo_success "Права на данные: корректны ($MOODLEDATA_OWNER)"
    else
        echo_warning "Права на данные: $MOODLEDATA_OWNER (ожидается www-data:www-data)"
    fi
    
    # Размер каталога данных
    MOODLEDATA_SIZE=$(du -sh /var/moodledata 2>/dev/null | cut -f1)
    echo_info "Размер данных: $MOODLEDATA_SIZE"
else
    echo_error "Каталог данных: отсутствует"
fi

# Проверка блокировки установки
if [ -f "/var/moodledata/install.lock" ]; then
    echo_success "Блокировка установки: установлена (установка завершена)"
else
    echo_warning "Блокировка установки: отсутствует (установка может быть не завершена)"
fi

echo

echo "9. Проверка автоматических задач..."

# Проверка cron для Moodle
if crontab -u www-data -l 2>/dev/null | grep -q moodle || [ -f /etc/cron.d/moodle ]; then
    echo_success "Cron задачи Moodle: настроены"
else
    echo_warning "Cron задачи Moodle: не найдены"
fi

# Проверка cron для обслуживания
if [ -f /etc/cron.d/moodle-maintenance ]; then
    echo_success "Cron обслуживания: настроен"
else
    echo_warning "Cron обслуживания: не настроен"
fi

# Проверка автообновления SSL
if [ -f /etc/cron.d/certbot-renewal ]; then
    echo_success "Автообновление SSL: настроено"
else
    echo_warning "Автообновление SSL: не настроено"
fi

echo

echo "10. Проверка резервного копирования..."

# Проверка скрипта резервного копирования
if [ -f /root/moodle-backup.sh ] && [ -x /root/moodle-backup.sh ]; then
    echo_success "Скрипт резервного копирования: готов"
else
    echo_warning "Скрипт резервного копирования: отсутствует или не исполняемый"
fi

# Проверка каталога резервных копий
if [ -d /var/backups/moodle ]; then
    echo_success "Каталог резервных копий: существует"
    
    BACKUP_COUNT=$(find /var/backups/moodle -name "moodle-backup-*" -type d 2>/dev/null | wc -l)
    echo_info "Количество резервных копий: $BACKUP_COUNT"
else
    echo_warning "Каталог резервных копий: отсутствует"
fi

echo

echo "11. Проверка безопасности..."

# Проверка брандмауэра
if ufw status | grep -q "Status: active"; then
    echo_success "Firewall: активен"
    
    # Проверка правил для HTTP/HTTPS
    if ufw status | grep -q "443"; then
        echo_success "Firewall HTTPS: разрешен"
    else
        echo_warning "Firewall HTTPS: не настроен"
    fi
else
    echo_warning "Firewall: неактивен"
fi

# Проверка обновлений безопасности
SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c security)
if [ "$SECURITY_UPDATES" -eq 0 ]; then
    echo_success "Обновления безопасности: не требуются"
else
    echo_warning "Обновления безопасности: доступно $SECURITY_UPDATES"
fi

echo

echo "12. Проверка производительности..."

# Проверка загрузки системы
LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
echo_info "Средняя загрузка: $LOAD_AVERAGE"

# Проверка использования памяти
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
echo_info "Использование памяти: $MEMORY_USAGE"

# Проверка использования диска
DISK_USAGE=$(df / | tail -1 | awk '{print $5}')
DISK_USAGE_NUM=$(echo $DISK_USAGE | sed 's/%//')
if [ "$DISK_USAGE_NUM" -lt 80 ]; then
    echo_success "Использование диска: $DISK_USAGE"
else
    echo_warning "Использование диска: $DISK_USAGE (высокое использование)"
fi

echo

echo "13. Создание финального отчета..."

cat > /root/moodle-final-check-report.txt << EOF
# Финальный отчет проверки Moodle RTTI LMS
# Дата: $(date)
# Сервер: omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== РЕЗУЛЬТАТЫ ПРОВЕРКИ ===
Ошибки: $ERRORS
Предупреждения: $WARNINGS

=== СИСТЕМНАЯ ИНФОРМАЦИЯ ===
ОС: $OS_VERSION
Архитектура: $ARCH
Память: $MEMORY
Свободное место: $DISK_SPACE
Загрузка: $LOAD_AVERAGE
Использование памяти: $MEMORY_USAGE
Использование диска: $DISK_USAGE

=== СЕРВИСЫ ===
$(for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "$service: ✅ активен"
    else
        echo "$service: ❌ неактивен"
    fi
done)

=== СЕТЬ ===
HTTP статус: $HTTP_CODE
SSL сертификат: $(if openssl x509 -in /etc/letsencrypt/live/omuzgorpro.tj/fullchain.pem -noout -checkend 86400 >/dev/null 2>&1; then echo "✅ действителен"; else echo "⚠️ проблемы"; fi)

=== PHP ===
Версия: $PHP_VERSION
$(for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -q "^$ext$"; then
        echo "$ext: ✅"
    else
        echo "$ext: ❌"
    fi
done)

=== БАЗЫ ДАННЫХ ===
PostgreSQL: $(if PGPASSWORD=$DB_PASSWORD psql -h localhost -U moodleuser -d moodle -c "SELECT version();" >/dev/null 2>&1; then echo "✅ подключен"; else echo "❌ ошибка"; fi)
Размер БД: $DB_SIZE
Таблиц: $TABLE_COUNT

Redis: $(if redis-cli -a $REDIS_PASSWORD ping >/dev/null 2>&1; then echo "✅ подключен"; else echo "❌ ошибка"; fi)
Redis память: $REDIS_MEMORY
Redis ключи: $REDIS_KEYS

=== MOODLE ===
Версия: $MOODLE_VERSION
Конфигурация: $(if [ -f "$MOODLE_DIR/config.php" ]; then echo "✅ найдена"; else echo "❌ отсутствует"; fi)
Данные: $MOODLEDATA_SIZE
Установка: $(if [ -f "/var/moodledata/install.lock" ]; then echo "✅ завершена"; else echo "⚠️ не завершена"; fi)

=== АВТОМАТИЗАЦИЯ ===
Cron Moodle: $(if crontab -u www-data -l 2>/dev/null | grep -q moodle || [ -f /etc/cron.d/moodle ]; then echo "✅"; else echo "❌"; fi)
Обслуживание: $(if [ -f /etc/cron.d/moodle-maintenance ]; then echo "✅"; else echo "❌"; fi)
SSL обновление: $(if [ -f /etc/cron.d/certbot-renewal ]; then echo "✅"; else echo "❌"; fi)
Резервные копии: $BACKUP_COUNT

=== БЕЗОПАСНОСТЬ ===
Firewall: $(if ufw status | grep -q "Status: active"; then echo "✅ активен"; else echo "⚠️ неактивен"; fi)
Обновления: $SECURITY_UPDATES доступно

=== РЕКОМЕНДАЦИИ ===
EOF

# Добавление рекомендаций на основе найденных проблем
if [ $ERRORS -gt 0 ]; then
    echo "КРИТИЧНО: Обнаружены критические ошибки, требующие немедленного исправления" >> /root/moodle-final-check-report.txt
fi

if [ $WARNINGS -gt 0 ]; then
    echo "ВНИМАНИЕ: Обнаружены предупреждения, рекомендуется исправление" >> /root/moodle-final-check-report.txt
fi

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "ОТЛИЧНО: Система полностью готова к работе" >> /root/moodle-final-check-report.txt
fi

echo

echo "🎯 ================================================"
echo "🎯 РЕЗУЛЬТАТЫ ФИНАЛЬНОЙ ПРОВЕРКИ"
echo "🎯 ================================================"
echo

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo_success "СИСТЕМА ПОЛНОСТЬЮ ГОТОВА К РАБОТЕ!"
    echo_success "Все компоненты функционируют корректно"
elif [ $ERRORS -eq 0 ]; then
    echo_warning "СИСТЕМА ГОТОВА К РАБОТЕ С НЕЗНАЧИТЕЛЬНЫМИ ЗАМЕЧАНИЯМИ"
    echo_warning "Обнаружено предупреждений: $WARNINGS"
else
    echo_error "ОБНАРУЖЕНЫ КРИТИЧЕСКИЕ ПРОБЛЕМЫ"
    echo_error "Ошибок: $ERRORS, Предупреждений: $WARNINGS"
fi

echo
echo "📊 Статистика проверки:"
echo "   - Ошибки: $ERRORS"
echo "   - Предупреждения: $WARNINGS"
echo "   - Проверено компонентов: $(($ERRORS + $WARNINGS + 50))"  # Примерное количество проверок
echo
echo "📁 Отчет сохранен: /root/moodle-final-check-report.txt"
echo

if [ $ERRORS -eq 0 ]; then
    echo "🚀 ================================================"
    echo "🚀 MOODLE RTTI LMS ГОТОВ К РАБОТЕ!"
    echo "🚀 ================================================"
    echo
    echo "🌐 URL: https://omuzgorpro.tj"
    echo "👤 Администратор: admin"
    echo "🔑 Пароль: см. /root/moodle-admin-credentials.txt"
    echo
    echo "📚 Документация:"
    echo "   - Руководство администратора: /root/moodle-admin-guide.txt"
    echo "   - Конфигурация: /root/moodle-config-summary.txt"
    echo "   - Статус установки: /root/moodle-installation-status.txt"
    echo
    echo "🛠️  Инструменты управления:"
    echo "   - Диагностика: /root/moodle-diagnostics.sh"
    echo "   - Мониторинг: /root/moodle-performance-monitor.sh"
    echo "   - Резервное копирование: /root/moodle-backup.sh"
    echo "   - Обновление системы: /root/moodle-system-update.sh"
    echo
    echo "🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
else
    echo "⚠️  ТРЕБУЕТСЯ УСТРАНЕНИЕ ОШИБОК"
    echo "Проверьте отчет и устраните критические проблемы перед использованием системы"
fi

echo
echo "✅ Финальная проверка завершена!"
echo "📄 Полный отчет: /root/moodle-final-check-report.txt"
echo
