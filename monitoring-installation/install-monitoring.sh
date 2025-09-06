#!/bin/bash

# RTTI Monitoring System - Полная автоматическая установка
# Сервер: monitoring.omuzgorpro.tj (92.242.60.172) - центральный мониторинг
# Агенты: storage.omuzgorpro.tj (92.242.61.204) - удаленный мониторинг

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                     RTTI Monitoring System - Установка                      ║"
echo "║                   Prometheus + Grafana + Alertmanager                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "📊 Сервер мониторинга: monitoring.omuzgorpro.tj (92.242.60.172)"
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

# Загрузка всех необходимых скриптов
echo "📥 Загрузка скриптов установки..."
echo

GITHUB_RAW_URL="https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring-installation"
SCRIPTS_TO_DOWNLOAD=(
    "01-prepare-system.sh"
    "02-install-prometheus.sh"
    "03-install-grafana.sh"
    "04-install-alertmanager.sh"
    "05-install-exporters.sh"
    "06-configure-alerts.sh"
    "07-create-dashboards.sh"
    "08-optimize-monitoring.sh"
    "09-setup-backup.sh"
    "10-final-check.sh"
)

# Функция загрузки скрипта
download_script() {
    local script_name=$1
    echo "📥 Загружается: $script_name..."
    
    if wget -q --timeout=10 "$GITHUB_RAW_URL/$script_name" -O "$script_name"; then
        chmod +x "$script_name"
        echo "✅ Загружен: $script_name"
        return 0
    else
        echo "❌ Ошибка загрузки: $script_name"
        return 1
    fi
}

# Загрузка всех скриптов
DOWNLOAD_FAILED=0
for script in "${SCRIPTS_TO_DOWNLOAD[@]}"; do
    if ! download_script "$script"; then
        DOWNLOAD_FAILED=1
    fi
done

if [ $DOWNLOAD_FAILED -eq 1 ]; then
    echo
    echo "❌ Ошибка загрузки скриптов из GitHub"
    echo "🔧 Проверьте:"
    echo "   1. Подключение к интернету"
    echo "   2. Доступность GitHub репозитория"
    echo "   3. Правильность URL в скрипте"
    echo
    echo "📁 URL репозитория: $GITHUB_RAW_URL"
    exit 1
fi

echo "✅ Все скрипты загружены успешно"
echo

# Массив шагов установки
STEPS=(
    "01-prepare-system.sh:Подготовка системы для мониторинга"
    "02-install-prometheus.sh:Установка Prometheus сервера"
    "03-install-grafana.sh:Установка Grafana"
    "04-install-alertmanager.sh:Установка Alertmanager"
    "05-install-exporters.sh:Установка экспортеров метрик"
    "06-configure-alerts.sh:Настройка правил алертов"
    "07-create-dashboards.sh:Создание дашбордов Grafana"
    "08-optimize-monitoring.sh:Оптимизация мониторинга"
    "09-setup-backup.sh:Настройка системы резервного копирования"
    "10-final-check.sh:Финальная проверка системы"
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
echo "   🌐 URL: http://monitoring.omuzgorpro.tj:9090"
echo "   ⚙️ Конфигурация: /etc/prometheus/prometheus.yml"
echo
echo "📈 Grafana (дашборды):"
echo "   🌐 URL: http://monitoring.omuzgorpro.tj:3000"
echo "   👤 Пользователь: admin"
echo "   🔑 Пароль: RTTIMonitor2024!"
echo
echo "🚨 Alertmanager (уведомления):"
echo "   🌐 URL: http://monitoring.omuzgorpro.tj:9093"
echo "   ⚙️ Конфигурация: /etc/alertmanager/alertmanager.yml"
echo
echo "📡 Exporters (агенты сбора метрик):"
echo "   🖥️  Node Exporter: http://omuzgorpro.tj:9100"
echo "   🌐 Nginx Exporter: http://omuzgorpro.tj:9113"
echo "   🗄️ Postgres Exporter: http://omuzgorpro.tj:9187"
echo
echo "📁 Важные файлы:"
echo "   📋 Данные доступа: /root/monitoring-credentials.txt"
echo "   📊 Данные метрик: /var/lib/prometheus/"
echo "   📈 Данные Grafana: /var/lib/grafana/"
echo "   ⚙️ Конфигурации: /etc/prometheus/ /etc/grafana/ /etc/alertmanager/"
echo
echo "🔧 Следующие шаги:"
echo "   1. Откройте http://monitoring.omuzgorpro.tj:3000 для доступа к Grafana"
echo "   2. Войдите с данными администратора"
echo "   3. Просмотрите предустановленные дашборды"
echo "   4. Настройте алерты и уведомления"
echo "   5. Добавьте мониторинг дополнительных серверов"
echo
echo "📊 Мониторинг серверов:"
echo "   🎓 Moodle LMS: omuzgorpro.tj (92.242.60.172) - ЦЕНТРАЛЬНЫЙ СЕРВЕР"
echo "   📚 Drupal Library: storage.omuzgorpro.tj (92.242.61.204) - удаленные агенты"
echo "   🌐 Веб-интерфейс: monitoring.omuzgorpro.tj"
echo
echo "🔗 Дополнительные настройки:"
echo "   📧 Email алерты: ./setup-email-alerts.sh admin@omuzgorpro.tj"
echo "   📱 Telegram: ./setup-telegram-alerts.sh"
echo "   🔒 SSL для мониторинга: ./setup-ssl-monitoring.sh"
echo
echo "✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
