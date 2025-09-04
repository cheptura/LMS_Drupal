#!/bin/bash

# RTTI Moodle - Экстренная остановка Cron
# Останавливает все запущенные Moodle cron процессы

echo "=== RTTI Moodle - Экстренная остановка Cron ==="
echo "🛑 Немедленная остановка всех cron процессов"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "Используйте: sudo $0"
    exit 1
fi

echo "🔍 Поиск запущенных Moodle cron процессов..."

# Найти все процессы связанные с cron.php
CRON_PIDS=$(pgrep -f "cron.php" 2>/dev/null)
CLI_PIDS=$(pgrep -f "cli/cron" 2>/dev/null)
PHP_CRON_PIDS=$(ps aux | grep "php.*cron" | grep -v grep | awk '{print $2}')

ALL_PIDS="$CRON_PIDS $CLI_PIDS $PHP_CRON_PIDS"
UNIQUE_PIDS=$(echo $ALL_PIDS | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [ -n "$UNIQUE_PIDS" ]; then
    echo "📋 Найдены следующие процессы:"
    ps aux | grep -E "(cron\.php|cli/cron)" | grep -v grep
    echo
    echo "🔢 PID процессов: $UNIQUE_PIDS"
    echo
    
    # Мягкое завершение
    echo "1️⃣ Попытка мягкого завершения (SIGTERM)..."
    for pid in $UNIQUE_PIDS; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "   Останавливаем процесс $pid..."
            kill "$pid" 2>/dev/null
        fi
    done
    
    # Ждем 5 секунд
    echo "⏱️  Ожидание 5 секунд..."
    sleep 5
    
    # Проверяем, что завершилось
    REMAINING_PIDS=$(pgrep -f "cron.php" 2>/dev/null)
    REMAINING_CLI=$(pgrep -f "cli/cron" 2>/dev/null)
    REMAINING_ALL="$REMAINING_PIDS $REMAINING_CLI"
    
    if [ -n "$REMAINING_ALL" ]; then
        echo "⚠️  Некоторые процессы все еще работают"
        echo "2️⃣ Принудительное завершение (SIGKILL)..."
        
        for pid in $REMAINING_ALL; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "   Принудительно останавливаем процесс $pid..."
                kill -9 "$pid" 2>/dev/null
            fi
        done
        
        sleep 2
    fi
    
    # Финальная проверка
    FINAL_CHECK=$(pgrep -f "cron.php" 2>/dev/null)
    if [ -z "$FINAL_CHECK" ]; then
        echo "✅ Все cron процессы успешно остановлены"
    else
        echo "❌ Некоторые процессы все еще работают: $FINAL_CHECK"
        echo "🔧 Попробуйте перезагрузить сервер: sudo reboot"
    fi
else
    echo "ℹ️  Запущенные cron процессы не найдены"
fi

echo
echo "3️⃣ Отключение автоматического cron на время установки..."

# Временно отключаем cron файл
if [ -f "/etc/cron.d/moodle" ]; then
    echo "🔧 Временное отключение системного cron..."
    mv /etc/cron.d/moodle /etc/cron.d/moodle.disabled
    echo "✅ Системный cron отключен (файл переименован в moodle.disabled)"
else
    echo "ℹ️  Системный cron файл не найден"
fi

# Перезапускаем cron службу
echo "🔄 Перезапуск cron службы..."
systemctl restart cron

echo
echo "4️⃣ Проверка текущего состояния..."
CURRENT_CRON=$(pgrep -f "cron.php" 2>/dev/null)
if [ -z "$CURRENT_CRON" ]; then
    echo "✅ Cron процессы остановлены"
else
    echo "❌ Все еще работают процессы: $CURRENT_CRON"
fi

echo
echo "🎯 CRON ОСТАНОВЛЕН!"
echo "════════════════════════════════════════════════════════════"
echo "✅ Теперь можно безопасно продолжить установку Moodle"
echo "🔧 После завершения установки запустите для восстановления cron:"
echo "   sudo ./manage-cron.sh"
echo "   Выберите: 1) Настроить системный cron"
echo "════════════════════════════════════════════════════════════"
echo
echo "💡 Если нужно остановить cron снова во время установки:"
echo "   Нажмите Ctrl+C в терминале установки"
echo "   Затем запустите: sudo ./stop-cron.sh"
