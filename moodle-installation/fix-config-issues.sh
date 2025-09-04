#!/bin/bash

# RTTI Moodle - Быстрое исправление проблем конфигурации
# Скрипт для решения типичных проблем при настройке Moodle

echo "=== RTTI Moodle - Исправление проблем конфигурации ==="
echo "🔧 Диагностика и исправление типичных проблем"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Проверка существования файлов учетных данных..."
if [ ! -f "/root/moodle-db-credentials.txt" ]; then
    echo "❌ Файл /root/moodle-db-credentials.txt не найден"
    echo "Запустите сначала: ./03-install-database.sh"
    exit 1
else
    echo "✅ Файл учетных данных БД найден"
fi

if [ ! -f "/root/moodle-redis-credentials.txt" ]; then
    echo "❌ Файл /root/moodle-redis-credentials.txt не найден"
    echo "Запустите сначала: ./04-install-cache.sh"
    exit 1
else
    echo "✅ Файл учетных данных Redis найден"
fi

echo
echo "2. Проверка статуса сервисов..."
services=("postgresql" "redis-server" "nginx")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: активен"
    else
        echo "❌ $service: не активен"
        echo "Попытка запуска $service..."
        systemctl start $service
        if systemctl is-active --quiet $service; then
            echo "✅ $service успешно запущен"
        else
            echo "❌ Не удалось запустить $service"
        fi
    fi
done

echo
echo "3. Проверка PHP-FPM..."
PHP_VERSION=$(php -v | head -n1 | cut -d" " -f2 | cut -d"." -f1-2)
echo "Версия PHP: $PHP_VERSION"

if systemctl is-active --quiet php$PHP_VERSION-fpm; then
    echo "✅ PHP $PHP_VERSION FPM: активен"
else
    echo "❌ PHP $PHP_VERSION FPM: не активен"
    echo "Попытка запуска..."
    systemctl start php$PHP_VERSION-fpm 2>/dev/null
    if systemctl is-active --quiet php$PHP_VERSION-fpm; then
        echo "✅ PHP $PHP_VERSION FPM успешно запущен"
    else
        echo "❌ Не удалось запустить PHP $PHP_VERSION FPM"
        echo "Попробуйте: apt install php$PHP_VERSION-fpm"
    fi
fi

echo
echo "4. Проверка базы данных..."
if sudo -u postgres psql -d moodle -c "SELECT version();" >/dev/null 2>&1; then
    echo "✅ База данных moodle доступна"
else
    echo "❌ База данных moodle недоступна"
    echo "Проверьте:"
    echo "- Запущен ли PostgreSQL: systemctl status postgresql"
    echo "- Создана ли база: sudo -u postgres psql -l | grep moodle"
fi

echo
echo "5. Проверка Redis..."
REDIS_PASSWORD=""
if [ -f "/root/moodle-redis-credentials.txt" ]; then
    REDIS_PASSWORD=$(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print $2}')
fi

if [ -n "$REDIS_PASSWORD" ]; then
    if redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        echo "✅ Redis доступен с паролем"
    else
        echo "❌ Redis недоступен с паролем"
    fi
else
    if redis-cli ping >/dev/null 2>&1; then
        echo "✅ Redis доступен без пароля"
    else
        echo "❌ Redis недоступен"
    fi
fi

echo
echo "6. Проверка директорий Moodle..."
if [ -d "/var/www/moodle" ]; then
    echo "✅ Директория Moodle существует"
    echo "Размер: $(du -sh /var/www/moodle | cut -f1)"
else
    echo "❌ Директория Moodle не найдена"
    echo "Запустите: ./06-download-moodle.sh"
fi

if [ -d "/var/moodledata" ]; then
    echo "✅ Директория данных Moodle существует"
    echo "Владелец: $(stat -c '%U:%G' /var/moodledata)"
else
    echo "❌ Директория данных Moodle не найдена"
    echo "Создание /var/moodledata..."
    mkdir -p /var/moodledata
    chown -R www-data:www-data /var/moodledata
    chmod 755 /var/moodledata
    echo "✅ Директория данных создана"
fi

echo
echo "7. Проверка конфигурации Nginx..."
if nginx -t >/dev/null 2>&1; then
    echo "✅ Конфигурация Nginx корректна"
else
    echo "❌ Ошибка в конфигурации Nginx"
    echo "Детали:"
    nginx -t
fi

echo
echo "8. Проверка прав доступа..."
echo "Исправление прав доступа для Moodle..."
if [ -d "/var/www/moodle" ]; then
    chown -R www-data:www-data /var/www/moodle
    chmod -R 755 /var/www/moodle
    echo "✅ Права на файлы Moodle исправлены"
fi

if [ -d "/var/moodledata" ]; then
    chown -R www-data:www-data /var/moodledata
    chmod -R 755 /var/moodledata
    echo "✅ Права на данные Moodle исправлены"
fi

echo
echo "=== Диагностика завершена ==="
echo
echo "Если проблемы остались:"
echo "1. Проверьте логи: tail -f /var/log/nginx/error.log"
echo "2. Проверьте PHP: tail -f /var/log/php$PHP_VERSION-fpm.log"
echo "3. Перезапустите скрипт: ./07-configure-moodle.sh"
echo
