#!/bin/bash

# RTTI Moodle - Восстановление и завершение установки
# Исправляет все проблемы и завершает установку Moodle

echo "=== RTTI Moodle - Восстановление установки ==="
echo "🔧 Исправление проблем и завершение установки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

MOODLE_DIR="/var/www/moodle"

echo "🔍 Анализ текущего состояния..."

# Проверка 1: Установлен ли Moodle
if [ ! -d "$MOODLE_DIR" ]; then
    echo "❌ Каталог Moodle не найден. Запустите полную установку:"
    echo "   sudo ./install-moodle.sh"
    exit 1
fi

# Проверка 2: Есть ли config.php
if [ -f "$MOODLE_DIR/config.php" ]; then
    echo "ℹ️  Найден файл конфигурации Moodle"
    CONFIG_EXISTS=true
else
    echo "ℹ️  Файл конфигурации не найден"
    CONFIG_EXISTS=false
fi

# Проверка 3: Установлена ли база данных
DB_INSTALLED=$(sudo -u postgres psql -d moodle -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'mdl_config');" -t 2>/dev/null | tr -d ' ')

if [ "$DB_INSTALLED" = "t" ]; then
    echo "ℹ️  База данных Moodle уже установлена"
    DB_EXISTS=true
else
    echo "ℹ️  База данных Moodle не установлена"
    DB_EXISTS=false
fi

echo
echo "📋 План восстановления:"

# Шаг 1: Исправить PHP конфигурацию
echo "1️⃣  Исправление конфигурации PHP..."
if [ -f "./fix-php-config.sh" ]; then
    chmod +x ./fix-php-config.sh
    ./fix-php-config.sh
    if [ $? -eq 0 ]; then
        echo "✅ PHP конфигурация исправлена"
    else
        echo "❌ Ошибка исправления PHP конфигурации"
        exit 1
    fi
else
    echo "❌ Скрипт fix-php-config.sh не найден"
    exit 1
fi

# Шаг 2: Исправить веб-сервер если нужно
echo
echo "2️⃣  Проверка веб-сервера..."
if ! systemctl is-active --quiet nginx; then
    echo "🔧 Перезапуск Nginx..."
    systemctl restart nginx
fi

if ! systemctl is-active --quiet php8.3-fpm; then
    echo "🔧 Перезапуск PHP-FPM..."
    systemctl restart php8.3-fpm
fi

# Шаг 3: Определить стратегию установки
echo
echo "3️⃣  Определение стратегии установки..."

if [ "$CONFIG_EXISTS" = true ] && [ "$DB_EXISTS" = true ]; then
    echo "✅ Moodle уже установлен. Проверяем целостность..."
    
    # Проверка через CLI
    cd $MOODLE_DIR
    MOODLE_STATUS=$(sudo -u www-data php admin/cli/check_database_schema.php 2>/dev/null | grep -c "error" || echo "0")
    
    if [ "$MOODLE_STATUS" -eq 0 ]; then
        echo "✅ Moodle установлен и работает корректно"
        echo "🌐 Доступ: https://lms.rtti.tj"
    else
        echo "⚠️  Обнаружены проблемы, выполняем обновление..."
        sudo -u www-data php admin/cli/upgrade.php --non-interactive
    fi
    
elif [ "$CONFIG_EXISTS" = true ] && [ "$DB_EXISTS" = false ]; then
    echo "🔄 Завершение установки базы данных..."
    
    cd $MOODLE_DIR
    
    # Получаем пароль администратора
    ADMIN_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)
    
    # Установка только базы данных
    sudo -u www-data php admin/cli/install_database.php \
        --agree-license \
        --fullname="RTTI Learning Management System" \
        --shortname="RTTI LMS" \
        --adminuser=admin \
        --adminpass=$ADMIN_PASSWORD \
        --adminemail=admin@rtti.tj
    
    if [ $? -eq 0 ]; then
        echo "✅ База данных Moodle установлена успешно"
        echo "🔑 Администратор: admin"
        echo "🔐 Пароль: $ADMIN_PASSWORD"
        echo "📧 Email: admin@rtti.tj"
        
        # Сохраняем данные
        echo "Данные администратора Moodle RTTI:" > /var/log/moodle-admin-recovery.log
        echo "Дата восстановления: $(date)" >> /var/log/moodle-admin-recovery.log
        echo "Пользователь: admin" >> /var/log/moodle-admin-recovery.log
        echo "Пароль: $ADMIN_PASSWORD" >> /var/log/moodle-admin-recovery.log
        echo "Email: admin@rtti.tj" >> /var/log/moodle-admin-recovery.log
        echo "URL: https://lms.rtti.tj" >> /var/log/moodle-admin-recovery.log
        
        chmod 600 /var/log/moodle-admin-recovery.log
    else
        echo "❌ Ошибка установки базы данных"
        exit 1
    fi
    
else
    echo "🆕 Запуск полной установки..."
    
    # Удаляем неполные файлы
    if [ "$CONFIG_EXISTS" = true ]; then
        echo "🗑️  Удаление неполного файла конфигурации..."
        rm -f "$MOODLE_DIR/config.php"
    fi
    
    # Запускаем полную установку
    if [ -f "./08-install-moodle.sh" ]; then
        chmod +x ./08-install-moodle.sh
        ./08-install-moodle.sh
    else
        echo "❌ Скрипт 08-install-moodle.sh не найден"
        exit 1
    fi
fi

# Шаг 4: Настройка cron
echo
echo "4️⃣  Настройка планировщика задач..."
if [ -f "./manage-cron.sh" ]; then
    chmod +x ./manage-cron.sh
    
    # Автоматическая настройка системного cron
    cat > /etc/cron.d/moodle << EOF
# Moodle cron job - RTTI Configuration
* * * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/cron.php --quiet >/dev/null 2>&1
0 */4 * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/purge_caches.php >/dev/null 2>&1
EOF
    
    chmod 644 /etc/cron.d/moodle
    systemctl restart cron
    
    echo "✅ Планировщик задач настроен"
else
    echo "⚠️  Скрипт manage-cron.sh не найден, настройте cron вручную"
fi

# Шаг 5: Финальные настройки
echo
echo "5️⃣  Финальные настройки..."

# Проверяем права доступа
chown -R www-data:www-data /var/moodledata
chmod -R 755 /var/moodledata

# Очистка кэша
if [ -d "$MOODLE_DIR" ]; then
    cd $MOODLE_DIR
    sudo -u www-data php admin/cli/purge_caches.php >/dev/null 2>&1
fi

echo
echo "🎉 Восстановление завершено!"
echo "════════════════════════════════════════════════════════════"
echo "🌐 Доступ к Moodle: https://lms.rtti.tj"
echo "📊 Панель администратора: https://lms.rtti.tj/admin"
echo "📄 Логи сохранены в: /var/log/moodle-admin-recovery.log"
echo "🔧 Для управления cron: sudo ./manage-cron.sh"
echo "════════════════════════════════════════════════════════════"
