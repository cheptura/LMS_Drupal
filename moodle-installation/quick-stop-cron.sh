#!/bin/bash
# Быстрое решение для остановки cron во время установки Moodle

echo "🛑 ОСТАНОВКА MOODLE CRON..."

# Убиваем все процессы cron
pkill -f "cron.php" 2>/dev/null
pkill -f "cli/cron" 2>/dev/null  
pkill -9 -f "cron.php" 2>/dev/null

echo "✅ Готово! Продолжайте установку."
