#!/bin/bash

# RTTI Drupal - Шаг 10: Финальная проверка установки
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 10: Финальная проверка системы ==="
echo "✅ Комплексная диагностика и валидация установки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"
PHP_VERSION="8.3"
DOMAIN="storage.omuzgorpro.tj"
REPORT_FILE="/root/drupal-final-report.txt"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для форматированного вывода
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Инициализация отчета
cat > $REPORT_FILE << EOF
# ФИНАЛЬНЫЙ ОТЧЕТ О УСТАНОВКЕ DRUPAL LIBRARY
# Сервер: $DOMAIN ($(hostname -I | awk '{print $1}'))
# Дата проверки: $(date)
# Администратор: $(whoami)

EOF

log_result() {
    echo "$1" >> $REPORT_FILE
}

print_header "1. Проверка системных компонентов"

# Проверка операционной системы
os_info=$(lsb_release -d | cut -f2)
print_info "Операционная система: $os_info"
log_result "OS: $os_info"

# Проверка архитектуры
arch_info=$(uname -m)
print_info "Архитектура: $arch_info"
log_result "Architecture: $arch_info"

# Проверка времени работы системы
uptime_info=$(uptime -p)
print_info "Время работы: $uptime_info"
log_result "Uptime: $uptime_info"

print_header "2. Проверка сетевой конфигурации"

# Проверка сетевых интерфейсов
ip_address=$(hostname -I | awk '{print $1}')
if [ ! -z "$ip_address" ]; then
    print_success "IP адрес: $ip_address"
    log_result "✅ IP: $ip_address"
else
    print_error "IP адрес не настроен"
    log_result "❌ IP: not configured"
fi

# Проверка DNS резолвинга
if nslookup $DOMAIN > /dev/null 2>&1; then
    resolved_ip=$(nslookup $DOMAIN | awk '/^Address: / { print $2 }' | tail -1)
    print_success "DNS резолвинг: $DOMAIN -> $resolved_ip"
    log_result "✅ DNS: $DOMAIN -> $resolved_ip"
else
    print_warning "DNS резолвинг: $DOMAIN - не настроен"
    log_result "⚠️ DNS: $DOMAIN - not configured"
fi

# Проверка портов
print_info "Проверка открытых портов:"
declare -A ports=([22]="SSH" [80]="HTTP" [443]="HTTPS" [5432]="PostgreSQL" [6379]="Redis")

for port in "${!ports[@]}"; do
    if netstat -tln | grep -q ":$port "; then
        print_success "Порт $port (${ports[$port]}): открыт"
        log_result "✅ Port $port (${ports[$port]}): open"
    else
        print_error "Порт $port (${ports[$port]}): закрыт"
        log_result "❌ Port $port (${ports[$port]}): closed"
    fi
done

print_header "3. Проверка веб-сервера (Nginx)"

# Проверка статуса Nginx
if systemctl is-active --quiet nginx; then
    print_success "Nginx: активен"
    log_result "✅ Nginx: active"
    
    # Проверка версии
    nginx_version=$(nginx -v 2>&1 | cut -d/ -f2)
    print_info "Версия Nginx: $nginx_version"
    log_result "Nginx version: $nginx_version"
else
    print_error "Nginx: не активен"
    log_result "❌ Nginx: inactive"
fi

# Проверка конфигурации Nginx
if nginx -t &> /dev/null; then
    print_success "Конфигурация Nginx: корректна"
    log_result "✅ Nginx config: valid"
else
    print_error "Конфигурация Nginx: содержит ошибки"
    log_result "❌ Nginx config: invalid"
fi

# Проверка SSL сертификата
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    cert_expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" | cut -d= -f2)
    print_success "SSL сертификат: установлен (истекает: $cert_expiry)"
    log_result "✅ SSL cert: installed, expires $cert_expiry"
else
    print_warning "SSL сертификат: не найден"
    log_result "⚠️ SSL cert: not found"
fi

print_header "4. Проверка PHP"

# Проверка статуса PHP-FPM
if systemctl is-active --quiet php$PHP_VERSION-fpm; then
    print_success "PHP-FPM: активен"
    log_result "✅ PHP-FPM: active"
    
    # Проверка версии PHP
    php_version=$(php -v | head -1 | cut -d' ' -f2)
    print_info "Версия PHP: $php_version"
    log_result "PHP version: $php_version"
else
    print_error "PHP-FPM: не активен"
    log_result "❌ PHP-FPM: inactive"
fi

# Проверка PHP модулей
print_info "Проверка PHP модулей:"
required_modules=("pdo_pgsql" "gd" "curl" "zip" "xml" "mbstring" "opcache" "redis" "memcached")

