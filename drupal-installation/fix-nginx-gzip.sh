#!/bin/bash

# RTTI Drupal - Исправление проблемы с дублирующимися директивами gzip в Nginx
# Дата: $(date)

echo "=== Исправление проблемы с дублирующимися директивами gzip в Nginx ==="
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./fix-nginx-gzip.sh"
    exit 1
fi

echo "🔍 Проверяем конфигурацию Nginx..."

# Проверяем текущее состояние конфигурации
if nginx -t 2>&1 | grep -q "gzip.*duplicate"; then
    echo "❌ Найдена проблема с дублирующимися директивами gzip"
    
    # Показываем детали проблемы
    echo "📋 Детали ошибки:"
    nginx -t 2>&1 | grep -A2 -B2 "gzip.*duplicate"
    echo
    
    # Файл с проблемой
    PERFORMANCE_CONF="/etc/nginx/conf.d/drupal-performance.conf"
    
    if [ -f "$PERFORMANCE_CONF" ]; then
        echo "🔧 Исправляем файл: $PERFORMANCE_CONF"
        
        # Создаем резервную копию
        cp "$PERFORMANCE_CONF" "$PERFORMANCE_CONF.backup.$(date +%Y%m%d-%H%M%S)"
        echo "✅ Создана резервная копия: $PERFORMANCE_CONF.backup.$(date +%Y%m%d-%H%M%S)"
        
        # Создаем исправленный файл конфигурации
        cat > "$PERFORMANCE_CONF" << 'EOF'
# Drupal Performance Configuration
# Optimized for RTTI Drupal Library

# Client body size
client_max_body_size 100M;

# Timeouts
client_body_timeout 60s;
client_header_timeout 60s;
keepalive_timeout 65s;
send_timeout 60s;

# Buffers
client_body_buffer_size 128k;
client_header_buffer_size 4k;
large_client_header_buffers 4 8k;
output_buffers 2 32k;

# FastCGI cache settings
fastcgi_cache_path /var/cache/nginx/drupal levels=1:2 keys_zone=drupal:10m max_size=1g inactive=60m use_temp_path=off;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_use_stale error timeout invalid_header updating http_500 http_503;
fastcgi_cache_valid 200 301 302 1h;
fastcgi_cache_valid 404 1m;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

# File caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
}

# Drupal specific locations
location ~ ^/sites/.*/files/styles/ {
    try_files $uri $uri/ @rewrite;
}

location ~ ^(/[a-z\-]+)?/system/files/ {
    try_files $uri $uri/ /index.php?$query_string;
}

# Защита системных файлов
location ~ ^/sites/.*/private/ {
    return 403;
}

location ~ ^/sites/[^/]+/files/.*\.php$ {
    deny all;
}

location ~* ^/.well-known/ {
    allow all;
}

location ~ (^|/)\. {
    return 403;
}

location ~ /vendor/ {
    return 403;
}

location ~ /core/install.php {
    return 403;
}
EOF

        echo "✅ Файл $PERFORMANCE_CONF исправлен"
        
    else
        echo "⚠️  Файл $PERFORMANCE_CONF не найден"
    fi
    
    # Также проверим основной файл nginx.conf
    NGINX_CONF="/etc/nginx/nginx.conf"
    if [ -f "$NGINX_CONF" ]; then
        echo "🔍 Проверяем основной файл конфигурации: $NGINX_CONF"
        
        # Проверяем, есть ли gzip в основном файле
        if grep -q "gzip on" "$NGINX_CONF"; then
            echo "✅ gzip уже включен в основном файле конфигурации"
        else
            echo "⚠️  gzip не найден в основном файле конфигурации"
        fi
    fi
    
    echo
    echo "🧪 Тестируем исправленную конфигурацию..."
    
    if nginx -t; then
        echo "✅ Конфигурация Nginx исправлена успешно!"
        
        echo "🔄 Перезапускаем Nginx..."
        if systemctl restart nginx; then
            echo "✅ Nginx перезапущен успешно"
            
            # Проверяем статус
            if systemctl is-active --quiet nginx; then
                echo "✅ Nginx работает"
                
                # Проверяем порты
                echo "🔍 Проверяем открытые порты..."
                netstat -tlnp | grep ':80\|:443' || echo "⚠️  Порты 80/443 не прослушиваются"
                
            else
                echo "❌ Nginx не запустился"
                systemctl status nginx --no-pager
            fi
        else
            echo "❌ Ошибка перезапуска Nginx"
            systemctl status nginx --no-pager
        fi
        
    else
        echo "❌ В конфигурации все еще есть ошибки"
        nginx -t
    fi
    
else
    echo "✅ Проблем с дублирующимися директивами gzip не найдено"
    
    # Все равно проверим общее состояние
    if nginx -t; then
        echo "✅ Конфигурация Nginx корректна"
        
        if systemctl is-active --quiet nginx; then
            echo "✅ Nginx работает"
        else
            echo "⚠️  Nginx не активен, попробуем запустить..."
            systemctl start nginx
            
            if systemctl is-active --quiet nginx; then
                echo "✅ Nginx запущен успешно"
            else
                echo "❌ Не удалось запустить Nginx"
                systemctl status nginx --no-pager
            fi
        fi
    else
        echo "❌ В конфигурации Nginx есть другие ошибки:"
        nginx -t
    fi
fi

echo
echo "=== Финальная проверка ==="

# Проверяем статус всех сервисов
echo "📊 Статус сервисов:"
for service in nginx php8.3-fpm postgresql redis; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: активен"
    else
        echo "❌ $service: не активен"
    fi
done

echo
echo "📊 Открытые порты:"
netstat -tlnp | grep ':80\|:443\|:22\|:5432\|:6379' | while read line; do
    port=$(echo $line | awk '{print $4}' | cut -d: -f2)
    case $port in
        80) echo "✅ HTTP (80): открыт" ;;
        443) echo "✅ HTTPS (443): открыт" ;;
        22) echo "✅ SSH (22): открыт" ;;
        5432) echo "✅ PostgreSQL (5432): открыт" ;;
        6379) echo "✅ Redis (6379): открыт" ;;
    esac
done

echo
echo "🎯 Рекомендации:"
echo "1. Проверьте файрвол: sudo ufw status"
echo "2. Если порты 80/443 закрыты, откройте их: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
echo "3. Проверьте Drupal сайт: curl -I http://localhost"
echo
echo "✅ Скрипт исправления завершен"
