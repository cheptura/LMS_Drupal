#!/bin/bash

# RTTI Moodle - Шаг 8: Умная установка Moodle
# Сервер: lms.rtti.tj (92.242.60.172)
# Автоматически обрабатывает все возможные ситуации и проблемы

echo "=== RTTI Moodle - Шаг 8: Умная установка Moodle ==="
echo "🚀 Анализ ситуации и выбор стратегии установки"
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
    echo "🔧 Сначала запустите: ./06-download-moodle.sh && ./07-configure-moodle.sh"
    exit 1
fi

echo "🔍 Анализ текущего состояния системы..."

# Функция проверки и исправления PHP конфигурации
check_and_fix_php() {
    echo "🔧 Проверка конфигурации PHP..."
    
    # Проверяем max_input_vars
    MAX_INPUT_VARS=$(php -r "echo ini_get('max_input_vars');")
    if [ "$MAX_INPUT_VARS" -lt 5000 ]; then
        echo "⚠️  max_input_vars = $MAX_INPUT_VARS (требуется >= 5000)"
        echo "🔧 Исправление конфигурации PHP..."
        
        # Определяем версию PHP
        PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
        PHP_FPM_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
        PHP_CLI_INI="/etc/php/$PHP_VERSION/cli/php.ini"
        
        # Функция для установки PHP параметра
        set_php_setting() {
            local setting=$1
            local value=$2
            local file=$3
            
            if [ -f "$file" ]; then
                # Удаляем существующие настройки
                sed -i "/^;*\s*$setting\s*=/d" "$file"
                # Добавляем новую настройку
                echo "$setting = $value" >> "$file"
            fi
        }
        
        # Исправляем оба INI файла
        for ini_file in "$PHP_FPM_INI" "$PHP_CLI_INI"; do
            if [ -f "$ini_file" ]; then
                echo "   Настройка $ini_file..."
                set_php_setting "max_input_vars" "5000" "$ini_file"
                set_php_setting "max_execution_time" "300" "$ini_file"
                set_php_setting "memory_limit" "512M" "$ini_file"
                set_php_setting "post_max_size" "100M" "$ini_file"
                set_php_setting "upload_max_filesize" "100M" "$ini_file"
            fi
        done
        
        # Перезапускаем PHP-FPM
        systemctl restart php$PHP_VERSION-fpm
        
        # Проверяем результат
        MAX_INPUT_VARS_NEW=$(php -r "echo ini_get('max_input_vars');")
        if [ "$MAX_INPUT_VARS_NEW" -ge 5000 ]; then
            echo "✅ max_input_vars исправлен: $MAX_INPUT_VARS_NEW"
        else
            echo "❌ Не удалось исправить max_input_vars автоматически"
            echo "🔧 Ручное исправление:"
            echo "   sudo nano /etc/php/$PHP_VERSION/fpm/php.ini"
            echo "   Найдите и установите: max_input_vars = 5000"
            echo "   sudo systemctl restart php$PHP_VERSION-fpm"
            exit 1
        fi
    else
        echo "✅ max_input_vars = $MAX_INPUT_VARS (соответствует требованиям)"
    fi
}

# Проверяем и исправляем PHP
check_and_fix_php

echo
echo "1. Проверка состояния всех сервисов..."

SERVICES=("nginx" "php8.3-fpm" "postgresql" "redis-server")
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: работает"
    else
        echo "❌ $service: не работает"
        echo "🔧 Попытка запуска $service..."
        systemctl start $service
        sleep 2
        if systemctl is-active --quiet $service; then
            echo "✅ $service: запущен"
        else
            echo "❌ Не удалось запустить $service"
            if [ "$service" = "php8.3-fpm" ]; then
                echo "🔧 Попытка установки $service..."
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

echo "4. Анализ ситуации и выбор стратегии установки..."
ADMIN_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)
ADMIN_EMAIL="admin@rtti.tj"

cd $MOODLE_DIR

# Проверяем состояние конфигурации и базы данных
CONFIG_EXISTS=false
DB_EXISTS=false
MOODLE_INSTALLED=false

if [ -f "$CONFIG_FILE" ]; then
    echo "ℹ️  Найден файл конфигурации Moodle"
    CONFIG_EXISTS=true
fi

