#!/bin/bash

# RTTI Monitoring System - Полная автоматическая установка
# Сервер: lms.rtti.tj (92.242.60.172) - основной мониторинг
# Агенты: library.rtti.tj (92.242.61.204) - удаленный мониторинг

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                     RTTI Monitoring System - Установка                      ║"
echo "║                   Prometheus + Grafana + Alertmanager                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "📊 Сервер мониторинга: lms.rtti.tj (92.242.60.172)"
echo "📅 Дата: $(date)"
echo "🖥️  IP: $(hostname -I | awk '{print $1}')"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./install-monitoring.sh"
    exit 1
fi

# Проверка ОС
if ! lsb_release -d | grep -q "Ubuntu"; then
    echo "⚠️  Предупреждение: Скрипт тестировался на Ubuntu 24.04 LTS"
    read -p "   Продолжить? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Создание логов
LOG_DIR="/var/log/rtti-installation"
mkdir -p $LOG_DIR
INSTALL_LOG="$LOG_DIR/monitoring-install-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$INSTALL_LOG")
exec 2> >(tee -a "$INSTALL_LOG" >&2)

echo "📋 Лог установки: $INSTALL_LOG"
echo

# Массив шагов установки
STEPS=(
    "01-prepare-monitoring.sh:Подготовка системы для мониторинга"
    "02-install-prometheus.sh:Установка Prometheus сервера"
    "03-install-grafana.sh:Установка Grafana"
    "04-install-alertmanager.sh:Установка Alertmanager"
    "05-install-exporters.sh:Установка exporters (Node/Nginx/Postgres)"
    "06-configure-alerts.sh:Настройка правил алертов"
    "07-setup-dashboards.sh:Импорт дашбордов Grafana"
    "08-configure-remote.sh:Настройка мониторинга удаленных серверов"
    "09-setup-backup.sh:Настройка резервного копирования"
    "10-test-monitoring.sh:Тестирование системы мониторинга"
)

