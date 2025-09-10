#!/bin/bash

# RTTI Drupal - Быстрое исправление проблем
# Выполните эти команды в WSL под root

echo "=== Быстрое исправление проблем RTTI Drupal ==="

# 1. Исправить конфликт gzip в Nginx
echo "1. Исправляем конфликт gzip..."
cat > /etc/nginx/conf.d/drupal-performance.conf << 'EOF'
# Fixed Drupal Performance Config - no gzip conflicts
client_max_body_size 100M;
client_body_timeout 60s;
client_header_timeout 60s;
keepalive_timeout 65s;
send_timeout 60s;
client_body_buffer_size 128k;
client_header_buffer_size 4k;
large_client_header_buffers 4 8k;
output_buffers 2 32k;
EOF

# 2. Установить OPcache если отсутствует
echo "2. Устанавливаем OPcache..."
apt update -qq && apt install -y php8.3-opcache

# 3. Настроить OPcache
echo "3. Настраиваем OPcache..."
cat > /etc/php/8.3/fpm/conf.d/10-opcache.ini << 'EOF'
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
opcache.save_comments=1
opcache.fast_shutdown=1
EOF

# 4. Создать необходимые директории
echo "4. Создаем директории..."
mkdir -p /var/cache/nginx/drupal
chown -R www-data:www-data /var/cache/nginx/drupal

# 5. Настроить файрвол
echo "5. Настраиваем файрвол..."
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true

# 6. Перезапустить сервисы
echo "6. Перезапускаем сервисы..."
systemctl restart php8.3-fpm
systemctl restart nginx

# 7. Проверить результат
echo "7. Проверяем результат..."
echo "Nginx config test:"
nginx -t

echo "Services status:"
systemctl is-active nginx php8.3-fpm postgresql redis

echo "Open ports:"
netstat -tlnp | grep ':80\|:443'

echo "OPcache:"
php -m | grep -i opcache

echo "=== Готово! ==="
