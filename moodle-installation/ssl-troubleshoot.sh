#!/bin/bash

# RTTI Moodle - SSL Troubleshooting Script
# Диагностика и исправление проблем с SSL

echo "=== RTTI Moodle - SSL Troubleshooting ==="
echo "🔧 Диагностика проблем с SSL сертификатами"
echo "📅 Дата: $(date)"
echo

DOMAIN="lms.rtti.tj"
EMAIL="admin@rtti.tj"

echo "1. Проверка DNS записей..."
echo "Проверяем A-запись для $DOMAIN:"
dig +short A $DOMAIN
echo
echo "Проверяем A-запись для www.$DOMAIN:"
dig +short A www.$DOMAIN
echo

echo "2. Проверка доступности портов..."
echo "Порт 80 (HTTP):"
netstat -tuln | grep :80 || echo "Порт 80 не открыт"
echo "Порт 443 (HTTPS):"
netstat -tuln | grep :443 || echo "Порт 443 не открыт"
echo

echo "3. Проверка статуса Nginx..."
systemctl status nginx --no-pager
echo

echo "4. Проверка конфигурации Nginx..."
nginx -t
echo

echo "5. Проверка активных сайтов..."
echo "Активные сайты в /etc/nginx/sites-enabled/:"
ls -la /etc/nginx/sites-enabled/
echo

echo "6. Проверка логов Nginx..."
echo "Последние ошибки Nginx:"
tail -10 /var/log/nginx/error.log 2>/dev/null || echo "Лог ошибок недоступен"
echo

echo "7. Проверка Let's Encrypt сертификатов..."
certbot certificates 2>/dev/null || echo "Certbot не установлен или нет сертификатов"
echo

echo "8. Проверка логов Let's Encrypt..."
echo "Последние записи Let's Encrypt:"
tail -20 /var/log/letsencrypt/letsencrypt.log 2>/dev/null || echo "Лог Let's Encrypt недоступен"
echo

echo "9. Тест HTTP подключения..."
curl -I http://$DOMAIN 2>/dev/null | head -3 || echo "HTTP недоступен"
echo

echo "10. Тест HTTPS подключения..."
curl -I https://$DOMAIN 2>/dev/null | head -3 || echo "HTTPS недоступен"
echo

echo "=== Рекомендации по исправлению ==="
echo

# Проверяем основные проблемы
DNS_A=$(dig +short A $DOMAIN)
DNS_WWW=$(dig +short A www.$DOMAIN)
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ -z "$DNS_A" ]; then
    echo "❌ ПРОБЛЕМА: DNS A-запись для $DOMAIN не найдена"
    echo "   РЕШЕНИЕ: Добавьте A-запись $DOMAIN -> $CURRENT_IP в DNS"
    echo
fi

if [ "$DNS_A" != "$CURRENT_IP" ] && [ -n "$DNS_A" ]; then
    echo "❌ ПРОБЛЕМА: DNS A-запись для $DOMAIN указывает на $DNS_A, а должна на $CURRENT_IP"
    echo "   РЕШЕНИЕ: Обновите A-запись $DOMAIN -> $CURRENT_IP в DNS"
    echo
fi

if [ -n "$DNS_WWW" ] && [ "$DNS_WWW" != "$CURRENT_IP" ]; then
    echo "❌ ПРОБЛЕМА: DNS A-запись для www.$DOMAIN указывает на $DNS_WWW, а должна на $CURRENT_IP"
    echo "   РЕШЕНИЕ: Обновите A-запись www.$DOMAIN -> $CURRENT_IP в DNS или удалите www-запись"
    echo
fi

if [ -z "$DNS_WWW" ]; then
    echo "⚠️  ЗАМЕЧАНИЕ: www.$DOMAIN не имеет DNS записи"
    echo "   РЕШЕНИЕ: Либо добавьте A-запись www.$DOMAIN -> $CURRENT_IP, либо используйте только основной домен"
    echo
fi

# Проверяем порты
if ! netstat -tuln | grep -q :80; then
    echo "❌ ПРОБЛЕМА: Порт 80 не открыт"
    echo "   РЕШЕНИЕ: ufw allow 80/tcp"
    echo
fi

if ! systemctl is-active --quiet nginx; then
    echo "❌ ПРОБЛЕМА: Nginx не запущен"
    echo "   РЕШЕНИЕ: systemctl start nginx"
    echo
fi

echo "=== Команды для быстрого исправления ==="
echo

echo "# Если нужно получить сертификат только для основного домена:"
echo "certbot certonly --nginx --non-interactive --agree-tos --email $EMAIL --domains $DOMAIN"
echo

echo "# Если нужно получить сертификат для основного домена и www:"
echo "certbot certonly --nginx --non-interactive --agree-tos --email $EMAIL --domains $DOMAIN,www.$DOMAIN"
echo

echo "# Если нужно удалить существующий сертификат:"
echo "certbot delete --cert-name $DOMAIN"
echo

echo "# Принудительное обновление сертификата:"
echo "certbot renew --force-renewal"
echo

echo "# Проверка конфигурации и перезапуск Nginx:"
echo "nginx -t && systemctl reload nginx"
echo

echo "# Проверка статуса файрвола:"
echo "ufw status"
echo

echo "# Открытие необходимых портов:"
echo "ufw allow 80/tcp"
echo "ufw allow 443/tcp"
echo

echo "=== Использование исправленного скрипта ==="
echo "Для автоматического решения проблем с www-доменом используйте:"
echo "./05-configure-ssl-fixed.sh"
echo
