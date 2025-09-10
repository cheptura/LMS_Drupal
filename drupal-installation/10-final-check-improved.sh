#!/bin/bash

# RTTI Drupal - Улучшенная финальная проверка с рекомендациями
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Улучшенная финальная проверка ==="
echo "🔍 Диагностика с рекомендациями по исправлению"
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
REPORT_FILE="/root/drupal-diagnostic-$(date +%Y%m%d-%H%M%S).txt"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для форматированного вывода
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "✅ $1" >> $REPORT_FILE
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    echo "❌ $1" >> $REPORT_FILE
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
    echo "⚠️ $1" >> $REPORT_FILE
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
    echo "ℹ️ $1" >> $REPORT_FILE
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
    echo -e "\n=== $1 ===" >> $REPORT_FILE
}

print_recommendation() {
    echo -e "${YELLOW}🔧 РЕКОМЕНДАЦИЯ: $1${NC}"
    echo "🔧 РЕКОМЕНДАЦИЯ: $1" >> $REPORT_FILE
}

# Инициализация отчета
echo "=== RTTI Drupal - Диагностический отчет ===" > $REPORT_FILE
echo "Дата: $(date)" >> $REPORT_FILE
echo "Сервер: $DOMAIN ($(hostname -I | awk '{print $1}'))" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Массив для хранения проблем
declare -a CRITICAL_ISSUES=()
declare -a WARNINGS=()
declare -a RECOMMENDATIONS=()

print_header "1. Проверка системных компонентов"
print_info "Операционная система: $(lsb_release -d | cut -f2)"
print_info "Архитектура: $(uname -m)"
print_info "Время работы: $(uptime -p)"

print_header "2. Проверка сетевой конфигурации"
IP_ADDRESS=$(hostname -I | awk '{print $1}')
print_success "IP адрес: $IP_ADDRESS"

# Проверка DNS
if nslookup $DOMAIN >/dev/null 2>&1; then
    DNS_IP=$(nslookup $DOMAIN | grep 'Address:' | tail -1 | awk '{print $2}')
    print_success "DNS резолвинг: $DOMAIN -> $DNS_IP"
else
    print_error "DNS резолвинг: не работает для $DOMAIN"
    CRITICAL_ISSUES+=("DNS резолвинг не работает")
    RECOMMENDATIONS+=("Настройте DNS запись для домена $DOMAIN")
fi

# Проверка портов
print_info "Проверка открытых портов:"
PORTS_TO_CHECK=(22 80 443 5432 6379)
PORT_NAMES=("SSH" "HTTP" "HTTPS" "PostgreSQL" "Redis")

for i in "${!PORTS_TO_CHECK[@]}"; do
    port=${PORTS_TO_CHECK[$i]}
    name=${PORT_NAMES[$i]}
    
    if netstat -tlnp | grep ":$port " >/dev/null 2>&1; then
        print_success "Порт $port ($name): открыт"
    else
        if [[ "$port" == "80" || "$port" == "443" ]]; then
            print_error "Порт $port ($name): закрыт"
            CRITICAL_ISSUES+=("Веб-порт $port закрыт")
            if [ "$port" == "80" ]; then
                RECOMMENDATIONS+=("Запустите Nginx: systemctl start nginx")
            fi
        else
            print_warning "Порт $port ($name): закрыт"
            WARNINGS+=("Порт $port закрыт")
        fi
    fi
done

print_header "3. Проверка веб-сервера (Nginx)"

# Проверка статуса Nginx
if systemctl is-active --quiet nginx; then
    print_success "Nginx: активен"
    nginx_version=$(nginx -v 2>&1 | cut -d/ -f2)
    print_info "Версия Nginx: $nginx_version"
else
    print_error "Nginx: не активен"
    CRITICAL_ISSUES+=("Nginx не запущен")
    RECOMMENDATIONS+=("Запустите Nginx: systemctl start nginx && systemctl enable nginx")
fi

# Проверка конфигурации Nginx
if nginx -t &> /dev/null; then
    print_success "Конфигурация Nginx: корректна"
else
    print_error "Конфигурация Nginx: содержит ошибки"
    CRITICAL_ISSUES+=("Ошибки в конфигурации Nginx")
    RECOMMENDATIONS+=("Проверьте конфигурацию: nginx -t && journalctl -u nginx.service")
    RECOMMENDATIONS+=("Исправьте или пересоздайте конфигурацию: ./fix-issues.sh")
