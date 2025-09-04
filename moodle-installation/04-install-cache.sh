#!/bin/bash

# RTTI Moodle - Шаг 4: Установка системы кэширования
# Сервер: lms.rtti.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 4: Установка Redis для кэширования ==="
echo "🚀 Redis для ускорения Moodle"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Установка Redis сервера..."
apt install -y redis-server php-redis

echo "2. Настройка Redis для продакшен..."
REDIS_CONF="/etc/redis/redis.conf"
cp $REDIS_CONF ${REDIS_CONF}.backup

echo "3. Конфигурация Redis..."
# Привязка к localhost
sed -i 's/^bind 127.0.0.1/bind 127.0.0.1/' $REDIS_CONF

# Защищенный режим
sed -i 's/^protected-mode yes/protected-mode yes/' $REDIS_CONF

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

# Добавление пароля в конфиг
echo "requirepass $REDIS_PASSWORD" >> $REDIS_CONF

echo "5. Включение и запуск Redis..."
systemctl enable redis-server
systemctl start redis-server

echo "6. Ожидание запуска Redis..."
sleep 3

echo "7. Проверка статуса Redis..."
systemctl status redis-server --no-pager -l

echo "8. Тестирование Redis..."
redis-cli -a $REDIS_PASSWORD ping
if [ $? -eq 0 ]; then
    echo "✅ Redis работает корректно"
else
    echo "❌ Ошибка подключения к Redis"
    exit 1
fi

echo "9. Проверка PHP расширения Redis..."
php -m | grep redis
if [ $? -eq 0 ]; then
    echo "✅ PHP расширение Redis установлено"
else
    echo "❌ PHP расширение Redis не найдено"
    exit 1
fi

echo "10. Настройка PHP для работы с Redis..."
PHP_INI="/etc/php/8.2/fpm/php.ini"

# Увеличиваем лимиты для сессий
sed -i 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 3600/' $PHP_INI

echo "11. Сохранение данных подключения к Redis..."
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

chmod 600 /root/moodle-redis-credentials.txt

echo "12. Создание скрипта мониторинга Redis..."
cat > /root/redis-monitor.sh << 'EOF'
#!/bin/bash
echo "=== Redis Status ==="
systemctl status redis-server --no-pager
echo
echo "=== Redis Info ==="
redis-cli -a $(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print $2}') info memory
echo
echo "=== Redis Connected Clients ==="
redis-cli -a $(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print $2}') info clients
EOF

chmod +x /root/redis-monitor.sh

echo "13. Перезапуск PHP-FPM для применения настроек..."
systemctl restart php8.2-fpm

echo "14. Проверка интеграции PHP и Redis..."
php -r "
\$redis = new Redis();
\$redis->connect('127.0.0.1', 6379);
\$redis->auth('$REDIS_PASSWORD');
\$redis->set('test_key', 'test_value');
\$value = \$redis->get('test_key');
if (\$value === 'test_value') {
    echo 'PHP Redis integration: OK\n';
} else {
    echo 'PHP Redis integration: FAILED\n';
    exit(1);
}
\$redis->del('test_key');
\$redis->close();
"

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