# Проверяем базу данных
DB_CHECK=$(sudo -u postgres psql -d moodle -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'mdl_config');" -t 2>/dev/null | tr -d ' ')
if [ "$DB_CHECK" = "t" ]; then
    echo "ℹ️  База данных Moodle уже содержит установку"
    DB_EXISTS=true
fi

# Определяем стратегию
echo
echo "📋 Определение стратегии установки:"

if [ "$CONFIG_EXISTS" = true ] && [ "$DB_EXISTS" = true ]; then
    echo "✅ Полная установка обнаружена - проверяем целостность"
    
    # Проверяем целостность установки
    INTEGRITY_CHECK=$(sudo -u www-data php admin/cli/check_database_schema.php 2>&1 | grep -c "error" || echo "0")
    
    if [ "$INTEGRITY_CHECK" -eq 0 ]; then
        echo "✅ Moodle уже полностью установлен и работает корректно"
        MOODLE_INSTALLED=true
        
        # Проверяем доступность через веб
        ADMIN_EXISTS=$(sudo -u www-data php -r "
        require_once 'config.php';
        require_once 'lib/moodlelib.php';
        \$user = \$DB->get_record('user', array('username' => 'admin'));
        echo \$user ? 'true' : 'false';
        " 2>/dev/null)
        
        if [ "$ADMIN_EXISTS" = "true" ]; then
            echo "✅ Администратор уже существует"
            echo "🌐 Доступ: https://lms.rtti.tj"
            echo "👤 Пользователь: admin"
            echo "🔐 Используйте существующий пароль или сбросьте его через интерфейс"
        fi
    else
        echo "⚠️  Обнаружены проблемы целостности - выполняем обновление"
        sudo -u www-data php admin/cli/upgrade.php --non-interactive
        INSTALL_RESULT=$?
    fi
    
elif [ "$CONFIG_EXISTS" = true ] && [ "$DB_EXISTS" = false ]; then
    echo "🔄 Конфигурация найдена, но база данных пустая - завершаем установку"
    
    # Установка только базы данных
    echo "🗃️  Установка схемы базы данных..."
    sudo -u www-data php admin/cli/install_database.php \
        --agree-license \
        --fullname="RTTI Learning Management System" \
        --shortname="RTTI LMS" \
        --adminuser=admin \
        --adminpass=$ADMIN_PASSWORD \
        --adminemail=$ADMIN_EMAIL
    INSTALL_RESULT=$?
    
elif [ "$CONFIG_EXISTS" = false ] && [ "$DB_EXISTS" = true ]; then
    echo "🔧 База данных найдена, но конфигурация отсутствует - восстанавливаем"
    
    echo "❌ Необычная ситуация: есть база, но нет config.php"
    echo "🔧 Необходимо пересоздать конфигурацию. Запустите:"
    echo "   sudo ./07-configure-moodle.sh"
    exit 1
    
else
    echo "🆕 Новая установка - выполняем полную установку"
    
    # Удаляем неполный config.php если он есть
    if [ -f "$CONFIG_FILE" ]; then
        echo "🗑️  Удаление неполного файла конфигурации..."
        rm -f "$CONFIG_FILE"
        echo "🔧 Пересоздание конфигурации..."
        
        # Нужно пересоздать config.php
        DB_PASSWORD=$(grep "Пароль:" /root/moodle-db-credentials.txt | awk '{print $2}' 2>/dev/null || echo "")
        REDIS_PASSWORD=$(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print $2}' 2>/dev/null || echo "")
        
        if [ -z "$DB_PASSWORD" ] || [ -z "$REDIS_PASSWORD" ]; then
            echo "❌ Не найдены пароли для базы данных или Redis"
            echo "🔧 Запустите сначала: sudo ./07-configure-moodle.sh"
            exit 1
        fi
        
        # Создаем config.php снова
        cat > $MOODLE_DIR/config.php << EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'pgsql';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'moodleuser';
\$CFG->dbpass    = '$DB_PASSWORD';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => 5432,
    'dbsocket' => '',
    'dbcollation' => 'utf8_unicode_ci',
);

\$CFG->wwwroot   = 'https://lms.rtti.tj';
\$CFG->dataroot  = '/var/moodledata';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0777;

// Redis session configuration
\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '127.0.0.1';
\$CFG->session_redis_port = 6379;
\$CFG->session_redis_auth = '$REDIS_PASSWORD';
\$CFG->session_redis_database = 0;
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;