fi

# Проверка SSL сертификата
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    cert_expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" | cut -d= -f2)
    print_success "SSL сертификат: установлен (истекает: $cert_expiry)"
    
    # Проверка срока действия
    end_timestamp=$(date -d "$cert_expiry" +%s)
    current_timestamp=$(date +%s)
    days_left=$(( (end_timestamp - current_timestamp) / 86400 ))
    
    if [ $days_left -lt 30 ]; then
        print_warning "SSL сертификат истекает через $days_left дней"
        WARNINGS+=("SSL сертификат скоро истечет")
        RECOMMENDATIONS+=("Обновите SSL сертификат: certbot renew")
    fi
else
    print_warning "SSL сертификат: не найден"
    WARNINGS+=("SSL сертификат отсутствует")
    RECOMMENDATIONS+=("Установите SSL сертификат: ./05-configure-ssl.sh")
fi

print_header "4. Проверка PHP"

# Проверка PHP-FPM
if systemctl is-active --quiet php8.3-fpm; then
    print_success "PHP-FPM: активен"
else
    print_error "PHP-FPM: не активен"
    CRITICAL_ISSUES+=("PHP-FPM не запущен")
    RECOMMENDATIONS+=("Запустите PHP-FPM: systemctl start php8.3-fpm && systemctl enable php8.3-fpm")
fi

print_info "Версия PHP: $(php --version | head -1 | awk '{print $2}')"

# Проверка PHP модулей
print_info "Проверка PHP модулей:"
REQUIRED_MODULES=("pdo_pgsql" "gd" "curl" "zip" "xml" "mbstring" "opcache" "redis")

for module in "${REQUIRED_MODULES[@]}"; do
    if php -m | grep -qi "$module"; then
        print_success "$module: установлен"
    else
        if [ "$module" == "opcache" ]; then
            print_error "$module: не установлен"
            CRITICAL_ISSUES+=("OPcache не установлен")
            RECOMMENDATIONS+=("Установите OPcache: apt install php8.3-opcache")
            RECOMMENDATIONS+=("Или запустите скрипт исправления: ./fix-issues.sh")
        else
            print_warning "$module: не установлен"
            WARNINGS+=("PHP модуль $module отсутствует")
            RECOMMENDATIONS+=("Установите модуль: apt install php8.3-$module")
        fi
    fi
done

# Проверка PHP-FPM пула
if [ -f "/etc/php/8.3/fpm/pool.d/drupal.conf" ]; then
    print_success "PHP-FPM пул Drupal: настроен"
    
    # Проверка сокета
    if [ -S "/run/php/php8.3-fpm-drupal.sock" ]; then
        print_success "PHP-FPM сокет: активен"
    else
        print_error "PHP-FPM сокет: не найден"
        CRITICAL_ISSUES+=("PHP-FPM сокет не создан")
        RECOMMENDATIONS+=("Перезапустите PHP-FPM: systemctl restart php8.3-fpm")
    fi
else
    print_error "PHP-FPM пул Drupal: не настроен"
    CRITICAL_ISSUES+=("PHP-FPM пул не настроен")
    RECOMMENDATIONS+=("Создайте пул: ./fix-issues.sh")
fi

print_header "5. Проверка базы данных (PostgreSQL)"

if systemctl is-active --quiet postgresql; then
    print_success "PostgreSQL: активен"
    
    # Проверка версии
    pg_version=$(sudo -u postgres psql -t -c "SELECT version();" | head -1 | awk '{print $2}')
    print_info "Версия PostgreSQL: $pg_version"
    
    # Проверка базы данных
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw drupal_library; then
        print_success "База данных drupal_library: существует"
        
        # Проверка подключения
        if sudo -u postgres psql -d drupal_library -c "SELECT 1;" &> /dev/null; then
            print_success "База данных drupal_library: доступна"
        else
            print_error "База данных drupal_library: недоступна"
            CRITICAL_ISSUES+=("База данных недоступна")
            RECOMMENDATIONS+=("Проверьте подключение к базе данных")
        fi
    else
        print_error "База данных drupal_library: не существует"
        CRITICAL_ISSUES+=("База данных не создана")
        RECOMMENDATIONS+=("Создайте базу данных: ./03-install-database.sh")
    fi