for module in "${required_modules[@]}"; do
    if php -m | grep -q "^$module$"; then
        print_success "$module: установлен"
        log_result "✅ PHP module $module: installed"
    else
        print_error "$module: не установлен"
        log_result "❌ PHP module $module: missing"
    fi
done

print_header "5. Проверка базы данных (PostgreSQL)"

# Проверка статуса PostgreSQL
if systemctl is-active --quiet postgresql; then
    print_success "PostgreSQL: активен"
    log_result "✅ PostgreSQL: active"
    
    # Проверка версии
    pg_version=$(sudo -u postgres psql -c "SELECT version();" | grep "PostgreSQL" | cut -d' ' -f3)
    print_info "Версия PostgreSQL: $pg_version"
    log_result "PostgreSQL version: $pg_version"
else
    print_error "PostgreSQL: не активен"
    log_result "❌ PostgreSQL: inactive"
fi

# Проверка подключения к базе данных
if sudo -u postgres psql -d drupal_library -c "SELECT 1;" &> /dev/null; then
    print_success "База данных drupal_library: доступна"
    log_result "✅ Database drupal_library: accessible"
    
    # Статистика базы данных
    table_count=$(sudo -u postgres psql -d drupal_library -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
    print_info "Количество таблиц: $table_count"
    log_result "Database tables: $table_count"
    
    db_size=$(sudo -u postgres psql -d drupal_library -t -c "SELECT pg_size_pretty(pg_database_size('drupal_library'));" | tr -d ' ')
    print_info "Размер базы данных: $db_size"
    log_result "Database size: $db_size"
else
    print_error "База данных drupal_library: недоступна"
    log_result "❌ Database drupal_library: inaccessible"
fi

print_header "6. Проверка кэширования (Redis & Memcached)"

# Проверка Redis
if systemctl is-active --quiet redis-server; then
    print_success "Redis: активен"
    log_result "✅ Redis: active"
    
    if redis-cli ping &> /dev/null; then
        print_success "Redis: отвечает на запросы"
        log_result "✅ Redis: responding"
        
        redis_memory=$(redis-cli info memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
        print_info "Использование памяти Redis: $redis_memory"
        log_result "Redis memory: $redis_memory"
    else
        print_error "Redis: не отвечает"
        log_result "❌ Redis: not responding"
    fi
else
    print_error "Redis: не активен"
    log_result "❌ Redis: inactive"
fi

# Проверка Memcached
if systemctl is-active --quiet memcached; then
    print_success "Memcached: активен"
    log_result "✅ Memcached: active"
    
    if echo "stats" | nc localhost 11211 &> /dev/null; then
        print_success "Memcached: отвечает на запросы"
        log_result "✅ Memcached: responding"
    else
        print_error "Memcached: не отвечает"
        log_result "❌ Memcached: not responding"
    fi
else
    print_error "Memcached: не активен"
    log_result "❌ Memcached: inactive"
fi

print_header "7. Проверка Drupal"

# Проверка файлов Drupal
if [ -d "$DRUPAL_DIR" ] && [ -f "$DRUPAL_DIR/web/index.php" ]; then
    print_success "Drupal файлы: установлены"
    log_result "✅ Drupal files: installed"
    
    # Проверка версии Drupal
    cd $DRUPAL_DIR
    if [ -f "vendor/bin/drush" ]; then
        drupal_version=$(sudo -u www-data vendor/bin/drush status --field=drupal-version 2>/dev/null)
        if [ ! -z "$drupal_version" ]; then
            print_success "Версия Drupal: $drupal_version"
            log_result "✅ Drupal version: $drupal_version"
        else
            print_warning "Не удается определить версию Drupal"
            log_result "⚠️ Drupal version: unknown"
        fi
    fi
else
    print_error "Drupal файлы: не найдены"
    log_result "❌ Drupal files: not found"
fi

# Проверка настроек Drupal
if [ -f "$DRUPAL_DIR/web/sites/default/settings.php" ]; then
    print_success "Файл настроек Drupal: существует"
    log_result "✅ Drupal settings: exists"
    
    # Проверка прав на файл настроек
    settings_perms=$(stat -c "%a" "$DRUPAL_DIR/web/sites/default/settings.php")
    if [ "$settings_perms" == "444" ]; then
        print_success "Права на settings.php: корректные ($settings_perms)"
        log_result "✅ Settings permissions: $settings_perms"
    else
        print_warning "Права на settings.php: $settings_perms (рекомендуется 444)"
        log_result "⚠️ Settings permissions: $settings_perms"
    fi
else
    print_error "Файл настроек Drupal: не найден"
    log_result "❌ Drupal settings: not found"
fi

# Проверка статуса Drupal
cd $DRUPAL_DIR
if sudo -u www-data vendor/bin/drush status &> /dev/null; then
    print_success "Drupal: функционирует"
    log_result "✅ Drupal: functional"
    
    # Проверка модулей
    print_info "Проверка ключевых модулей:"
    key_modules=("node" "user" "system" "admin_toolbar" "search_api" "redis")
    
    for module in "${key_modules[@]}"; do
        if sudo -u www-data vendor/bin/drush pm:list --status=enabled --format=list | grep -q "^$module$"; then
            print_success "$module: включен"
            log_result "✅ Module $module: enabled"
        else
            print_warning "$module: не включен"
            log_result "⚠️ Module $module: disabled"
        fi
    done
else
    print_error "Drupal: не функционирует"
    log_result "❌ Drupal: not functional"
fi

print_header "8. Проверка безопасности"

# Проверка Fail2Ban
if systemctl is-active --quiet fail2ban; then
    print_success "Fail2Ban: активен"
    log_result "✅ Fail2Ban: active"
    
    # Проверка количества заблокированных IP
    banned_count=$(fail2ban-client status | grep "Number of jail" | cut -d: -f2 | tr -d ' ')
    print_info "Количество активных jail: $banned_count"
    log_result "Fail2Ban jails: $banned_count"
else
    print_error "Fail2Ban: не активен"
    log_result "❌ Fail2Ban: inactive"
fi

# Проверка firewall
if iptables -L INPUT | grep -q "DROP"; then
    print_success "Firewall: настроен"
    log_result "✅ Firewall: configured"
else
    print_warning "Firewall: не настроен"
    log_result "⚠️ Firewall: not configured"
fi

# Проверка auditd
if systemctl is-active --quiet auditd; then
    print_success "Auditd: активен"
    log_result "✅ Auditd: active"
else
    print_warning "Auditd: не активен"
    log_result "⚠️ Auditd: inactive"
fi

print_header "9. Проверка производительности"

# Проверка загрузки системы
load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
print_info "Средняя загрузка: $load_avg"
log_result "Load average: $load_avg"

# Проверка использования памяти
memory_usage=$(free -h | grep "Mem:" | awk '{print $3"/"$2" ("int($3/$2*100)"%)";}')
print_info "Использование памяти: $memory_usage"
log_result "Memory usage: $memory_usage"

# Проверка использования диска
disk_usage=$(df -h /var/www | tail -1 | awk '{print $3"/"$2" ("$5")"}')
print_info "Использование диска: $disk_usage"
log_result "Disk usage: $disk_usage"

# Проверка количества процессов
process_count=$(ps aux | wc -l)
print_info "Количество процессов: $process_count"
log_result "Process count: $process_count"

print_header "10. Проверка HTTP/HTTPS доступности"

# Проверка HTTP ответа
if curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN | grep -q "301\|302"; then
    print_success "HTTP: перенаправление работает"
    log_result "✅ HTTP redirect: working"
else
    print_warning "HTTP: перенаправление не настроено"
    log_result "⚠️ HTTP redirect: not configured"
fi

# Проверка HTTPS ответа
https_status=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN 2>/dev/null || echo "000")
if [ "$https_status" == "200" ]; then
    print_success "HTTPS: сайт доступен (код $https_status)"
    log_result "✅ HTTPS: accessible (code $https_status)"
elif [ "$https_status" == "000" ]; then
    print_error "HTTPS: сайт недоступен (ошибка соединения)"
    log_result "❌ HTTPS: connection error"
else
    print_warning "HTTPS: сайт отвечает с кодом $https_status"
    log_result "⚠️ HTTPS: code $https_status"
fi

# Проверка времени ответа
if [ "$https_status" == "200" ]; then
    response_time=$(curl -s -o /dev/null -w "%{time_total}" https://$DOMAIN 2>/dev/null || echo "timeout")
    print_info "Время ответа: ${response_time}s"
    log_result "Response time: ${response_time}s"
fi

print_header "11. Проверка логов и мониторинга"

# Проверка наличия логов
log_dirs=("/var/log/nginx" "/var/log/drupal" "/var/log/postgresql")
for log_dir in "${log_dirs[@]}"; do
    if [ -d "$log_dir" ]; then
        log_count=$(find "$log_dir" -name "*.log" | wc -l)
        print_success "Логи $log_dir: $log_count файлов"
        log_result "✅ Logs $log_dir: $log_count files"
    else
        print_warning "Директория логов $log_dir: не найдена"
        log_result "⚠️ Log dir $log_dir: not found"
    fi
done

# Проверка cron заданий
cron_count=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)
if [ "$cron_count" -gt 0 ]; then
    print_success "Cron задания: $cron_count активных"
    log_result "✅ Cron jobs: $cron_count active"
else
    print_warning "Cron задания: не настроены"
    log_result "⚠️ Cron jobs: not configured"
fi

# Проверка скриптов обслуживания
maintenance_scripts=("/root/library-maintenance.sh" "/root/drupal-monitor.sh" "/root/drupal-backup.sh" "/root/security-monitor.sh")
for script in "${maintenance_scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        print_success "Скрипт $(basename $script): установлен и исполняемый"
        log_result "✅ Script $(basename $script): installed"
    else
        print_warning "Скрипт $(basename $script): не найден или не исполняемый"
        log_result "⚠️ Script $(basename $script): missing or not executable"
    fi
done

print_header "12. Создание сводки по установке"

# Подсчет успешных и проблемных компонентов
success_count=$(grep -c "✅" $REPORT_FILE)
warning_count=$(grep -c "⚠️" $REPORT_FILE)
error_count=$(grep -c "❌" $REPORT_FILE)

total_checks=$((success_count + warning_count + error_count))
success_percentage=$((success_count * 100 / total_checks))

# Определение статуса установки
if [ $error_count -eq 0 ] && [ $warning_count -le 3 ]; then
    installation_status="ОТЛИЧНОЕ"
    status_color=$GREEN
elif [ $error_count -le 2 ] && [ $warning_count -le 5 ]; then
    installation_status="ХОРОШЕЕ"
    status_color=$YELLOW
else
    installation_status="ТРЕБУЕТ ВНИМАНИЯ"
    status_color=$RED
fi

cat >> $REPORT_FILE << EOF

=== СВОДКА ПРОВЕРКИ ===

Общее количество проверок: $total_checks
✅ Успешно: $success_count ($success_percentage%)
⚠️ Предупреждения: $warning_count
❌ Ошибки: $error_count

СТАТУС УСТАНОВКИ: $installation_status

=== РЕКОМЕНДАЦИИ ===

EOF

# Добавление рекомендаций в зависимости от найденных проблем
if [ $error_count -gt 0 ]; then
    cat >> $REPORT_FILE << EOF
КРИТИЧЕСКИЕ ПРОБЛЕМЫ:
- Обнаружены критические ошибки ($error_count)
- Требуется немедленное внимание администратора
- Система может работать нестабильно

EOF
fi

if [ $warning_count -gt 0 ]; then
    cat >> $REPORT_FILE << EOF
ПРЕДУПРЕЖДЕНИЯ:
- Обнаружены некритические проблемы ($warning_count)
- Рекомендуется устранить для оптимальной работы
- Система функциональна, но может быть улучшена

EOF
fi

cat >> $REPORT_FILE << EOF
СЛЕДУЮЩИЕ ШАГИ:
1. Проверьте элементы с предупреждениями и ошибками
2. Настройте регулярное резервное копирование
3. Мониторьте производительность системы
4. Обновляйте Drupal и модули безопасности
5. Проводите регулярные проверки безопасности

=== КОНТАКТЫ ТЕХНИЧЕСКОЙ ПОДДЕРЖКИ ===
Email: support@omuzgorpro.tj
Документация: /root/drupal-*-report.txt
Мониторинг: /root/drupal-monitor.sh
Обслуживание: /root/library-maintenance.sh

=== ЗАКЛЮЧЕНИЕ ===

Дата установки: $(date)
Сервер: $DOMAIN ($(hostname -I | awk '{print $1}'))
Версия Drupal: $(cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush status --field=drupal-version 2>/dev/null || echo "неизвестно")
Статус: $installation_status

Установка завершена успешно!
EOF

print_header "13. Финальные тесты"

# Тест производительности
print_info "Запуск теста производительности..."
if command -v ab &> /dev/null; then
    ab_result=$(ab -n 10 -c 2 https://$DOMAIN/ 2>/dev/null | grep "Requests per second" | awk '{print $4}')
    if [ ! -z "$ab_result" ]; then
        print_success "Производительность: $ab_result запросов/сек"
        log_result "✅ Performance: $ab_result req/sec"
    fi
else
    print_info "Apache Bench не установлен, пропускаем тест производительности"
fi

# Тест базы данных
print_info "Тест подключения к базе данных..."
if cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush sql:query "SELECT COUNT(*) FROM users;" &> /dev/null; then
    user_count=$(cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush sql:query "SELECT COUNT(*) FROM users;" --extra=--skip-column-names 2>/dev/null)
    print_success "База данных: $user_count пользователей"
    log_result "✅ Database test: $user_count users"
else
    print_error "База данных: ошибка подключения"
    log_result "❌ Database test: connection error"
fi

print_header "14. Создание final checklist"

cat > /root/drupal-checklist.txt << EOF
# КОНТРОЛЬНЫЙ СПИСОК DRUPAL LIBRARY
# Дата: $(date)

[ ] 1. Система и сеть
    [ ] Операционная система настроена
    [ ] IP адрес назначен
    [ ] DNS настроен
    [ ] Порты открыты (22, 80, 443)

[ ] 2. Веб-сервер
    [ ] Nginx установлен и запущен
    [ ] SSL сертификат установлен
    [ ] Конфигурация корректна
    [ ] Виртуальный хост настроен

[ ] 3. PHP
    [ ] PHP-FPM запущен
    [ ] Все необходимые модули установлены
    [ ] Конфигурация оптимизирована
    [ ] OPcache настроен

[ ] 4. База данных
    [ ] PostgreSQL запущен
    [ ] База drupal_library создана
    [ ] Пользователь drupaluser настроен
    [ ] Подключение работает

[ ] 5. Кэширование
    [ ] Redis запущен и отвечает
    [ ] Memcached запущен
    [ ] Drupal подключен к кэшу
    [ ] APCu работает

[ ] 6. Drupal
    [ ] Файлы установлены
    [ ] Конфигурация корректна
    [ ] Модули включены
    [ ] Темы настроены
    [ ] Контент-типы созданы

[ ] 7. Безопасность
    [ ] Fail2Ban настроен
    [ ] Firewall активен
    [ ] SSL работает
    [ ] Права на файлы корректны
    [ ] Аудит включен

[ ] 8. Мониторинг
    [ ] Системный мониторинг
    [ ] Логирование настроено
    [ ] Уведомления работают
    [ ] Скрипты обслуживания

[ ] 9. Резервное копирование
    [ ] Автоматическое создание
    [ ] Шифрование данных
    [ ] Ротация архивов
    [ ] Тестирование восстановления

[ ] 10. Производительность
    [ ] Кэширование работает
    [ ] Сжатие включено
    [ ] Статика оптимизирована
    [ ] База данных оптимизирована
EOF

echo
echo -e "${status_color}=== ФИНАЛЬНЫЙ РЕЗУЛЬТАТ ===${NC}"
echo -e "${BLUE}Общее количество проверок:${NC} $total_checks"
echo -e "${GREEN}✅ Успешно:${NC} $success_count ($success_percentage%)"
echo -e "${YELLOW}⚠️ Предупреждения:${NC} $warning_count"
echo -e "${RED}❌ Ошибки:${NC} $error_count"
echo
echo -e "${status_color}СТАТУС УСТАНОВКИ: $installation_status${NC}"
echo
print_info "Подробный отчет сохранен в: $REPORT_FILE"
print_info "Контрольный список: /root/drupal-checklist.txt"
echo
if [ "$installation_status" == "ОТЛИЧНОЕ" ]; then
    print_success "🎉 Поздравляем! Система полностью готова к работе!"
    print_success "🌐 Сайт доступен по адресу: https://$DOMAIN"
    print_success "🔧 Панель администратора: https://$DOMAIN/admin"
elif [ "$installation_status" == "ХОРОШЕЕ" ]; then
    print_success "✅ Система готова к работе с небольшими замечаниями"
    print_info "📋 Просмотрите предупреждения в отчете для улучшения"
    print_success "🌐 Сайт доступен по адресу: https://$DOMAIN"
else
    print_warning "⚠️ Система требует дополнительной настройки"
    print_warning "🔧 Устраните ошибки перед продуктивным использованием"
    print_info "📋 Подробности в отчете: $REPORT_FILE"
fi

echo
print_header "ПОЛЕЗНЫЕ КОМАНДЫ"
print_info "Статус системы: /root/drupal-monitor.sh status"
print_info "Статистика библиотеки: /root/library-maintenance.sh stats"
print_info "Статус безопасности: /root/security-monitor.sh status"
print_info "Создание резервной копии: /root/drupal-backup.sh"
print_info "Обновление поиска: /root/library-maintenance.sh reindex"

echo
print_success "✅ Установка Drupal Library RTTI завершена!"
echo
