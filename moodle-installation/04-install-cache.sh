#!/bin/bash

# RTTI Moodle - Шаг 4: Установка системы кэширования
# Сервер: lms.rtti.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 4: Установка Redis ==="
echo "🔄 Настройка системы кэширования"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Установка Redis сервера..."
apt install -y redis-server

echo "2. Создание резервной копии конфигурации..."
REDIS_CONF="/etc/redis/redis.conf"
cp $REDIS_CONF ${REDIS_CONF}.backup

echo "3. Настройка Redis для Moodle..."
echo "3. Настройка Redis для Moodle..."
# Привязка к localhost для безопасности
sed -i 's/^bind 127.0.0.1/bind 127.0.0.1/' $REDIS_CONF

# Порт по умолчанию
sed -i 's/^port 6379/port 6379/' $REDIS_CONF

# Настройки памяти
sed -i 's/^# maxmemory <bytes>/maxmemory 256mb/' $REDIS_CONF
sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' $REDIS_CONF

# Настройки сохранения
sed -i 's/^save 900 1/save 900 1/' $REDIS_CONF
sed -i 's/^save 300 10/save 300 10/' $REDIS_CONF
sed -i 's/^save 60 10000/save 60 10000/' $REDIS_CONF

# Настройки RDB
sed -i 's/^# rdbcompression yes/rdbcompression yes/' $REDIS_CONF
sed -i 's/^# rdbchecksum yes/rdbchecksum yes/' $REDIS_CONF

echo "4. Генерация пароля для Redis..."
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Безопасное добавление пароля в конфиг
echo "Настройка аутентификации Redis..."
# Убираем все старые настройки requirepass
sed -i '/^requirepass/d' $REDIS_CONF
sed -i '/^# requirepass/d' $REDIS_CONF
# Добавляем новый пароль
echo "requirepass $REDIS_PASSWORD" >> $REDIS_CONF

echo "5. Включение и запуск Redis..."
systemctl enable redis-server
systemctl restart redis-server

# Безопасное добавление пароля в конфиг
echo "Настройка аутентификации Redis..."
# Убираем все старые настройки requirepass
sed -i '/^requirepass/d' $REDIS_CONF
sed -i '/^# requirepass/d' $REDIS_CONF
# Добавляем новый пароль
echo "requirepass $REDIS_PASSWORD" >> $REDIS_CONF

echo "5. Включение и запуск Redis..."
systemctl enable redis-server
systemctl restart redis-server

echo "6. Ожидание запуска Redis..."
sleep 5

echo "7. Проверка статуса Redis..."
if systemctl is-active --quiet redis-server; then
    echo "✅ Redis сервер запущен"
else
    echo "❌ Redis сервер не запустился"
    systemctl status redis-server --no-pager
    exit 1
fi

echo "8. Проверка аутентификации Redis..."
# Тестируем подключение с паролем
if redis-cli -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
    echo "✅ Redis аутентификация работает"
else
    echo "⚠️ Проблема с аутентификацией Redis, попробуем без пароля..."
    if redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis работает без аутентификации"
        # Очищаем пароль для дальнейшего использования
        REDIS_PASSWORD=""
    else
        echo "❌ Redis недоступен"
        exit 1
    fi
fi
systemctl status redis-server --no-pager -l

echo "9. Проверка PHP расширения Redis..."
php -m | grep redis
if [ $? -eq 0 ]; then
    echo "✅ PHP расширение Redis установлено"
else
    echo "❌ PHP расширение Redis не найдено"
    exit 1
fi

echo "10. Настройка PHP для работы с Redis..."

# Автоматическое определение версии PHP
PHP_VERSION=""
for version in 8.3 8.2 8.1 8.0; do
    if [ -f "/etc/php/$version/fpm/php.ini" ]; then
        PHP_VERSION=$version
        break
    fi
done

if [ -z "$PHP_VERSION" ]; then
    echo "⚠️ PHP не найден. Возможно, веб-сервер еще не установлен."
    echo "Пропускаем настройку PHP для Redis..."
