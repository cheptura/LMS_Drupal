#!/bin/bash

# RTTI Moodle - Управление Cron
# Настройка и управление планировщиком задач Moodle

echo "=== RTTI Moodle - Управление Cron ==="
echo "🕐 Управление планировщиком задач Moodle"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

MOODLE_DIR="/var/www/moodle"

# Проверка существования Moodle
if [ ! -d "$MOODLE_DIR" ]; then
    echo "❌ Каталог Moodle не найден: $MOODLE_DIR"
    exit 1
fi

# Функция для отображения меню
show_menu() {
    echo "🔧 Выберите действие:"
    echo "1) Настроить системный cron (рекомендуется)"
    echo "2) Запустить cron один раз"
    echo "3) Остановить все запущенные cron процессы"
    echo "4) Проверить статус cron"
    echo "5) Показать логи cron"
    echo "6) Тест cron (без keep-alive)"
    echo "0) Выход"
    echo
    read -p "Введите номер: " choice
}

# Функция настройки системного cron
setup_system_cron() {
    echo "🔧 Настройка системного cron для Moodle..."
    
    # Создаем cron файл для Moodle
    cat > /etc/cron.d/moodle << EOF
# Moodle cron job - RTTI Configuration
# Выполняется каждую минуту для обработки задач
* * * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/cron.php --quiet >/dev/null 2>&1

# Очистка кэша каждые 4 часа
0 */4 * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/purge_caches.php >/dev/null 2>&1

# Проверка обновлений каждый день в 3:00
0 3 * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/check_for_updates.php >/dev/null 2>&1
EOF

    # Устанавливаем правильные права доступа
    chmod 644 /etc/cron.d/moodle
    chown root:root /etc/cron.d/moodle
    
    # Перезапускаем cron службу
    systemctl restart cron
    
    echo "✅ Системный cron настроен успешно"
    echo "ℹ️  Moodle cron будет выполняться каждую минуту автоматически"
    echo "ℹ️  Логи будут записываться в /var/log/syslog"
}

# Функция запуска cron один раз
run_cron_once() {
    echo "🏃 Запуск Moodle cron один раз..."
    
    echo "Выполнение cron задач..."
    sudo -u www-data php $MOODLE_DIR/admin/cli/cron.php --quiet
    
    if [ $? -eq 0 ]; then
        echo "✅ Cron выполнен успешно"
    else
        echo "❌ Ошибка выполнения cron"
    fi
}

# Функция остановки всех cron процессов
stop_cron_processes() {
    echo "🛑 Остановка всех запущенных Moodle cron процессов..."
    
    # Найти и завершить все процессы cron.php
    CRON_PIDS=$(pgrep -f "cron.php")
    
    if [ -n "$CRON_PIDS" ]; then
        echo "Найдены запущенные cron процессы: $CRON_PIDS"
        
        # Мягкое завершение
        echo "Попытка мягкого завершения..."
        kill $CRON_PIDS 2>/dev/null
        
        sleep 3
        
        # Проверяем, завершились ли процессы
        REMAINING_PIDS=$(pgrep -f "cron.php")
        if [ -n "$REMAINING_PIDS" ]; then
            echo "Принудительное завершение оставшихся процессов..."
            kill -9 $REMAINING_PIDS 2>/dev/null
        fi
        
        echo "✅ Все cron процессы остановлены"
    else
        echo "ℹ️  Запущенные cron процессы не найдены"
    fi
}

# Функция проверки статуса cron
check_cron_status() {
    echo "📊 Проверка статуса Moodle cron..."
    
    # Проверка системной службы cron
    echo "🔧 Статус службы cron:"
    systemctl is-active cron && echo "✅ Служба cron активна" || echo "❌ Служба cron неактивна"
    
    # Проверка файла конфигурации cron
    if [ -f "/etc/cron.d/moodle" ]; then
        echo "✅ Файл конфигурации cron найден: /etc/cron.d/moodle"
        echo "📄 Содержимое:"
        cat /etc/cron.d/moodle
    else
        echo "❌ Файл конфигурации cron не найден"
    fi
    
    # Проверка запущенных процессов
    CRON_PIDS=$(pgrep -f "cron.php")
    if [ -n "$CRON_PIDS" ]; then
        echo "🏃 Запущенные cron процессы:"
        ps aux | grep cron.php | grep -v grep
    else
        echo "ℹ️  Нет запущенных cron процессов"
    fi
    
    # Последние записи в логах
    echo "📝 Последние записи cron в системном логе:"
    journalctl -u cron --no-pager -n 5
}

# Функция просмотра логов
show_cron_logs() {
    echo "📝 Логи Moodle cron..."
    
    # Показываем записи из системного лога
    echo "🔍 Последние записи из системного лога:"
    journalctl -u cron --no-pager -n 20 | grep -i moodle || echo "Записи Moodle в системном логе не найдены"
    
    # Проверяем лог-файл Moodle, если существует
    MOODLE_LOG="$MOODLE_DIR/../moodledata/moodle.log"
    if [ -f "$MOODLE_LOG" ]; then
        echo "📄 Последние записи из лога Moodle:"
        tail -20 "$MOODLE_LOG"
    fi
}

# Функция тестового запуска
test_cron() {
    echo "🧪 Тестовый запуск Moodle cron..."
    
    echo "Запуск с подробным выводом (без keep-alive режима)..."
    sudo -u www-data php $MOODLE_DIR/admin/cli/cron.php --verbose
    
    echo "✅ Тестовый запуск завершен"
}

# Основной цикл
while true; do
    echo
    show_menu
    
    case $choice in
        1)
            setup_system_cron
            ;;
        2)
            run_cron_once
            ;;
        3)
            stop_cron_processes
            ;;
        4)
            check_cron_status
            ;;
        5)
            show_cron_logs
            ;;
        6)
            test_cron
            ;;
        0)
            echo "👋 Выход из программы"
            exit 0
            ;;
        *)
            echo "❌ Неверный выбор. Попробуйте снова."
            ;;
    esac
    
    echo
    read -p "Нажмите Enter для продолжения..."
done