else
    print_error "PostgreSQL: не активен"
    CRITICAL_ISSUES+=("PostgreSQL не запущен")
    RECOMMENDATIONS+=("Запустите PostgreSQL: systemctl start postgresql && systemctl enable postgresql")
fi

print_header "6. Проверка Redis"

if systemctl is-active --quiet redis-server; then
    print_success "Redis: активен"
    
    if redis-cli ping &> /dev/null; then
        print_success "Redis: отвечает на запросы"
    else
        print_error "Redis: не отвечает"
        WARNINGS+=("Redis не отвечает")
        RECOMMENDATIONS+=("Перезапустите Redis: systemctl restart redis-server")
    fi
else
    print_warning "Redis: не активен"
    WARNINGS+=("Redis не запущен")
    RECOMMENDATIONS+=("Запустите Redis: systemctl start redis-server && systemctl enable redis-server")
fi

print_header "7. Проверка Drupal"

if [ -d "$DRUPAL_DIR" ] && [ -f "$DRUPAL_DIR/web/index.php" ]; then
    print_success "Drupal файлы: установлены"
    
    # Проверка прав доступа
    if [ "$(stat -c %U $DRUPAL_DIR)" == "www-data" ]; then
        print_success "Права на файлы Drupal: корректные"
    else
        print_warning "Права на файлы Drupal: требуют исправления"
        WARNINGS+=("Неправильные права на файлы Drupal")
        RECOMMENDATIONS+=("Исправьте права: chown -R www-data:www-data $DRUPAL_DIR")
    fi
else
    print_error "Drupal файлы: не найдены"
    CRITICAL_ISSUES+=("Drupal не установлен")
    RECOMMENDATIONS+=("Установите Drupal: ./06-install-drupal.sh")
fi

print_header "8. Проверка HTTP/HTTPS доступности"

# Тест HTTP
if curl -s -o /dev/null http://localhost/ 2>/dev/null; then
    http_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null)
    if [ "$http_status" == "200" ] || [ "$http_status" == "301" ] || [ "$http_status" == "302" ]; then
        print_success "HTTP: сайт отвечает (код $http_status)"
    else
        print_warning "HTTP: сайт отвечает с кодом $http_status"
        WARNINGS+=("HTTP возвращает код $http_status")
    fi
else
    print_error "HTTP: сайт недоступен"
    CRITICAL_ISSUES+=("HTTP недоступен")
    RECOMMENDATIONS+=("Проверьте Nginx и Drupal конфигурацию")
fi

# Тест HTTPS
if curl -k -s -o /dev/null https://localhost/ 2>/dev/null; then
    https_status=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost/ 2>/dev/null)
    if [ "$https_status" == "200" ]; then
        print_success "HTTPS: сайт доступен (код $https_status)"
    else
        print_warning "HTTPS: сайт отвечает с кодом $https_status"
        WARNINGS+=("HTTPS возвращает код $https_status")
    fi
else
    print_error "HTTPS: сайт недоступен"
    WARNINGS+=("HTTPS недоступен")
    RECOMMENDATIONS+=("Настройте SSL: ./05-configure-ssl.sh")
fi

print_header "9. Сводка и рекомендации"

