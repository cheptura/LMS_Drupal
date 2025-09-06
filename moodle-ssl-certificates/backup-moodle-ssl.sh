#!/bin/bash

# Скрипт резервного копирования SSL сертификатов для Moodle
# Автор: RTTI Development Team
# Дата: $(date)

DOMAIN="omuzgorpro.tj"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/$DOMAIN"
LETSENCRYPT_DIR="/etc/letsencrypt/live/$DOMAIN"

echo "=== Резервное копирование SSL сертификатов Moodle ==="
echo "📅 Дата: $(date)"
echo "🌐 Домен: $DOMAIN"
echo "📁 Источник: $LETSENCRYPT_DIR"
echo "💾 Назначение: $CERT_DIR"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo $0"
    exit 1
fi

# Проверка существования сертификатов Let's Encrypt
if [ ! -d "$LETSENCRYPT_DIR" ]; then
    echo "❌ Ошибка: Сертификаты Let's Encrypt не найдены"
    echo "   Директория не существует: $LETSENCRYPT_DIR"
    echo "   Сначала выпустите сертификаты командой: sudo ./05-configure-ssl.sh"
    exit 1
fi

# Создание директории для сертификатов
mkdir -p "$CERT_DIR"

echo "1. Копирование файлов сертификатов..."

# Копирование основных файлов сертификатов
if cp "$LETSENCRYPT_DIR/cert.pem" "$CERT_DIR/" 2>/dev/null; then
    echo "   ✅ cert.pem скопирован"
else
    echo "   ❌ Ошибка копирования cert.pem"
    exit 1
fi

if cp "$LETSENCRYPT_DIR/chain.pem" "$CERT_DIR/" 2>/dev/null; then
    echo "   ✅ chain.pem скопирован"
else
    echo "   ⚠️  chain.pem не найден, пропускаем"
fi

if cp "$LETSENCRYPT_DIR/fullchain.pem" "$CERT_DIR/" 2>/dev/null; then
    echo "   ✅ fullchain.pem скопирован"
else
    echo "   ❌ Ошибка копирования fullchain.pem"
    exit 1
fi

if cp "$LETSENCRYPT_DIR/privkey.pem" "$CERT_DIR/" 2>/dev/null; then
    echo "   ✅ privkey.pem скопирован"
else
    echo "   ❌ Ошибка копирования privkey.pem"
    exit 1
fi

echo "2. Создание информационного файла..."

# Создание файла с информацией о сертификате
cat > "$CERT_DIR/cert-info.txt" << EOF
# Информация о SSL сертификате Moodle
# Домен: $DOMAIN
# Дата резервного копирования: $(date)
# Источник: $LETSENCRYPT_DIR

=== ИНФОРМАЦИЯ О СЕРТИФИКАТЕ ===
$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -text | head -20)

=== СРОК ДЕЙСТВИЯ ===
$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -dates)

=== FINGERPRINT ===
SHA1: $(openssl x509 -in "$CERT_DIR/cert.pem" -noout -fingerprint -sha1)
SHA256: $(openssl x509 -in "$CERT_DIR/cert.pem" -noout -fingerprint -sha256)

=== РАЗМЕР КЛЮЧА ===
$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -text | grep "Public-Key:")

=== АЛЬТЕРНАТИВНЫЕ ИМЕНА ===
$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -text | grep -A 1 "Subject Alternative Name:")

=== ФАЙЛЫ ===
cert.pem     - Основной сертификат
chain.pem    - Промежуточные сертификаты
fullchain.pem - Полная цепочка (cert + chain)
privkey.pem  - Приватный ключ

=== КОМАНДЫ ПРОВЕРКИ ===
# Проверка срока действия:
openssl x509 -in cert.pem -noout -dates

# Проверка соответствия ключа и сертификата:
openssl x509 -in cert.pem -noout -modulus | openssl md5
openssl rsa -in privkey.pem -noout -modulus | openssl md5

=== MOODLE ИНТЕГРАЦИЯ ===
# Конфигурация Nginx: /etc/nginx/sites-available/moodle-ssl
# Moodle config.php: $CFG->wwwroot = 'https://$DOMAIN';
# SSL редирект: Автоматически настроен в Nginx
EOF

echo "3. Установка правильных прав доступа..."
chmod 644 "$CERT_DIR"/*.pem
chmod 600 "$CERT_DIR/privkey.pem"  # Приватный ключ должен быть только для owner
chmod 644 "$CERT_DIR/cert-info.txt"

echo "4. Проверка целостности скопированных файлов..."

# Проверка, что скопированные файлы валидны
if openssl x509 -in "$CERT_DIR/cert.pem" -noout -text >/dev/null 2>&1; then
    echo "   ✅ cert.pem - валидный сертификат"
else
    echo "   ❌ cert.pem - поврежден"
    exit 1
fi

if openssl rsa -in "$CERT_DIR/privkey.pem" -check -noout >/dev/null 2>&1; then
    echo "   ✅ privkey.pem - валидный ключ"
else
    echo "   ❌ privkey.pem - поврежден"
    exit 1
fi

# Проверка соответствия ключа и сертификата
CERT_MODULUS=$(openssl x509 -in "$CERT_DIR/cert.pem" -noout -modulus | openssl md5)
KEY_MODULUS=$(openssl rsa -in "$CERT_DIR/privkey.pem" -noout -modulus | openssl md5)

if [ "$CERT_MODULUS" = "$KEY_MODULUS" ]; then
    echo "   ✅ Сертификат и ключ соответствуют друг другу"
else
    echo "   ❌ Сертификат и ключ НЕ соответствуют!"
    exit 1
fi

echo "5. Информация о сохраненных файлах..."
echo "📁 Директория: $CERT_DIR"
echo "📋 Сохраненные файлы:"
ls -la "$CERT_DIR"

echo
echo "✅ Резервное копирование завершено успешно!"
echo "📝 Информация о сертификате: $CERT_DIR/cert-info.txt"
echo "🔐 Сертификаты готовы для коммита в репозиторий"
echo

# Показываем срок действия
echo "📅 Срок действия сертификата:"
openssl x509 -in "$CERT_DIR/cert.pem" -noout -dates

echo
echo "💡 Следующие шаги:"
echo "   1. Добавьте файлы в git: git add moodle-ssl-certificates/"
echo "   2. Закоммитьте: git commit -m 'Обновлены SSL сертификаты для Moodle ($DOMAIN)'"
echo "   3. Отправьте в репозиторий: git push"
echo
echo "⚠️  ВНИМАНИЕ: Убедитесь, что репозиторий приватный!"
echo "   Приватные ключи не должны попадать в публичные репозитории"
