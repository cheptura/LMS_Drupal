#!/bin/bash

# Скрипт восстановления SSL сертификатов из репозитория
# Автор: RTTI Development Team
# Дата: $(date)

DOMAIN="storage.omuzgorpro.tj"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/$DOMAIN"
LETSENCRYPT_DIR="/etc/letsencrypt/live/$DOMAIN"
LETSENCRYPT_ARCHIVE="/etc/letsencrypt/archive/$DOMAIN"

echo "=== Восстановление SSL сертификатов из репозитория ==="
echo "📅 Дата: $(date)"
echo "🌐 Домен: $DOMAIN"
echo "📁 Источник: $CERT_DIR"
echo "💾 Назначение: $LETSENCRYPT_DIR"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo $0"
    exit 1
fi

# Проверка существования сертификатов в репозитории
if [ ! -d "$CERT_DIR" ]; then
    echo "❌ Ошибка: Сертификаты в репозитории не найдены"
    echo "   Директория не существует: $CERT_DIR"
    echo "   Сначала создайте резервную копию: sudo ./backup-ssl.sh"
    exit 1
fi

# Проверка наличия всех необходимых файлов
REQUIRED_FILES=("cert.pem" "fullchain.pem" "privkey.pem")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$CERT_DIR/$file" ]; then
        echo "❌ Ошибка: Файл $file не найден в $CERT_DIR"
        exit 1
    fi
done

echo "1. Проверка целостности сертификатов в репозитории..."

# Проверка валидности сертификата
if ! openssl x509 -in "$CERT_DIR/cert.pem" -noout -text >/dev/null 2>&1; then
    echo "❌ Ошибка: cert.pem поврежден или невалиден"
    exit 1
fi

# Проверка валидности ключа
if ! openssl rsa -in "$CERT_DIR/privkey.pem" -check -noout >/dev/null 2>&1; then
    echo "❌ Ошибка: privkey.pem поврежден или невалиден"
    exit 1
fi

# Проверка соответствия ключа и сертификата
CERT_MODULUS=$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -modulus | openssl md5)
KEY_MODULUS=$(openssl rsa -in "$CERT_DIR/privkey.pem" -noout -modulus | openssl md5)

if [ "$CERT_MODULUS" != "$KEY_MODULUS" ]; then
    echo "❌ Ошибка: Сертификат и ключ не соответствуют друг другу"
    exit 1
fi

echo "   ✅ Все файлы валидны и соответствуют друг другу"

