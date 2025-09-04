#!/bin/bash

# RTTI Moodle - Шаг 8: Установка Moodle
# Сервер: lms.rtti.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 8: Установка Moodle через CLI ==="
echo "🚀 Запуск процесса установки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

MOODLE_DIR="/var/www/moodle"
CONFIG_FILE="$MOODLE_DIR/config.php"

# Проверка готовности к установке
if [ ! -d "$MOODLE_DIR" ]; then
    echo "❌ Каталог Moodle не найден: $MOODLE_DIR"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Конфигурационный файл не найден: $CONFIG_FILE"
    exit 1
fi

echo "1. Проверка состояния всех сервисов..."

SERVICES=("nginx" "php8.3-fpm" "postgresql" "redis-server")
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: работает"
    else
        echo "❌ $service: не работает"
        echo "Попытка запуска $service..."
        systemctl start $service
        sleep 2
        if systemctl is-active --quiet $service; then
            echo "✅ $service: запущен"
        else
            echo "❌ Не удалось запустить $service"
            if [ "$service" = "php8.3-fpm" ]; then
                echo "Попытка установки $service..."
                apt install -y $service
                systemctl enable $service
                systemctl start $service
                if systemctl is-active --quiet $service; then
                    echo "✅ $service: установлен и запущен"
                else
                    echo "❌ Критическая ошибка: не удалось запустить $service"
                    exit 1
                fi
            else
                exit 1
            fi
        fi
    fi
done

echo "2. Проверка доступности домена..."
curl -I https://lms.rtti.tj >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Домен lms.rtti.tj доступен"
else
    echo "⚠️  Домен lms.rtti.tj недоступен извне, но установка продолжится"
fi

echo "3. Проверка подключений к базе данных и Redis..."
DB_PASSWORD=$(grep "Пароль:" /root/moodle-db-credentials.txt | awk '{print $2}')
REDIS_PASSWORD=$(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print $2}')

# Проверка базы данных
sudo -u postgres psql -d moodle -c "SELECT version();" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL доступен"
else
    echo "❌ PostgreSQL недоступен"
    exit 1
fi

# Проверка Redis
redis-cli -a $REDIS_PASSWORD ping >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Redis доступен"
else
    echo "❌ Redis недоступен"
    exit 1
fi

echo "4. Создание администратора по умолчанию..."
ADMIN_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)
ADMIN_EMAIL="admin@rtti.tj"

echo "5. Запуск установки Moodle через CLI..."
echo "Это может занять несколько минут..."

cd $MOODLE_DIR

# Установка через CLI
sudo -u www-data php admin/cli/install.php \
    --non-interactive \
    --agree-license \
    --lang=ru \
    --wwwroot=https://lms.rtti.tj \
    --dataroot=/var/moodledata \
    --dbtype=pgsql \
    --dbhost=localhost \
    --dbname=moodle \
    --dbuser=moodleuser \
    --dbpass=$DB_PASSWORD \
    --prefix=mdl_ \
    --fullname="RTTI Learning Management System" \
    --shortname="RTTI LMS" \
    --adminuser=admin \
    --adminpass=$ADMIN_PASSWORD \
    --adminemail=$ADMIN_EMAIL

INSTALL_RESULT=$?

if [ $INSTALL_RESULT -eq 0 ]; then
    echo "✅ Базовая установка Moodle завершена успешно"
else
    echo "❌ Ошибка установки Moodle"
    echo "Проверьте логи в /var/log/nginx/ и /var/log/php8.3-fpm.log"
    exit 1
fi

echo "6. Применение дополнительных настроек производительности..."
sudo -u www-data php admin/cli/cfg.php --name=enablecompletion --set=1
sudo -u www-data php admin/cli/cfg.php --name=completiondefault --set=1
sudo -u www-data php admin/cli/cfg.php --name=enablegzip --set=1
sudo -u www-data php admin/cli/cfg.php --name=theme --set=boost

echo "7. Настройка кэширования..."
# Очистка кэша
sudo -u www-data php admin/cli/purge_caches.php

# Переустановка кэша
sudo -u www-data php admin/cli/alternative_component_cache.php --rebuild

echo "8. Создание дополнительных каталогов..."
mkdir -p /var/moodledata/{cache,sessions,temp,repository,backup}
chown -R www-data:www-data /var/moodledata
chmod -R 755 /var/moodledata

echo "9. Настройка cron для Moodle..."
cat > /etc/cron.d/moodle << EOF
# Moodle cron job
# Выполняется каждую минуту для обработки задач
* * * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/cron.php >/dev/null 2>&1

# Очистка кэша каждый час
0 * * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/purge_caches.php >/dev/null 2>&1

# Резервное копирование каждую ночь в 2:00
0 2 * * * root /root/moodle-backup.sh >/dev/null 2>&1
EOF

echo "10. Создание скрипта резервного копирования..."
cat > /root/moodle-backup.sh << EOF
#!/bin/bash
# Автоматическое резервное копирование Moodle

BACKUP_DIR="/var/backups/moodle"
DATE=\$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="\$BACKUP_DIR/moodle-backup-\$DATE"

echo "=== Moodle Backup: \$DATE ==="

# Создание каталога для резервных копий
mkdir -p \$BACKUP_PATH

# Включение режима обслуживания
sudo -u www-data php $MOODLE_DIR/admin/cli/maintenance.php --enable