else
    echo "📍 Найдена версия PHP: $PHP_VERSION"
    PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
    
    # Увеличиваем лимиты для сессий
    sed -i 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 3600/' $PHP_INI
    echo "✅ Настройки PHP обновлены"
fi

echo "11. Сохранение данных подключения к Redis..."
if [ ! -z "$REDIS_PASSWORD" ] && [ "$REDIS_PASSWORD" != "" ]; then
    cat > /root/moodle-redis-credentials.txt << EOF
# Данные подключения к Redis для Moodle
# Дата создания: $(date)
# Сервер: lms.rtti.tj ($(hostname -I | awk '{print $1}'))

Хост: 127.0.0.1
Порт: 6379
Пароль: $REDIS_PASSWORD

# Команда для подключения:
# redis-cli -a '$REDIS_PASSWORD'

# Для тестирования:
# redis-cli -a '$REDIS_PASSWORD' ping

# Конфигурация для Moodle config.php:
# \$CFG->session_handler_class = '\core\session\redis';
# \$CFG->session_redis_host = '127.0.0.1';
# \$CFG->session_redis_port = 6379;
# \$CFG->session_redis_auth = '$REDIS_PASSWORD';
# \$CFG->session_redis_database = 0;
# \$CFG->session_redis_acquire_lock_timeout = 120;
# \$CFG->session_redis_lock_expire = 7200;
EOF
else
    cat > /root/moodle-redis-credentials.txt << EOF
# Данные подключения к Redis для Moodle
# Дата создания: $(date)
# Сервер: lms.rtti.tj ($(hostname -I | awk '{print $1}'))

Хост: 127.0.0.1
Порт: 6379
Пароль: (без аутентификации)

# Команда для подключения:
# redis-cli

# Для тестирования:
# redis-cli ping

# Конфигурация для Moodle config.php:
# \$CFG->session_handler_class = '\core\session\redis';
# \$CFG->session_redis_host = '127.0.0.1';
# \$CFG->session_redis_port = 6379;
# // \$CFG->session_redis_auth = ''; // Пароль не нужен
# \$CFG->session_redis_database = 0;
# \$CFG->session_redis_acquire_lock_timeout = 120;
# \$CFG->session_redis_lock_expire = 7200;
EOF
fi

chmod 600 /root/moodle-redis-credentials.txt

echo "12. Создание скрипта мониторинга Redis..."
cat > /root/redis-monitor.sh << EOF
#!/bin/bash
echo "=== Redis Status ==="
systemctl status redis-server --no-pager
echo
echo "=== Redis Info ==="
if [ -f "/root/moodle-redis-credentials.txt" ]; then
    REDIS_PASS=\$(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print \$2}')
    if [ ! -z "\$REDIS_PASS" ] && [ "\$REDIS_PASS" != "" ]; then
        redis-cli -a "\$REDIS_PASS" info memory
        echo
        echo "=== Redis Connected Clients ==="
        redis-cli -a "\$REDIS_PASS" info clients
    else
        redis-cli info memory
        echo
        echo "=== Redis Connected Clients ==="
        redis-cli info clients
    fi
else
    redis-cli info memory
    echo
    echo "=== Redis Connected Clients ==="
    redis-cli info clients
fi
EOF

chmod +x /root/redis-monitor.sh

echo "13. Перезапуск PHP-FPM для применения настроек..."

# Автоматическое определение и перезапуск PHP-FPM
PHP_FPM_RESTARTED=false
for version in 8.3 8.2 8.1 8.0; do
    if systemctl list-unit-files | grep -q "php$version-fpm.service"; then
        echo "🔄 Перезапуск php$version-fpm..."
        systemctl restart php$version-fpm
        PHP_FPM_RESTARTED=true
        break
    fi
done

if [ "$PHP_FPM_RESTARTED" = false ]; then
    echo "⚠️ PHP-FPM сервис не найден. Возможно, веб-сервер еще не установлен."
fi

echo "14. Проверка интеграции PHP и Redis..."