# Проверка срока действия
CERT_END_DATE=$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -enddate | cut -d= -f2)
CERT_END_TIMESTAMP=$(date -d "$CERT_END_DATE" +%s)
CURRENT_TIMESTAMP=$(date +%s)
DAYS_LEFT=$(( (CERT_END_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

echo "📅 Срок действия сертификата:"
echo "   Действителен до: $CERT_END_DATE"
echo "   Осталось дней: $DAYS_LEFT"

if [ $DAYS_LEFT -lt 30 ]; then
    echo "⚠️  ВНИМАНИЕ: Сертификат истекает менее чем через 30 дней!"
    echo "   Рекомендуется обновить сертификат"
fi

if [ $DAYS_LEFT -lt 0 ]; then
    echo "❌ ОШИБКА: Сертификат уже истек!"
    echo "   Используйте этот сертификат только для тестирования"
    read -p "Продолжить установку истекшего сертификата? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "2. Создание директорий Let's Encrypt..."

# Создание необходимых директорий
mkdir -p /etc/letsencrypt/live
mkdir -p /etc/letsencrypt/archive
mkdir -p "$LETSENCRYPT_ARCHIVE"

echo "3. Создание резервной копии существующих сертификатов..."

# Если уже есть сертификаты, создаем резервную копию
if [ -d "$LETSENCRYPT_DIR" ]; then
    BACKUP_DIR="/etc/letsencrypt/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$LETSENCRYPT_DIR" "$BACKUP_DIR/"
    echo "   ✅ Создана резервная копия: $BACKUP_DIR"
fi

echo "4. Установка сертификатов..."

# Создание директории live
mkdir -p "$LETSENCRYPT_DIR"

# Копирование файлов в archive (реальные файлы)
cp "$CERT_DIR/cert.pem" "$LETSENCRYPT_ARCHIVE/cert1.pem"
cp "$CERT_DIR/chain.pem" "$LETSENCRYPT_ARCHIVE/chain1.pem" 2>/dev/null || echo "   ⚠️ chain.pem не найден, пропускаем"
cp "$CERT_DIR/fullchain.pem" "$LETSENCRYPT_ARCHIVE/fullchain1.pem"
cp "$CERT_DIR/privkey.pem" "$LETSENCRYPT_ARCHIVE/privkey1.pem"

# Создание символических ссылок в live
ln -sf "../../archive/$DOMAIN/cert1.pem" "$LETSENCRYPT_DIR/cert.pem"
ln -sf "../../archive/$DOMAIN/chain1.pem" "$LETSENCRYPT_DIR/chain.pem"
ln -sf "../../archive/$DOMAIN/fullchain1.pem" "$LETSENCRYPT_DIR/fullchain.pem"
ln -sf "../../archive/$DOMAIN/privkey1.pem" "$LETSENCRYPT_DIR/privkey.pem"

echo "5. Установка правильных прав доступа..."

# Установка правильных прав доступа
chown -R root:root /etc/letsencrypt
chmod 755 /etc/letsencrypt
chmod 755 /etc/letsencrypt/live
chmod 755 /etc/letsencrypt/archive
chmod 755 "$LETSENCRYPT_DIR"
chmod 755 "$LETSENCRYPT_ARCHIVE"
chmod 644 "$LETSENCRYPT_ARCHIVE"/*.pem
chmod 600 "$LETSENCRYPT_ARCHIVE/privkey1.pem"

echo "6. Обновление конфигурации Nginx..."

# Проверка и обновление конфигурации Nginx
NGINX_CONFIG="/etc/nginx/sites-available/drupal-ssl"

if [ ! -f "$NGINX_CONFIG" ]; then
    echo "   📝 Создание SSL конфигурации Nginx..."
    
    cat > "$NGINX_CONFIG" << EOF
# SSL конфигурация для $DOMAIN
# Автоматически создано скриптом восстановления SSL
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    root /var/www/drupal/web;
    index index.php index.html;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Include Drupal configuration
    include /etc/nginx/sites-available/drupal-default-ssl-content;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
EOF

    # Активация SSL конфигурации
    ln -sf /etc/nginx/sites-available/drupal-ssl /etc/nginx/sites-enabled/
    echo "   ✅ SSL конфигурация Nginx создана и активирована"
else
    echo "   ✅ SSL конфигурация Nginx уже существует"
fi

echo "7. Проверка конфигурации..."

# Тест конфигурации Nginx
if nginx -t >/dev/null 2>&1; then
    echo "   ✅ Конфигурация Nginx корректна"
else
    echo "   ❌ Ошибка в конфигурации Nginx:"
    nginx -t
    exit 1
fi

echo "8. Перезапуск Nginx..."

if systemctl reload nginx >/dev/null 2>&1; then
    echo "   ✅ Nginx перезапущен успешно"
else
    echo "   ❌ Ошибка перезапуска Nginx"
    systemctl status nginx --no-pager -l
    exit 1
fi

echo "9. Проверка SSL соединения..."

# Небольшая пауза для запуска Nginx
sleep 2

# Проверка SSL
if curl -s -I "https://$DOMAIN" >/dev/null 2>&1; then
    echo "   ✅ SSL соединение работает"
else
    echo "   ⚠️  SSL соединение может не работать (проверьте DNS и firewall)"
fi

echo
echo "✅ Восстановление SSL сертификатов завершено успешно!"
echo
echo "📋 Информация о установленном сертификате:"
openssl x509 -in "$LETSENCRYPT_DIR/cert.pem" -noout -subject -dates
echo
echo "🌐 Проверьте сайт: https://$DOMAIN"
echo "🔍 Онлайн проверка SSL: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo
echo "📁 Файлы сертификатов:"
echo "   Сертификат: $LETSENCRYPT_DIR/cert.pem"
echo "   Полная цепочка: $LETSENCRYPT_DIR/fullchain.pem"
echo "   Приватный ключ: $LETSENCRYPT_DIR/privkey.pem"
