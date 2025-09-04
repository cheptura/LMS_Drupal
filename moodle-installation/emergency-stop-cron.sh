#!/bin/bash

# RTTI - Быстрая остановка Moodle Cron
# Одна команда для немедленной остановки

echo "🛑 БЫСТРАЯ ОСТАНОВКА MOODLE CRON"

# Остановка всех cron процессов
echo "Остановка процессов..."
pkill -f "cron.php" 2>/dev/null
pkill -f "cli/cron" 2>/dev/null
pkill -9 -f "cron.php" 2>/dev/null

# Отключение системного cron
if [ -f "/etc/cron.d/moodle" ]; then
    mv /etc/cron.d/moodle /etc/cron.d/moodle.disabled 2>/dev/null
fi

systemctl restart cron 2>/dev/null

echo "✅ ГОТОВО! Cron остановлен."
echo "💡 Продолжайте установку Moodle."
