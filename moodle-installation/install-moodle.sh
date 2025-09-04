#!/bin/bash

# RTTI Moodle LMS - Полная автоматическая установка
# Сервер: lms.rtti.tj (92.242.60.172)
# Версия: Moodle 5.0+

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        RTTI Moodle LMS - Установка                          ║"
echo "║                             Версия: 5.0+                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
echo "🎓 Сервер: lms.rtti.tj (92.242.60.172)"
echo "📅 Дата: $(date)"
echo "🖥️  IP: $(hostname -I | awk '{print $1}')"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./install-moodle.sh"
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
INSTALL_LOG="$LOG_DIR/moodle-install-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$INSTALL_LOG")
exec 2> >(tee -a "$INSTALL_LOG" >&2)

echo "📋 Лог установки: $INSTALL_LOG"
echo

# Массив шагов установки
STEPS=(
    "01-prepare-system.sh:Подготовка системы Ubuntu"
    "02-install-webserver.sh:Установка Nginx + PHP 8.2"
    "03-install-database.sh:Установка PostgreSQL 16"
    "04-install-cache.sh:Установка Redis"
    "05-configure-domain.sh:Настройка домена lms.rtti.tj"
    "06-install-ssl.sh:Установка SSL сертификатов"
    "07-download-moodle.sh:Загрузка Moodle 5.0+"
    "08-configure-moodle.sh:Конфигурация и установка Moodle"
    "09-optimize-moodle.sh:Оптимизация производительности"
    "10-backup-setup.sh:Настройка резервного копирования"
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
REQUIRED_SPACE=10485760  # 10GB в KB

if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
    echo "❌ Недостаточно места на диске (требуется минимум 10GB)"
    exit 1
else
    echo "✅ Достаточно места на диске"
fi

echo
echo "🚀 Начинаем установку Moodle LMS..."
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
        echo "   ./install-moodle.sh"
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
echo "🎉 MOODLE LMS УСТАНОВЛЕН УСПЕШНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "📊 Статистика установки:"
echo "   ✅ Выполнено: $CURRENT_STEP/$TOTAL_STEPS шагов"
echo "   ⏱️  Время установки: $(date)"
echo "   📄 Лог: $INSTALL_LOG"
echo
echo "🎓 Moodle LMS готов к использованию:"
echo "   🌐 URL: https://lms.rtti.tj"
echo "   👤 Администратор: admin"
echo "   🔑 Пароль: RTTIAdmin2024!"
echo "   📧 Email: admin@rtti.tj"
echo
echo "📁 Важные файлы:"
echo "   📋 Данные админа: /root/moodle-admin-credentials.txt"
echo "   🗄️ Данные БД: /root/moodle-db-credentials.txt"
echo "   ⚙️ Конфигурация: /var/www/html/moodle/config.php"
echo "   📂 Данные: /var/moodledata/"
echo
echo "🔧 Следующие шаги:"
echo "   1. Откройте https://lms.rtti.tj в браузере"
echo "   2. Войдите с данными администратора"
echo "   3. Настройте систему под ваши потребности"
echo "   4. Создайте курсы и добавьте пользователей"
echo
echo "📊 Мониторинг:"
echo "   Установите систему мониторинга:"
echo "   cd ../monitoring-installation && sudo ./install-monitoring.sh"
echo
echo "✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