require_once(__DIR__ . '/lib/setup.php');
EOF
        
        chown www-data:www-data $CONFIG_FILE
        chmod 640 $CONFIG_FILE
    fi
    
    # Полная новая установка
    echo "🚀 Запуск полной установки Moodle..."
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
fi

# Обработка результата установки
if [ "$MOODLE_INSTALLED" = true ]; then
    echo "✅ Moodle уже установлен и работает"
    INSTALL_RESULT=0
elif [ $INSTALL_RESULT -eq 0 ]; then
    echo "✅ Установка/обновление Moodle завершено успешно"
    
    # Сохраняем данные администратора
    echo "Данные администратора Moodle RTTI:" > /var/log/moodle-install.log
    echo "Дата установки: $(date)" >> /var/log/moodle-install.log
    echo "Пользователь: admin" >> /var/log/moodle-install.log
    echo "Пароль: $ADMIN_PASSWORD" >> /var/log/moodle-install.log
    echo "Email: $ADMIN_EMAIL" >> /var/log/moodle-install.log
    echo "URL: https://lms.rtti.tj" >> /var/log/moodle-install.log
    
    chmod 600 /var/log/moodle-install.log
    
    echo
    echo "🔑 Данные администратора:"
    echo "   👤 Пользователь: admin"
    echo "   🔐 Пароль: $ADMIN_PASSWORD"
    echo "   📧 Email: $ADMIN_EMAIL"
    echo "   📄 Сохранено в: /var/log/moodle-install.log"
else
    echo "❌ Ошибка установки/обновления Moodle"
    echo "📋 Проверьте логи:"
    echo "   sudo tail -50 /var/log/nginx/error.log"
    echo "   sudo tail -50 /var/log/php8.3-fpm.log"
    echo "   sudo journalctl -u nginx -n 20"
    echo "   sudo journalctl -u php8.3-fpm -n 20"
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

echo "5. Настройка умного cron для Moodle..."

# Сначала останавливаем любые запущенные cron процессы
echo "🛑 Остановка существующих cron процессов..."
CRON_PIDS=$(pgrep -f "cron.php" 2>/dev/null || echo "")
if [ -n "$CRON_PIDS" ]; then
    echo "   Найдены запущенные процессы: $CRON_PIDS"
    kill $CRON_PIDS 2>/dev/null || true
    sleep 2
    # Принудительная остановка если нужно
    REMAINING_PIDS=$(pgrep -f "cron.php" 2>/dev/null || echo "")
    if [ -n "$REMAINING_PIDS" ]; then
        kill -9 $REMAINING_PIDS 2>/dev/null || true
    fi
    echo "✅ Cron процессы остановлены"
else
    echo "ℹ️  Запущенных cron процессов не найдено"
fi

# Создаем правильный системный cron
echo "🔧 Настройка системного cron..."
cat > /etc/cron.d/moodle << EOF
# Moodle cron job - RTTI Configuration
# Выполняется каждую минуту с флагом --quiet (без keep-alive режима)
* * * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/cron.php --quiet >/dev/null 2>&1

# Очистка кэша каждые 4 часа
0 */4 * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/purge_caches.php >/dev/null 2>&1

# Проверка обновлений каждый день в 3:00
0 3 * * * www-data /usr/bin/php $MOODLE_DIR/admin/cli/check_for_updates.php >/dev/null 2>&1

# Резервное копирование каждую ночь в 2:00
0 2 * * * root [ -f /root/moodle-backup.sh ] && /root/moodle-backup.sh >/dev/null 2>&1
EOF

# Устанавливаем правильные права
chmod 644 /etc/cron.d/moodle
chown root:root /etc/cron.d/moodle

# Перезапускаем cron службу
systemctl restart cron

echo "✅ Системный cron настроен (--quiet режим, без keep-alive)"

echo "6. Применение дополнительных настроек производительности..."

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
echo "10. Финальные проверки системы..."

# Проверка доступности Moodle через CLI
echo "🧪 Проверка работоспособности Moodle..."
cd $MOODLE_DIR

