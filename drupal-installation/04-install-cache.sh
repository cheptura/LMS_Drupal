#!/bin/bash

# RTTI Drupal - Шаг 4: Установка системы кэширования
# Сервер: storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 4: Установка Redis для кэширования Drupal 11 ==="
echo "🚀 Redis + Memcached для ускорения цифровой библиотеки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Установка Redis сервера..."
apt install -y redis-server

echo "2. Установка Memcached (дополнительное кэширование)..."
apt install -y memcached

echo "3. Проверка установки PHP расширений для кэширования..."
# Расширения уже должны быть установлены в шаге 2, но проверим
php -m | grep -E "(redis|memcached|apcu)"

echo "4. Настройка Redis для Drupal..."
REDIS_CONF="/etc/redis/redis.conf"
cp $REDIS_CONF ${REDIS_CONF}.backup

# Генерация пароля для Redis
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Настройка Redis
cat > /etc/redis/redis.conf << EOF
# Redis configuration for Drupal 11
# Generated: $(date)

# Network
bind 127.0.0.1
port 6379
protected-mode yes

# Security
requirepass $REDIS_PASSWORD

# Memory management
maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000

stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename drupal-redis.rdb
dir /var/lib/redis

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Performance
tcp-keepalive 300
timeout 0
tcp-backlog 511

# Clients
maxclients 10000

# Append only file
appendonly yes
appendfilename "drupal-redis.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Lua scripting
lua-time-limit 5000

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Latency monitor
latency-monitor-threshold 100
EOF

echo "5. Настройка Memcached для Drupal..."
cat > /etc/memcached.conf << 'EOF'
# Memcached configuration for Drupal

# Memory
-m 256

# Network
-l 127.0.0.1
-p 11211

# User
-u memcache

# Connections
-c 1024

# Growth factor
-f 1.25

# Minimum space allocated for key+value+flags
-n 48

# Use large memory pages
-L

# Protocol
-B binary

# Logging
-v
EOF

echo "6. Создание каталогов для логов Redis..."
mkdir -p /var/log/redis
chown redis:redis /var/log/redis
chmod 755 /var/log/redis

echo "7. Настройка PHP для работы с кэшированием..."
cat > /etc/php/8.3/fpm/conf.d/20-drupal-cache.ini << EOF
; Drupal caching configuration

; Redis settings
redis.session.locking_enabled = 1
redis.session.lock_expire = 300
redis.session.lock_wait_time = 50000

; APCu settings for Drupal
apc.enable_cli = 1
apc.shm_size = 256M
apc.ttl = 3600
apc.user_ttl = 3600
apc.gc_ttl = 3600
apc.entries_hint = 4096
apc.slam_defense = 1

; Session settings
session.save_handler = redis
session.save_path = "tcp://127.0.0.1:6379?auth=$REDIS_PASSWORD"
session.gc_maxlifetime = 3600
EOF

# Копирование для CLI
cp /etc/php/8.3/fpm/conf.d/20-drupal-cache.ini /etc/php/8.3/cli/conf.d/20-drupal-cache.ini

echo "8. Включение и запуск сервисов кэширования..."
systemctl enable redis-server
systemctl start redis-server
systemctl enable memcached
systemctl start memcached

echo "9. Ожидание запуска сервисов..."
sleep 3

echo "10. Проверка статуса Redis..."
systemctl status redis-server --no-pager -l | head -5

echo "11. Проверка статуса Memcached..."
systemctl status memcached --no-pager -l | head -5

echo "12. Тестирование Redis..."
redis-cli -a $REDIS_PASSWORD ping
if [ $? -eq 0 ]; then
    echo "✅ Redis работает корректно"
else
    echo "❌ Ошибка подключения к Redis"
    exit 1
fi

echo "13. Тестирование Memcached..."
echo "stats" | nc localhost 11211 | head -1
if [ $? -eq 0 ]; then
    echo "✅ Memcached работает корректно"
else
    echo "❌ Ошибка подключения к Memcached"
    exit 1
fi

echo "14. Проверка PHP интеграции с кэшированием..."
php -r "
// Тест Redis
try {
    \$redis = new Redis();
    \$redis->connect('127.0.0.1', 6379);
    \$redis->auth('$REDIS_PASSWORD');
    \$redis->set('drupal_test', 'success');
    \$value = \$redis->get('drupal_test');
    if (\$value === 'success') {
        echo 'PHP Redis integration: OK\n';
    } else {
        echo 'PHP Redis integration: FAILED\n';
        exit(1);
    }
    \$redis->del('drupal_test');
    \$redis->close();
} catch (Exception \$e) {
    echo 'PHP Redis error: ' . \$e->getMessage() . '\n';
    exit(1);
}