# Подсчет проблем
CRITICAL_COUNT=${#CRITICAL_ISSUES[@]}
WARNING_COUNT=${#WARNINGS[@]}
RECOMMENDATION_COUNT=${#RECOMMENDATIONS[@]}

echo
if [ $CRITICAL_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
    print_success "СИСТЕМА РАБОТАЕТ ОТЛИЧНО!"
    print_info "Все проверки пройдены успешно"
elif [ $CRITICAL_COUNT -eq 0 ]; then
    print_warning "СИСТЕМА РАБОТАЕТ ХОРОШО"
    print_info "Есть незначительные предупреждения: $WARNING_COUNT"
else
    print_error "СИСТЕМА ТРЕБУЕТ ВНИМАНИЯ"
    print_info "Критических проблем: $CRITICAL_COUNT"
    print_info "Предупреждений: $WARNING_COUNT"
fi

echo
print_info "📊 Статистика проблем:"
echo "   🔴 Критические: $CRITICAL_COUNT"
echo "   🟡 Предупреждения: $WARNING_COUNT"
echo "   🔧 Рекомендации: $RECOMMENDATION_COUNT"

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo
    print_error "КРИТИЧЕСКИЕ ПРОБЛЕМЫ:"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "   ❌ $issue"
        echo "   ❌ $issue" >> $REPORT_FILE
    done
fi

if [ $WARNING_COUNT -gt 0 ]; then
    echo
    print_warning "ПРЕДУПРЕЖДЕНИЯ:"
    for warning in "${WARNINGS[@]}"; do
        echo "   ⚠️  $warning"
        echo "   ⚠️  $warning" >> $REPORT_FILE
    done
fi

if [ $RECOMMENDATION_COUNT -gt 0 ]; then
    echo
    print_header "РЕКОМЕНДАЦИИ ПО ИСПРАВЛЕНИЮ"
    for i in "${!RECOMMENDATIONS[@]}"; do
        echo "   $((i+1)). ${RECOMMENDATIONS[$i]}"
        echo "   $((i+1)). ${RECOMMENDATIONS[$i]}" >> $REPORT_FILE
    done
fi

print_header "10. Быстрые исправления"

echo "🚀 КОМАНДЫ ДЛЯ БЫСТРОГО ИСПРАВЛЕНИЯ:"
echo

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo "# Исправление критических проблем:"
    echo "cd $(pwd)"
    echo "./fix-issues.sh  # Исправляет Nginx, PHP, OPcache"
    echo
fi

echo "# Перезапуск всех сервисов:"
echo "systemctl restart nginx php8.3-fpm postgresql redis-server"
echo "systemctl enable nginx php8.3-fpm postgresql redis-server"
echo

echo "# Проверка статуса:"
echo "systemctl status nginx php8.3-fpm postgresql redis-server"
echo

echo "# Проверка конфигурации:"
echo "nginx -t"
echo "php -m | grep opcache"
echo

print_header "11. Следующие шаги"

echo "📋 ПЛАН ДЕЙСТВИЙ:"
echo

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo "1. ❗ СРОЧНО: Исправьте критические проблемы"
    echo "   ./fix-issues.sh"
    echo
fi

echo "2. 🔍 Проверьте доступность сайта:"
echo "   curl -I http://$DOMAIN/"
echo "   curl -I https://$DOMAIN/"
echo

echo "3. 🌐 Откройте в браузере:"
echo "   http://$IP_ADDRESS/phpinfo.php (локальный тест)"
echo "   https://$DOMAIN/ (публичный доступ)"
echo

echo "4. 📊 Мониторинг:"
echo "   tail -f /var/log/nginx/error.log"
echo "   journalctl -u nginx.service -f"
echo

echo "5. 🔄 Повторите проверку:"
echo "   ./10-final-check-improved.sh"
echo

print_header "12. Файлы отчетов"

echo "📁 Отчет сохранен: $REPORT_FILE"
echo "📁 Логи системы:"
echo "   /var/log/nginx/error.log"
echo "   /var/log/php8.3-fpm.log"
echo "   /var/log/postgresql/postgresql-*-main.log"
echo

# Сохранение финального статуса
echo
echo "=== ФИНАЛЬНЫЙ СТАТУС ===" >> $REPORT_FILE
echo "Критических проблем: $CRITICAL_COUNT" >> $REPORT_FILE
echo "Предупреждений: $WARNING_COUNT" >> $REPORT_FILE
echo "Дата проверки: $(date)" >> $REPORT_FILE

if [ $CRITICAL_COUNT -eq 0 ] && [ $WARNING_COUNT -le 2 ]; then
    echo "СТАТУС: СИСТЕМА ГОТОВА К РАБОТЕ ✅" >> $REPORT_FILE
    echo
    print_success "СИСТЕМА ГОТОВА К РАБОТЕ!"
    exit 0
elif [ $CRITICAL_COUNT -eq 0 ]; then
    echo "СТАТУС: СИСТЕМА РАБОТОСПОСОБНА ⚠️" >> $REPORT_FILE
    echo
    print_warning "СИСТЕМА РАБОТОСПОСОБНА, НО ЕСТЬ ПРЕДУПРЕЖДЕНИЯ"
    exit 1
else
    echo "СТАТУС: ТРЕБУЕТСЯ ИСПРАВЛЕНИЕ ❌" >> $REPORT_FILE
    echo
    print_error "СИСТЕМА ТРЕБУЕТ ИСПРАВЛЕНИЯ КРИТИЧЕСКИХ ПРОБЛЕМ"
    exit 2
fi