# Резервное копирование файлов
echo "Копирование файлов..."
tar -czf \$BACKUP_PATH/moodle-files.tar.gz -C /var/www moodle
tar -czf \$BACKUP_PATH/moodle-data.tar.gz -C /var moodledata

# Резервное копирование базы данных
echo "Резервное копирование базы данных..."
sudo -u postgres pg_dump moodle > \$BACKUP_PATH/moodle-database.sql

# Отключение режима обслуживания
sudo -u www-data php $MOODLE_DIR/admin/cli/maintenance.php --disable

# Удаление старых резервных копий (старше 7 дней)
find \$BACKUP_DIR -name "moodle-backup-*" -type d -mtime +7 -exec rm -rf {} \;

echo "Резервное копирование завершено: \$BACKUP_PATH"
EOF

chmod +x /root/moodle-backup.sh

# Создание каталога для резервных копий
mkdir -p /var/backups/moodle
chown root:root /var/backups/moodle
chmod 755 /var/backups/moodle

echo "11. Проверка работы веб-интерфейса..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://lms.rtti.tj)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Веб-интерфейс доступен (HTTP $HTTP_STATUS)"
else
    echo "⚠️  Веб-интерфейс: HTTP $HTTP_STATUS"
fi

echo "12. Первый запуск cron..."
sudo -u www-data php $MOODLE_DIR/admin/cli/cron.php

echo "13. Сохранение данных администратора..."
cat > /root/moodle-admin-credentials.txt << EOF
# Данные администратора Moodle
# Дата создания: $(date)
# Сервер: lms.rtti.tj ($(hostname -I | awk '{print $1}'))

URL: https://lms.rtti.tj
Администратор: admin
Пароль: $ADMIN_PASSWORD
Email: $ADMIN_EMAIL

# Первый вход:
# 1. Откройте https://lms.rtti.tj
# 2. Войдите как admin с паролем выше
# 3. Измените пароль на более запоминающийся
# 4. Настройте профиль и параметры сайта

# Важные ссылки:
# Панель администратора: https://lms.rtti.tj/admin/
# Управление пользователями: https://lms.rtti.tj/admin/user.php
# Настройки сайта: https://lms.rtti.tj/admin/settings.php
# Плагины: https://lms.rtti.tj/admin/plugins.php
EOF

chmod 600 /root/moodle-admin-credentials.txt

echo "14. Создание файла статуса установки..."
cat > /root/moodle-installation-status.txt << EOF
# Статус установки Moodle RTTI LMS
# Дата завершения: $(date)
# Сервер: lms.rtti.tj ($(hostname -I | awk '{print $1}'))

=== СТАТУС: УСТАНОВЛЕНО ✅ ===

URL: https://lms.rtti.tj
Администратор: admin
Email: $ADMIN_EMAIL

=== КОМПОНЕНТЫ ===
✅ Ubuntu 24.04 LTS
✅ Nginx (веб-сервер)
✅ PHP 8.3 + расширения
✅ PostgreSQL 16 (база данных)
✅ Redis (кэширование)
✅ Let's Encrypt SSL
✅ Moodle $(grep '$release' $MOODLE_DIR/version.php | cut -d "'" -f 2)

=== АВТОМАТИЗАЦИЯ ===
✅ Cron задачи настроены
✅ Автоматическое резервное копирование
✅ SSL сертификаты обновляются автоматически

=== ВАЖНЫЕ ФАЙЛЫ ===
Данные администратора: /root/moodle-admin-credentials.txt
Данные БД: /root/moodle-db-credentials.txt
Данные Redis: /root/moodle-redis-credentials.txt
Диагностика: /root/moodle-diagnostics.sh
Резервное копирование: /root/moodle-backup.sh

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Откройте https://lms.rtti.tj
2. Войдите как admin
3. Смените пароль администратора
4. Настройте параметры организации
5. Создайте курсы и пользователей

=== ПОДДЕРЖКА ===
Логи Nginx: /var/log/nginx/
Логи PHP: /var/log/php8.3-fpm.log
Логи PostgreSQL: /var/log/postgresql/
Логи Moodle: /var/moodledata/
EOF

echo "15. Финальная проверка всех компонентов..."
echo "Проверка доступности компонентов:"
echo -n "Nginx: "; systemctl is-active nginx
echo -n "PHP-FPM: "; systemctl is-active php8.3-fpm
echo -n "PostgreSQL: "; systemctl is-active postgresql
echo -n "Redis: "; systemctl is-active redis-server

echo
echo "🎉 ================================================"
echo "🎉 УСТАНОВКА MOODLE ЗАВЕРШЕНА УСПЕШНО!"
echo "🎉 ================================================"
echo
echo "📍 URL: https://lms.rtti.tj"
echo "👤 Администратор: admin"
echo "🔑 Пароль: $ADMIN_PASSWORD"
echo "📧 Email: $ADMIN_EMAIL"
echo
echo "📋 Следующие шаги:"
echo "1. Откройте https://lms.rtti.tj в браузере"
echo "2. Войдите с данными администратора"
echo "3. Смените пароль на более безопасный"
echo "4. Настройте параметры организации"
echo "5. Запустите ./09-post-install.sh для дополнительных настроек"
echo
echo "📁 Важные файлы:"
echo "   - Данные администратора: /root/moodle-admin-credentials.txt"
echo "   - Статус установки: /root/moodle-installation-status.txt"
echo "   - Диагностика: /root/moodle-diagnostics.sh"
echo
echo "✅ Шаг 8 завершен успешно!"
echo "📌 Следующий шаг: ./09-post-install.sh"
echo