// Тест Memcached
try {
    \$memcached = new Memcached();
    \$memcached->addServer('127.0.0.1', 11211);
    \$memcached->set('drupal_test', 'success', 3600);
    \$value = \$memcached->get('drupal_test');
    if (\$value === 'success') {
        echo 'PHP Memcached integration: OK\n';
    } else {
        echo 'PHP Memcached integration: FAILED\n';
        exit(1);
    }
    \$memcached->delete('drupal_test');
} catch (Exception \$e) {
    echo 'PHP Memcached error: ' . \$e->getMessage() . '\n';
    exit(1);
}

// Тест APCu
if (function_exists('apcu_store')) {
    apcu_store('drupal_test', 'success', 300);
    \$value = apcu_fetch('drupal_test');
    if (\$value === 'success') {
        echo 'PHP APCu integration: OK\n';
    } else {
        echo 'PHP APCu integration: FAILED\n';
    }
    apcu_delete('drupal_test');
} else {
    echo 'APCu not available\n';
}
"

if [ $? -eq 0 ]; then
    echo "✅ PHP интеграция с кэшированием работает"
else
    echo "❌ Ошибка интеграции PHP с кэшированием"
    exit 1
fi

echo "15. Создание скрипта мониторинга кэширования..."
cat > /root/drupal-cache-monitor.sh << EOF
#!/bin/bash
echo "=== Drupal Cache Monitor ==="
echo "Время: \$(date)"
echo

echo "1. Статус сервисов:"
echo -n "Redis: "; systemctl is-active redis-server
echo -n "Memcached: "; systemctl is-active memcached

echo -e "\n2. Redis статистика:"
redis-cli -a $REDIS_PASSWORD info memory | grep -E "(used_memory_human|maxmemory_human)"
echo "Ключи в Redis: \$(redis-cli -a $REDIS_PASSWORD dbsize)"

echo -e "\n3. Memcached статистика:"
echo "stats" | nc localhost 11211 | grep -E "(bytes|curr_items|get_hits|get_misses)"

echo -e "\n4. APCu статистика:"
php -r "
if (function_exists('apcu_cache_info')) {
    \\\$info = apcu_cache_info();
    echo 'APCu memory: ' . round(\\\$info['memory_type'] ?? 0) . ' MB\n';
    echo 'APCu entries: ' . (\\\$info['num_entries'] ?? 0) . '\n';
} else {
    echo 'APCu not available\n';
}
"

echo -e "\n5. Процессы:"
ps aux | grep -E "(redis|memcached)" | grep -v grep

echo -e "\n6. Сетевые подключения:"
ss -tuln | grep -E "(6379|11211)"

echo -e "\n7. Использование памяти кэшами:"
ps aux | grep -E "(redis|memcached)" | awk '{sum+=\$6} END {print "Cache processes: " sum/1024 " MB"}'
EOF

chmod +x /root/drupal-cache-monitor.sh

echo "16. Создание скрипта очистки кэша..."
cat > /root/drupal-cache-clear.sh << EOF
#!/bin/bash
echo "=== Drupal Cache Clear ==="
echo "Время: \$(date)"

echo "1. Очистка Redis..."
redis-cli -a $REDIS_PASSWORD FLUSHALL
echo "✅ Redis очищен"

echo "2. Очистка APCu..."
php -r "
if (function_exists('apcu_clear_cache')) {
    apcu_clear_cache();
    echo 'APCu cache cleared\n';
} else {
    echo 'APCu not available\n';
}
"

echo "3. Перезапуск Memcached..."
systemctl restart memcached
echo "✅ Memcached перезапущен"

echo "4. Перезапуск PHP-FPM..."
systemctl restart php8.3-fpm
echo "✅ PHP-FPM перезапущен"

echo "Все кэши очищены!"
EOF

chmod +x /root/drupal-cache-clear.sh

echo "17. Сохранение данных подключения к кэшам..."
cat > /root/drupal-cache-credentials.txt << EOF
# Данные подключения к системам кэширования Drupal
# Дата создания: $(date)
# Сервер: storage.omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== REDIS ===
Хост: 127.0.0.1
Порт: 6379
Пароль: $REDIS_PASSWORD
База данных: 0

Команда подключения:
redis-cli -a '$REDIS_PASSWORD'

