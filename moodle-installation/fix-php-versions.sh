#!/bin/bash

# RTTI Moodle - Исправление PHP версий
# Полная очистка и установка только PHP 8.2

echo "=== RTTI Moodle - Исправление PHP версий ==="
echo "🔧 Полная очистка и установка PHP 8.2"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Остановка всех PHP-FPM сервисов..."
systemctl stop php*.* 2>/dev/null || true

echo "2. Удаление всех версий PHP кроме 8.2..."
apt remove --purge -y php8.0* php8.1* php8.3* php8.4* 2>/dev/null || true
apt autoremove -y

echo "3. Добавление репозитория PHP..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "4. Установка PHP 8.2 и всех необходимых расширений..."
apt install -y \
    php8.2 \
    php8.2-fpm \
    php8.2-common \
    php8.2-cli \
    php8.2-pgsql \
    php8.2-mysql \
    php8.2-xml \
    php8.2-xmlrpc \
    php8.2-curl \
    php8.2-gd \
    php8.2-imagick \
    php8.2-dev \
    php8.2-imap \
    php8.2-mbstring \
    php8.2-opcache \
    php8.2-soap \
    php8.2-zip \
    php8.2-intl \
    php8.2-bcmath \
    php8.2-ldap \
    php8.2-redis \
    php8.2-fileinfo \
    php8.2-ctype \
    php8.2-tokenizer \
    php8.2-exif \
    php8.2-json \
    php8.2-dom

echo "5. Установка PHP 8.2 как версии по умолчанию..."
update-alternatives --install /usr/bin/php php /usr/bin/php8.2 100
update-alternatives --set php /usr/bin/php8.2

echo "6. Проверка установленных расширений..."
echo "Версия PHP: $(php --version | head -1)"
echo "Установленные расширения для Moodle:"
php -m | grep -E "(pgsql|redis|curl|xml|mbstring|json|zip|gd|intl|opcache)"

echo "7. Настройка PHP 8.2 для Moodle..."
PHP_INI="/etc/php/8.2/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    cp $PHP_INI ${PHP_INI}.backup-$(date +%Y%m%d)
    
    # Настройки производительности для Moodle
    sed -i 's/^max_execution_time = 30/max_execution_time = 300/' $PHP_INI
    sed -i 's/^max_input_time = 60/max_input_time = 300/' $PHP_INI
    sed -i 's/^memory_limit = 128M/memory_limit = 512M/' $PHP_INI
    sed -i 's/^post_max_size = 8M/post_max_size = 100M/' $PHP_INI
    sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 100M/' $PHP_INI
    sed -i 's/^;max_input_vars = 1000/max_input_vars = 5000/' $PHP_INI
    sed -i 's/^;opcache.enable=1/opcache.enable=1/' $PHP_INI
    sed -i 's/^;opcache.memory_consumption=128/opcache.memory_consumption=256/' $PHP_INI
    
    echo "✅ PHP 8.2 настроен для Moodle"
fi

echo "8. Запуск и включение автозапуска PHP 8.2 FPM..."
systemctl enable php8.2-fpm
systemctl start php8.2-fpm

echo "9. Проверка статуса PHP 8.2 FPM..."
if systemctl is-active --quiet php8.2-fpm; then
    echo "✅ PHP 8.2 FPM работает"
    systemctl status php8.2-fpm --no-pager -l
else
    echo "❌ PHP 8.2 FPM не запущен"
    journalctl -u php8.2-fpm --no-pager -n 10
    exit 1
fi

echo "10. Обновление конфигурации Nginx..."
NGINX_CONFIG="/etc/nginx/sites-available/lms.rtti.tj"
if [ -f "$NGINX_CONFIG" ]; then
    # Исправляем путь к PHP-FPM сокету
    sed -i 's|fastcgi_pass unix:/var/run/php/php.*-fpm\.sock;|fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;|g' $NGINX_CONFIG
    echo "✅ Конфигурация Nginx обновлена"
    
    # Проверяем конфигурацию
    nginx -t
    if [ $? -eq 0 ]; then
        systemctl reload nginx
        echo "✅ Nginx перезагружен"
    else
        echo "❌ Ошибка в конфигурации Nginx"
    fi
fi

echo "11. Сохранение информации о PHP..."
cat > /root/moodle-php-info.txt << EOF
# Информация о PHP для Moodle
# Дата установки: $(date)
PHP_VERSION=8.2
PHP_FPM_SERVICE=php8.2-fpm
PHP_INI_PATH=/etc/php/8.2/fpm/php.ini
PHP_SOCKET_PATH=/var/run/php/php8.2-fpm.sock
EOF

echo "12. Финальная проверка..."
echo "PHP версия: $(php --version | head -1)"
echo "PHP-FPM статус: $(systemctl is-active php8.2-fpm)"
echo "Nginx статус: $(systemctl is-active nginx)"

echo
echo "✅ Исправление PHP завершено!"
echo "📌 Установлен и настроен только PHP 8.2"
echo "📌 Все другие версии PHP удалены"
echo "📌 Конфигурация обновлена"
echo "📌 Теперь можно продолжить установку: ./08-install-moodle.sh"
echo
