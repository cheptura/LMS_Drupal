#!/bin/bash

# RTTI Drupal - Опциональная установка почтового сервера
# Устанавливает и настраивает Postfix для отправки уведомлений

echo "=== Установка почтового сервера для RTTI Drupal ==="
echo "⚠️  ВНИМАНИЕ: Этот скрипт опциональный!"
echo "   Запускайте только если нужны email уведомления"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DOMAIN="omuzgorpro.tj"
HOSTNAME="storage.$DOMAIN"

echo "🔍 Проверяем, установлен ли уже почтовый сервер..."

if systemctl is-active --quiet postfix; then
    echo "✅ Postfix уже установлен и работает"
    systemctl status postfix --no-pager
    exit 0
fi

echo "📧 Устанавливаем почтовый сервер..."

# Предварительная настройка для автоматической установки
echo "postfix postfix/mailname string $HOSTNAME" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

# Установка пакетов
apt update
apt install -y postfix mailutils

echo "⚙️  Настраиваем Postfix..."

# Основная конфигурация
cat > /etc/postfix/main.cf << EOF
# RTTI Drupal Library - Postfix Configuration
# Date: $(date)

# Basic settings
myhostname = $HOSTNAME
mydomain = $DOMAIN
myorigin = \$mydomain
inet_interfaces = loopback-only
inet_protocols = ipv4
mydestination = localhost

# Network settings
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

# Mail directory
home_mailbox = Maildir/

# SMTP settings for outbound mail
relayhost = 

# Security settings
smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no

# TLS settings
smtp_tls_security_level = may
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtpd_tls_security_level = may
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache

# Virtual settings (для локальной отправки)
virtual_alias_domains = 
virtual_alias_maps = hash:/etc/postfix/virtual

# Size limits
message_size_limit = 10485760
mailbox_size_limit = 1073741824

# Logging
maillog_file = /var/log/postfix.log
EOF

# Создание виртуальных псевдонимов
cat > /etc/postfix/virtual << EOF
# Virtual aliases for RTTI Drupal Library
admin@$DOMAIN root
security@$DOMAIN root
support@$DOMAIN root
noreply@$DOMAIN root
drupal@$DOMAIN root
EOF

# Применение изменений
postmap /etc/postfix/virtual

echo "🔧 Настраиваем aliases..."

# Настройка aliases
cat > /etc/aliases << EOF
# RTTI Drupal Library aliases
postmaster: root
mailer-daemon: postmaster
nobody: root
hostmaster: root
usenet: root
news: root
webmaster: root
www: root
ftp: root
abuse: root
security: root
admin: root
drupal: root

# Forward root mail to external email (опционально)
# root: hathona@gmail.com
EOF

newaliases

echo "🚀 Запускаем и включаем Postfix..."
systemctl enable postfix
systemctl restart postfix

echo "🧪 Тестируем отправку почты..."

# Тест отправки
echo "Test message from RTTI Drupal Library server at $(date)" | mail -s "Test Email from $HOSTNAME" root

if [ $? -eq 0 ]; then
    echo "✅ Тестовое письмо отправлено"
else
    echo "❌ Ошибка отправки тестового письма"
fi

echo "📊 Статус сервисов:"
systemctl status postfix --no-pager -l

echo "📋 Проверка логов:"
tail -10 /var/log/postfix.log

echo "🔧 Полезные команды:"
echo "   Статус Postfix: systemctl status postfix"
echo "   Логи Postfix: tail -f /var/log/postfix.log"
echo "   Отправка письма: echo 'text' | mail -s 'subject' user@domain.com"
echo "   Очередь писем: mailq"
echo "   Очистка очереди: postsuper -d ALL"

echo
echo "✅ Установка почтового сервера завершена!"
echo
echo "📧 Теперь можно включить email уведомления в скриптах:"
echo "   1. Раскомментируйте строки с 'mail' командами"
echo "   2. Убедитесь что aliases настроены корректно"
echo "   3. Проверьте что сообщения доставляются"
echo
echo "⚠️  ВАЖНО:"
echo "   - Настройте SPF записи в DNS"
echo "   - Рассмотрите использование внешнего SMTP"
echo "   - Мониторьте логи на спам и ошибки"