TOTAL_STEPS=${#STEPS[@]}
CURRENT_STEP=0
FAILED_STEPS=()

# Функция выполнения шага
execute_step() {
    local step_info=$1
    local script=$(echo $step_info | cut -d: -f1)
    local description=$(echo $step_info | cut -d: -f2)
    
    ((CURRENT_STEP++))
    
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║ Шаг $CURRENT_STEP/$TOTAL_STEPS: $description"
    echo "║ Скрипт: $script"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo
    
    if [ -f "./$script" ]; then
        chmod +x "./$script"
        
        echo "⏳ Выполнение: $script..."
        local start_time=$(date +%s)
        
        if "./$script"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            echo "✅ Шаг $CURRENT_STEP выполнен успешно за ${duration}с: $description"
            echo
            return 0
        else
            echo "❌ ОШИБКА в шаге $CURRENT_STEP: $description"
            echo "📁 Скрипт: $script"
            FAILED_STEPS+=("$CURRENT_STEP: $description ($script)")
            return 1
        fi
    else
        echo "❌ ФАЙЛ НЕ НАЙДЕН: $script"
        FAILED_STEPS+=("$CURRENT_STEP: Файл не найден ($script)")
        return 1
    fi
}

# Предварительные проверки
echo "🔍 Предварительные проверки..."
echo

# Проверка интернета
if ! ping -c 1 google.com &> /dev/null; then
    echo "❌ Нет подключения к интернету"
    exit 1
else
    echo "✅ Интернет подключение активно"
fi

# Проверка места на диске
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
REQUIRED_SPACE=5242880  # 5GB в KB

if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
    echo "❌ Недостаточно места на диске (требуется минимум 5GB)"
    exit 1
else
    echo "✅ Достаточно места на диске"
fi

# Проверка портов
REQUIRED_PORTS=(9090 3000 9093 9100 9113 9187)
for port in "${REQUIRED_PORTS[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "⚠️  Порт $port уже используется"
    else
        echo "✅ Порт $port свободен"
    fi
done

echo
echo "🚀 Начинаем установку системы мониторинга..."
echo

# Выполнение всех шагов
for step in "${STEPS[@]}"; do
    if ! execute_step "$step"; then
        echo
        echo "💥 УСТАНОВКА ПРЕРВАНА!"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "📊 Статистика:"
        echo "   ✅ Успешно выполнено: $((CURRENT_STEP - 1))/$TOTAL_STEPS шагов"
        echo "   ❌ Неудачных шагов: ${#FAILED_STEPS[@]}"
        echo
        
        if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
            echo "📋 Проблемные шаги:"
            for failed in "${FAILED_STEPS[@]}"; do
                echo "   ❌ $failed"
            done
            echo
        fi
        
        echo "🔧 Для продолжения после исправления ошибки:"
        echo "   ./$script"
        echo
        echo "📋 Или запустите установку заново:"
        echo "   ./install-monitoring.sh"
        echo
        echo "📄 Лог установки: $INSTALL_LOG"
        exit 1
    fi
    
    # Пауза между шагами
    if [ $CURRENT_STEP -lt $TOTAL_STEPS ]; then
        echo "⏳ Пауза 3 секунды..."
        sleep 3
        echo
    fi
done

# Успешное завершение
echo
echo "🎉 СИСТЕМА МОНИТОРИНГА УСТАНОВЛЕНА УСПЕШНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "📊 Статистика установки:"
echo "   ✅ Выполнено: $CURRENT_STEP/$TOTAL_STEPS шагов"
echo "   ⏱️  Время установки: $(date)"
echo "   📄 Лог: $INSTALL_LOG"
echo
echo "📊 Система мониторинга готова к использованию:"
echo
echo "🔍 Prometheus (метрики и алерты):"
echo "   🌐 URL: http://lms.rtti.tj:9090"
echo "   ⚙️ Конфигурация: /etc/prometheus/prometheus.yml"
echo
echo "📈 Grafana (дашборды):"
echo "   🌐 URL: http://lms.rtti.tj:3000"
echo "   👤 Пользователь: admin"
echo "   🔑 Пароль: RTTIMonitor2024!"
echo
echo "🚨 Alertmanager (уведомления):"
echo "   🌐 URL: http://lms.rtti.tj:9093"
echo "   ⚙️ Конфигурация: /etc/alertmanager/alertmanager.yml"
echo
echo "📡 Exporters (агенты сбора метрик):"
echo "   🖥️  Node Exporter: http://lms.rtti.tj:9100"
echo "   🌐 Nginx Exporter: http://lms.rtti.tj:9113"
echo "   🗄️ Postgres Exporter: http://lms.rtti.tj:9187"
echo
echo "📁 Важные файлы:"
echo "   📋 Данные доступа: /root/monitoring-credentials.txt"
echo "   📊 Данные метрик: /var/lib/prometheus/"
echo "   📈 Данные Grafana: /var/lib/grafana/"
echo "   ⚙️ Конфигурации: /etc/prometheus/ /etc/grafana/ /etc/alertmanager/"
echo
echo "🔧 Следующие шаги:"
echo "   1. Откройте http://lms.rtti.tj:3000 для доступа к Grafana"
echo "   2. Войдите с данными администратора"
echo "   3. Просмотрите предустановленные дашборды"
echo "   4. Настройте алерты и уведомления"
echo "   5. Добавьте мониторинг дополнительных серверов"
echo
echo "📊 Мониторинг серверов:"
echo "   🎓 Moodle LMS: lms.rtti.tj (92.242.60.172) - локальный"
echo "   📚 Drupal Library: library.rtti.tj (92.242.61.204) - удаленный"
echo
echo "🔗 Дополнительные настройки:"
echo "   📧 Email алерты: ./setup-email-alerts.sh admin@rtti.tj"
echo "   📱 Telegram: ./setup-telegram-alerts.sh"
echo "   🔒 SSL для мониторинга: ./setup-ssl-monitoring.sh"
echo
echo "✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
