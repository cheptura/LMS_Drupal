#!/bin/bash

# ЭКСТРЕННАЯ ОСТАНОВКА MOODLE CRON
# Используйте если cron зависает во время установки

echo "🚨 ЭКСТРЕННАЯ ОСТАНОВКА MOODLE CRON 🚨"
echo "=================================================="

# Показываем что происходит
echo "🔍 Поиск запущенных cron процессов..."
CRON_PROCESSES=$(ps aux | grep -E "(cron\.php|cli/cron)" | grep -v grep)

if [ -n "$CRON_PROCESSES" ]; then
    echo "📋 Найденные процессы:"
    echo "$CRON_PROCESSES"
    echo
    
    echo "🛑 Остановка всех cron процессов..."
    
    # Мягкая остановка
    pkill -f "cron.php" 2>/dev/null
    pkill -f "cli/cron" 2>/dev/null
    
    sleep 2
    
    # Принудительная остановка
    pkill -9 -f "cron.php" 2>/dev/null
    pkill -9 -f "cli/cron" 2>/dev/null
    
    echo "✅ Процессы остановлены"
else
    echo "ℹ️  Запущенные cron процессы не найдены"
fi

# Отключаем системный cron временно
if [ -f "/etc/cron.d/moodle" ]; then
    echo "🔧 Временное отключение системного cron..."
    mv /etc/cron.d/moodle /etc/cron.d/moodle.disabled 2>/dev/null
    systemctl restart cron 2>/dev/null
    echo "✅ Системный cron отключен"
fi

echo
echo "🎯 CRON ОСТАНОВЛЕН УСПЕШНО!"
echo "=================================================="
echo "✅ Теперь можно продолжить установку Moodle"
echo "🔄 После установки для восстановления cron:"
echo "   sudo mv /etc/cron.d/moodle.disabled /etc/cron.d/moodle"
echo "   sudo systemctl restart cron"
echo "=================================================="