# Проверяем, настроен ли пароль для Redis
echo "Проверка конфигурации Redis..."
if [ ! -z "$REDIS_PASSWORD" ] && [ "$REDIS_PASSWORD" != "" ]; then
    echo "Redis настроен с аутентификацией"
    REDIS_AUTH_NEEDED=true
    # Проверяем подключение с паролем
    if redis-cli -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
        echo "✅ Redis аутентификация работает"
    else
        echo "❌ Проблема с Redis аутентификацией"
        exit 1
    fi
else
    echo "Redis работает без аутентификации"
    REDIS_AUTH_NEEDED=false
fi

# Тестирование PHP интеграции
if [ "$REDIS_AUTH_NEEDED" = "true" ]; then
    echo "Тестирование с аутентификацией..."
    php -r "
try {
    \$redis = new Redis();
    if (!\$redis->connect('127.0.0.1', 6379)) {
        throw new Exception('Не удалось подключиться к Redis');
    }
    if (!\$redis->auth('$REDIS_PASSWORD')) {
        throw new Exception('Ошибка аутентификации Redis');
    }
    \$redis->set('test_key', 'test_value');
    \$value = \$redis->get('test_key');
    if (\$value === 'test_value') {
        echo 'PHP Redis integration: OK\n';
        \$redis->del('test_key');
    } else {
        throw new Exception('Ошибка записи/чтения Redis');
    }
    \$redis->close();
} catch (Exception \$e) {
    echo 'PHP Redis integration: FAILED - ' . \$e->getMessage() . '\n';
    exit(1);
}
"
else
    echo "Тестирование без аутентификации..."
    php -r "
try {
    \$redis = new Redis();
    if (!\$redis->connect('127.0.0.1', 6379)) {
        throw new Exception('Не удалось подключиться к Redis');
    }
    \$redis->set('test_key', 'test_value');
    \$value = \$redis->get('test_key');
    if (\$value === 'test_value') {
        echo 'PHP Redis integration: OK\n';
        \$redis->del('test_key');
    } else {
        throw new Exception('Ошибка записи/чтения Redis');
    }
    \$redis->close();
} catch (Exception \$e) {
    echo 'PHP Redis integration: FAILED - ' . \$e->getMessage() . '\n';
    exit(1);
}
"
fi

if [ $? -eq 0 ]; then
    echo "✅ PHP и Redis интегрированы успешно"
else
    echo "❌ Ошибка интеграции PHP и Redis"
    exit 1
fi

echo "15. Создание файла оптимизации Redis для Moodle..."
cat > /root/redis-moodle-optimization.txt << EOF
# Redis оптимизация для Moodle
# Рекомендуемые настройки для config.php

// Session хранение в Redis
\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '127.0.0.1';
\$CFG->session_redis_port = 6379;
\$CFG->session_redis_auth = '$REDIS_PASSWORD';
\$CFG->session_redis_database = 0;
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;

// Кэширование приложения в Redis
\$CFG->cache_stores = array(
    'redis_cache' => array(
        'plugin' => 'redis',
        'configuration' => array(
            'server' => '127.0.0.1:6379',
            'password' => '$REDIS_PASSWORD',
            'prefix' => 'mdl_',
            'serializer' => Redis::SERIALIZER_PHP,
            'compressor' => Redis::COMPRESSION_NONE,
        ),
        'features' => Redis::SERIALIZER_PHP,
    ),
);

// Настройки производительности
\$CFG->session_redis_acquire_lock_warn = 10;
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;
EOF

echo
echo "✅ Шаг 4 завершен успешно!"
echo "📌 Redis установлен и настроен"
echo "📌 PHP расширение Redis активировано"
echo "📌 Данные подключения: /root/moodle-redis-credentials.txt"
echo "📌 Скрипт мониторинга: /root/redis-monitor.sh"
echo "📌 Настройки для Moodle: /root/redis-moodle-optimization.txt"
echo "📌 Следующий шаг: ./05-configure-ssl.sh"
echo
