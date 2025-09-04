#!/bin/bash

# RTTI Moodle - Диагностика и исправление PHP-FPM
# Скрипт для проверки и настройки PHP-FPM

echo "=== RTTI Moodle - Диагностика PHP-FPM ==="
echo "🔧 Проверка и исправление проблем с PHP-FPM"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Проверка установленных версий PHP..."
dpkg -l | grep php | grep -E "php[0-9].[0-9]" | grep -v dev | awk '{print $2}' | sort -u

echo
echo "2. Проверка активных PHP-FPM сервисов..."
systemctl list-units --type=service --state=active | grep php.*fpm

echo
echo "3. Проверка всех доступных PHP-FPM сервисов..."
systemctl list-unit-files | grep php.*fpm

echo
echo "4. Определение основной версии PHP..."
PHP_VERSION=$(php -v | head -n1 | cut -d" " -f2 | cut -d"." -f1-2)
echo "Основная версия PHP: $PHP_VERSION"

echo
echo "5. Проверка статуса PHP $PHP_VERSION FPM..."
if systemctl is-active --quiet php$PHP_VERSION-fpm; then
    echo "✅ PHP $PHP_VERSION FPM активен"
    systemctl status php$PHP_VERSION-fpm --no-pager
else
    echo "❌ PHP $PHP_VERSION FPM не активен"
    
    echo
    echo "6. Попытка установки и запуска PHP $PHP_VERSION FPM..."
    apt update
    apt install -y php$PHP_VERSION-fpm
    
    echo "7. Включение и запуск PHP $PHP_VERSION FPM..."
    systemctl enable php$PHP_VERSION-fpm
    systemctl start php$PHP_VERSION-fpm
    
    if systemctl is-active --quiet php$PHP_VERSION-fpm; then
        echo "✅ PHP $PHP_VERSION FPM успешно запущен"
    else
        echo "❌ Не удалось запустить PHP $PHP_VERSION FPM"
        echo "Проверьте логи: journalctl -u php$PHP_VERSION-fpm"
    fi
fi

echo
echo "8. Проверка конфигурации Nginx для PHP..."
NGINX_CONFIGS=$(find /etc/nginx -name "*.conf" -o -name "*sites-*" | grep -v ".dpkg")
for config in $NGINX_CONFIGS; do
    if [ -f "$config" ]; then
        if grep -q "fastcgi_pass.*php.*fpm" "$config"; then
            echo "Найдена PHP конфигурация в: $config"
            grep "fastcgi_pass" "$config" | head -3
        fi
    fi
done

echo
echo "9. Проверка сокетов PHP-FPM..."
find /var/run/php -name "*.sock" 2>/dev/null || echo "Сокеты PHP-FPM не найдены"

echo
echo "10. Рекомендации по исправлению..."
echo "Если PHP-FPM не работает:"
echo "- Установите: apt install php$PHP_VERSION-fpm"
echo "- Запустите: systemctl start php$PHP_VERSION-fpm"
echo "- Включите автозапуск: systemctl enable php$PHP_VERSION-fpm"

echo
echo "Если Nginx не может подключиться к PHP:"
echo "- Проверьте путь к сокету в конфигурации Nginx"
echo "- Стандартный путь: /var/run/php/php$PHP_VERSION-fpm.sock"
echo "- Тест конфигурации: nginx -t"
echo "- Перезапуск: systemctl reload nginx"

echo
echo "=== Диагностика завершена ==="