Тест:
redis-cli -a '$REDIS_PASSWORD' ping

=== MEMCACHED ===
Хост: 127.0.0.1
Порт: 11211
Без аутентификации

Тест:
echo "stats" | nc localhost 11211

=== APCU ===
Локальный кэш PHP
Размер: 256MB
Включен для CLI и FPM

=== НАСТРОЙКИ ДЛЯ DRUPAL ===

# В settings.php добавить:

# Redis для кэширования
\$settings['redis.connection']['interface'] = 'PhpRedis';
\$settings['redis.connection']['host'] = '127.0.0.1';
\$settings['redis.connection']['port'] = 6379;
\$settings['redis.connection']['password'] = '$REDIS_PASSWORD';
\$settings['redis.connection']['base'] = 0;

\$settings['cache']['default'] = 'cache.backend.redis';
\$settings['cache']['bins']['bootstrap'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['discovery'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['config'] = 'cache.backend.chainedfast';

# APCu для локального кэширования
\$settings['cache']['bins']['bootstrap'] = 'cache.backend.apcu';
\$settings['cache']['bins']['discovery'] = 'cache.backend.apcu';
\$settings['cache']['bins']['config'] = 'cache.backend.apcu';

# Memcached (опционально)
# \$settings['memcache']['servers'] = ['127.0.0.1:11211' => 'default'];
# \$settings['memcache']['bins'] = ['cache.page' => 'default'];
EOF

chmod 600 /root/drupal-cache-credentials.txt

echo "18. Перезапуск PHP-FPM для применения настроек..."
systemctl restart php8.3-fpm

echo "19. Создание информационного файла..."
cat > /root/drupal-cache-info.txt << EOF
# Информация о системе кэширования Drupal
# Дата: $(date)
# Сервер: storage.omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===
✅ Redis $(redis-server --version | awk '{print $3}')
✅ Memcached $(memcached -h | head -1 | awk '{print $2}' 2>/dev/null || echo "установлен")
✅ APCu (PHP расширение)

=== КОНФИГУРАЦИЯ ===
Redis config: /etc/redis/redis.conf
Memcached config: /etc/memcached.conf
PHP config: /etc/php/8.3/fpm/conf.d/20-drupal-cache.ini

=== ПАРАМЕТРЫ ПРОИЗВОДИТЕЛЬНОСТИ ===
Redis память: 512MB
Memcached память: 256MB
APCu память: 256MB

=== ПОРТЫ ===
Redis: 6379
Memcached: 11211

=== СКРИПТЫ УПРАВЛЕНИЯ ===
Мониторинг: /root/drupal-cache-monitor.sh
Очистка кэша: /root/drupal-cache-clear.sh
Данные подключения: /root/drupal-cache-credentials.txt

=== КОМАНДЫ ===
Redis CLI: redis-cli -a 'пароль'
Memcached тест: echo "stats" | nc localhost 11211
Очистка Redis: redis-cli -a 'пароль' FLUSHALL
Перезапуск всех кэшей: /root/drupal-cache-clear.sh

=== ИНТЕГРАЦИЯ С DRUPAL ===
Для активации кэширования в Drupal:
1. Установите модуль Redis: composer require drupal/redis
2. Добавьте настройки в sites/default/settings.php
3. Очистите кэш Drupal: drush cache:rebuild

=== МОНИТОРИНГ ПРОИЗВОДИТЕЛЬНОСТИ ===
- Redis: Мониторинг через redis-cli info
- Memcached: Статистика через команду stats
- APCu: Мониторинг через PHP функции
- Общий мониторинг: /root/drupal-cache-monitor.sh

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Запустите: ./05-configure-ssl.sh
2. Проверьте кэши: /root/drupal-cache-monitor.sh
3. Настройте кэширование в Drupal после установки
EOF

echo
echo "✅ Шаг 4 завершен успешно!"
echo "📌 Redis установлен и настроен (порт 6379)"
echo "📌 Memcached установлен и настроен (порт 11211)"
echo "📌 APCu активирован для PHP"
echo "📌 PHP интеграция с кэшами работает"
echo "📌 Данные подключения: /root/drupal-cache-credentials.txt"
echo "📌 Мониторинг: /root/drupal-cache-monitor.sh"
echo "📌 Очистка кэшей: /root/drupal-cache-clear.sh"
echo "📌 Информация: /root/drupal-cache-info.txt"
echo "📌 Следующий шаг: ./05-configure-ssl.sh"
echo