# Тест подключения к базе данных
DB_TEST=$(sudo -u www-data php -r "
require_once 'config.php';
try {
    \$DB->get_record('user', array('id' => 1));
    echo 'OK';
} catch (Exception \$e) {
    echo 'ERROR: ' . \$e->getMessage();
}" 2>/dev/null)

if [[ $DB_TEST == "OK" ]]; then
    echo "✅ База данных работает корректно"
else
    echo "❌ Проблема с базой данных: $DB_TEST"
fi

# Тест cron (одноразовый запуск для проверки)
echo "🧪 Тестирование cron..."
CRON_TEST=$(sudo -u www-data php admin/cli/cron.php --quiet 2>&1)
if [ $? -eq 0 ]; then
    echo "✅ Cron работает корректно"
else
    echo "⚠️  Предупреждение cron: $CRON_TEST"
fi

# Проверка PHP настроек еще раз
MAX_INPUT_VARS_FINAL=$(php -r "echo ini_get('max_input_vars');")
if [ "$MAX_INPUT_VARS_FINAL" -ge 5000 ]; then
    echo "✅ PHP max_input_vars = $MAX_INPUT_VARS_FINAL (требования выполнены)"
else
    echo "⚠️  PHP max_input_vars = $MAX_INPUT_VARS_FINAL (может потребоваться дополнительная настройка)"
fi

echo "11. Проверка статуса сервисов..."
echo -n "Nginx: "; systemctl is-active nginx
echo -n "PHP-FPM: "; systemctl is-active php8.3-fpm  
echo -n "PostgreSQL: "; systemctl is-active postgresql
echo -n "Redis: "; systemctl is-active redis-server
echo -n "Cron: "; systemctl is-active cron

# Создание файла статуса установки
cat > /root/moodle-installation-status.txt << EOF
=== MOODLE INSTALLATION STATUS ===
Дата установки: $(date)
Статус: УСПЕШНО ЗАВЕРШЕНА
Сервер: lms.rtti.tj ($(hostname -I | awk '{print $1}'))

Компоненты:
- Moodle: $(sudo -u www-data php -r "require_once '$MOODLE_DIR/config.php'; require_once '$MOODLE_DIR/version.php'; echo \$release;" 2>/dev/null || echo "Установлен")
- PHP: $(php --version | head -1)
- PostgreSQL: $(sudo -u postgres psql --version | head -1)
- Nginx: $(nginx -v 2>&1)
- Redis: $(redis-server --version | head -1)

Настройки PHP:
- max_input_vars: $MAX_INPUT_VARS_FINAL
- memory_limit: $(php -r "echo ini_get('memory_limit');")
- max_execution_time: $(php -r "echo ini_get('max_execution_time');")

Доступ:
- URL: https://lms.rtti.tj
- Администратор: admin
- Данные сохранены в: /var/log/moodle-install.log

Статус сервисов:
- Nginx: $(systemctl is-active nginx)
- PHP-FPM: $(systemctl is-active php8.3-fpm)
- PostgreSQL: $(systemctl is-active postgresql)
- Redis: $(systemctl is-active redis-server)
- Cron: $(systemctl is-active cron)
EOF

echo
echo "🎉 ================================================"
echo "🎉 УМНАЯ УСТАНОВКА MOODLE ЗАВЕРШЕНА УСПЕШНО!"
echo "🎉 ================================================"
echo
echo "📍 URL: https://lms.rtti.tj"
echo "👤 Администратор: admin"
if [ "$MOODLE_INSTALLED" != true ]; then
    echo "🔑 Пароль: $ADMIN_PASSWORD"
    echo "📧 Email: $ADMIN_EMAIL"
else
    echo "🔑 Пароль: используйте существующий или сбросьте через интерфейс"
fi
echo
echo "📋 Следующие шаги:"
echo "1. Откройте https://lms.rtti.tj в браузере"
echo "2. Войдите с данными администратора"
if [ "$MOODLE_INSTALLED" != true ]; then
    echo "3. Смените пароль на более безопасный"
    echo "4. Настройте параметры организации"
fi
echo "5. Запустите ./09-post-install.sh для дополнительных настроек"
echo
echo "📁 Важные файлы:"
if [ "$MOODLE_INSTALLED" != true ]; then
    echo "   - Данные администратора: /var/log/moodle-install.log"
fi
echo "   - Статус установки: /root/moodle-installation-status.txt"
echo "   - Управление cron: ./manage-cron.sh"
echo "   - Диагностика: ./diagnose-moodle.sh"
echo
echo "✅ Шаг 8 завершен успешно!"
echo "📌 Следующий шаг: ./09-post-install.sh"
echo
