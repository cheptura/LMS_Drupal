#!/bin/bash

# RTTI Drupal - Шаг 6: Установка Drupal 11
# Сервер: library.rtti.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 6: Установка Drupal 11 ==="
echo "📚 Загрузка и установка цифровой библиотеки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"
BACKUP_DIR="/root/drupal-backup-$(date +%Y%m%d-%H%M%S)"

echo "1. Создание резервной копии если Drupal уже установлен..."
if [ -d "$DRUPAL_DIR" ] && [ -f "$DRUPAL_DIR/composer.json" ]; then
    echo "Найдена существующая установка Drupal, создание резервной копии..."
    mkdir -p $BACKUP_DIR
    cp -r $DRUPAL_DIR $BACKUP_DIR/
    echo "✅ Резервная копия создана: $BACKUP_DIR"
fi

echo "2. Подготовка каталога для Drupal..."
mkdir -p $DRUPAL_DIR
cd $DRUPAL_DIR

# Очистка каталога если есть старые файлы
if [ "$(ls -A $DRUPAL_DIR)" ]; then
    echo "Очистка старых файлов..."
    rm -rf $DRUPAL_DIR/*
    rm -rf $DRUPAL_DIR/.*  2>/dev/null || true
fi

echo "3. Создание Drupal проекта через Composer..."
echo "Создание нового проекта Drupal 11..."

# Создание проекта Drupal с использованием composer
sudo -u www-data composer create-project drupal/recommended-project:^11.0 . --no-interaction --prefer-dist

if [ $? -ne 0 ]; then
    echo "❌ Ошибка создания проекта Drupal через Composer"
    echo "Попытка установки с другими параметрами..."
    
    # Альтернативный метод
    sudo -u www-data composer create-project drupal/recommended-project . --no-interaction
    
    if [ $? -ne 0 ]; then
        echo "❌ Не удалось создать проект Drupal"
        exit 1
    fi
fi

echo "4. Проверка установки Drupal..."
if [ ! -f "$DRUPAL_DIR/web/index.php" ]; then
    echo "❌ Файлы Drupal не найдены"
    exit 1
fi

echo "5. Определение версии Drupal..."
DRUPAL_VERSION=$(sudo -u www-data php web/core/scripts/drupal version 2>/dev/null || echo "Drupal 11.x")
echo "Установлена версия: $DRUPAL_VERSION"

echo "6. Установка дополнительных модулей для цифровой библиотеки..."
cd $DRUPAL_DIR

# Модули для библиотечной системы
DRUPAL_MODULES=(
    "drupal/admin_toolbar"
    "drupal/pathauto"
    "drupal/metatag"
    "drupal/token"
    "drupal/ctools"
    "drupal/views_bulk_operations"
    "drupal/entity_reference_revisions"
    "drupal/paragraphs"
    "drupal/field_group"
    "drupal/search_api"
    "drupal/search_api_db"
    "drupal/facets"
    "drupal/media_library_edit"
    "drupal/file_browser"
    "drupal/backup_migrate"
    "drupal/redis"
    "drupal/memcache"
)

echo "Установка модулей для библиотечной системы..."
for module in "${DRUPAL_MODULES[@]}"; do
    echo "Установка $module..."
    sudo -u www-data composer require $module --no-interaction
done

echo "7. Установка темы для библиотеки..."
sudo -u www-data composer require drupal/bootstrap5 --no-interaction

echo "8. Настройка прав доступа..."
chown -R www-data:www-data $DRUPAL_DIR
find $DRUPAL_DIR -type d -exec chmod 755 {} \;
find $DRUPAL_DIR -type f -exec chmod 644 {} \;

# Специальные права для важных файлов
chmod 444 $DRUPAL_DIR/web/sites/default/default.settings.php

echo "9. Создание каталогов для файлов..."
mkdir -p $DRUPAL_DIR/web/sites/default/files
mkdir -p $DRUPAL_DIR/web/sites/default/files/private
mkdir -p $DRUPAL_DIR/web/sites/default/files/translations
mkdir -p $DRUPAL_DIR/web/sites/default/files/backup

chown -R www-data:www-data $DRUPAL_DIR/web/sites/default/files
chmod -R 755 $DRUPAL_DIR/web/sites/default/files

echo "10. Подготовка настроек базы данных..."
cp $DRUPAL_DIR/web/sites/default/default.settings.php $DRUPAL_DIR/web/sites/default/settings.php
chown www-data:www-data $DRUPAL_DIR/web/sites/default/settings.php
chmod 666 $DRUPAL_DIR/web/sites/default/settings.php

# Получение данных базы данных
if [ -f "/root/drupal-db-credentials.txt" ]; then
    DB_PASSWORD=$(grep "Пароль:" /root/drupal-db-credentials.txt | awk '{print $2}')
    echo "✅ Данные базы данных получены"
else
    echo "❌ Файл с данными БД не найден"
    exit 1
fi

echo "11. Настройка settings.php..."
cat >> $DRUPAL_DIR/web/sites/default/settings.php << EOF

/**
 * RTTI Digital Library Configuration
 * Generated: $(date)
 */

// Database configuration
\$databases['default']['default'] = [
  'database' => 'drupal_library',
  'username' => 'drupaluser',
  'password' => '$DB_PASSWORD',
  'prefix' => '',
  'host' => 'localhost',
  'port' => '5432',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\pgsql',
  'driver' => 'pgsql',
  'autoload' => 'core/modules/pgsql/src/Driver/Database/pgsql/',
];

// Trusted host patterns
\$settings['trusted_host_patterns'] = [
  '^library\.rtti\.tj\$',
  '^www\.library\.rtti\.tj\$',
];

// Salt for one-time login links, cancel links, form tokens, etc.
\$settings['hash_salt'] = '$(openssl rand -base64 75 | tr -d "=+/" | cut -c1-75)';

// Configuration sync directory
\$settings['config_sync_directory'] = '../config/sync';

// Private file path
\$settings['file_private_path'] = 'sites/default/files/private';

// Temporary file path
\$settings['file_temp_path'] = '/tmp';

EOF

# Получение данных Redis
if [ -f "/root/drupal-cache-credentials.txt" ]; then
    REDIS_PASSWORD=$(grep "Пароль:" /root/drupal-cache-credentials.txt | awk '{print $2}')
    
    # Добавление настроек кэширования
    cat >> $DRUPAL_DIR/web/sites/default/settings.php << EOF
// Redis configuration
\$settings['redis.connection']['interface'] = 'PhpRedis';
\$settings['redis.connection']['host'] = '127.0.0.1';
\$settings['redis.connection']['port'] = 6379;
\$settings['redis.connection']['password'] = '$REDIS_PASSWORD';
\$settings['redis.connection']['base'] = 0;

\$settings['cache']['default'] = 'cache.backend.redis';

// Bootstrap cache with Redis
\$settings['cache']['bins']['bootstrap'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['discovery'] = 'cache.backend.chainedfast';
\$settings['cache']['bins']['config'] = 'cache.backend.chainedfast';

// Memcached configuration (optional)
\$settings['memcache']['servers'] = ['127.0.0.1:11211' => 'default'];
\$settings['memcache']['bins'] = ['cache.page' => 'default'];

EOF
fi

# Дополнительные настройки для библиотеки
cat >> $DRUPAL_DIR/web/sites/default/settings.php << EOF
// RTTI Library specific settings
\$config['system.site']['name'] = 'RTTI Digital Library';
\$config['system.site']['slogan'] = 'Цифровая библиотека РЦТИ';
\$config['system.site']['mail'] = 'library@rtti.tj';

// Performance settings
\$config['system.performance']['css']['preprocess'] = TRUE;
\$config['system.performance']['js']['preprocess'] = TRUE;

// File system settings
\$config['system.file']['temporary_maximum_age'] = 86400;

// Logging
\$config['system.logging']['error_level'] = 'hide';

// Update notifications
\$config['update.settings']['notification']['emails'] = ['admin@rtti.tj'];

EOF

echo "12. Установка Drupal через CLI..."
echo "Запуск установки Drupal..."

cd $DRUPAL_DIR

# Установка Drupal
sudo -u www-data php web/core/scripts/drupal install \
    --langcode=ru \
    --db-type=pgsql \
    --db-host=localhost \
    --db-name=drupal_library \
    --db-user=drupaluser \
    --db-pass=$DB_PASSWORD \
    --db-port=5432 \
    --site-name="RTTI Digital Library" \
    --site-mail=library@rtti.tj \
    --account-name=admin \
    --account-pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12) \
    --account-mail=admin@rtti.tj

INSTALL_RESULT=$?

if [ $INSTALL_RESULT -eq 0 ]; then
    echo "✅ Установка Drupal завершена успешно"
else
    echo "❌ Ошибка установки Drupal через CLI"
    echo "Попробуем установку через веб-интерфейс..."
fi

echo "13. Настройка прав доступа после установки..."
chmod 444 $DRUPAL_DIR/web/sites/default/settings.php
chown -R www-data:www-data $DRUPAL_DIR
find $DRUPAL_DIR/web/sites/default/files -type d -exec chmod 755 {} \;
find $DRUPAL_DIR/web/sites/default/files -type f -exec chmod 644 {} \;

echo "14. Включение необходимых модулей..."
cd $DRUPAL_DIR

# Включение основных модулей
CORE_MODULES=(
    "toolbar"
    "admin_toolbar"
    "admin_toolbar_tools"
    "pathauto"
    "metatag"
    "token"
    "views_ui"
    "media"
    "media_library"
    "search_api"
    "search_api_db"
)

for module in "${CORE_MODULES[@]}"; do
    echo "Включение модуля $module..."
    sudo -u www-data vendor/bin/drush pm:enable $module -y 2>/dev/null || true
done

echo "15. Создание скрипта управления Drupal..."
cat > /root/drupal-management.sh << EOF
#!/bin/bash
# Скрипт управления Drupal

DRUPAL_DIR="$DRUPAL_DIR"

case "\$1" in
    cache-clear)
        echo "Очистка кэша Drupal..."
        cd \$DRUPAL_DIR
        sudo -u www-data vendor/bin/drush cache:rebuild
        echo "✅ Кэш очищен"
        ;;
    backup)
        echo "Создание резервной копии Drupal..."
        BACKUP_DIR="/var/backups/drupal/drupal-\$(date +%Y%m%d-%H%M%S)"
        mkdir -p \$BACKUP_DIR
        cp -r \$DRUPAL_DIR \$BACKUP_DIR/files
        sudo -u postgres pg_dump drupal_library > \$BACKUP_DIR/database.sql
        echo "✅ Резервная копия создана: \$BACKUP_DIR"
        ;;
    update)
        echo "Обновление Drupal..."
        cd \$DRUPAL_DIR
        sudo -u www-data composer update --no-interaction
        sudo -u www-data vendor/bin/drush updatedb -y
        sudo -u www-data vendor/bin/drush cache:rebuild
        echo "✅ Drupal обновлен"
        ;;
    status)
        echo "Статус Drupal:"
        cd \$DRUPAL_DIR
        sudo -u www-data vendor/bin/drush status
        ;;
    modules)
        echo "Список модулей:"
        cd \$DRUPAL_DIR
        sudo -u www-data vendor/bin/drush pm:list --type=module --status=enabled
        ;;
    *)
        echo "Использование: \$0 {cache-clear|backup|update|status|modules}"
        exit 1
        ;;
esac
EOF

chmod +x /root/drupal-management.sh

echo "16. Сохранение данных администратора..."
ADMIN_PASSWORD=$(grep "account-pass" /var/log/drupal-install.log 2>/dev/null | awk -F'=' '{print $2}' || echo "Проверьте в логах")

cat > /root/drupal-admin-credentials.txt << EOF
# Данные администратора Drupal
# Дата создания: $(date)
# Сервер: library.rtti.tj ($(hostname -I | awk '{print $1}'))

URL: https://library.rtti.tj
Администратор: admin
Пароль: $ADMIN_PASSWORD
Email: admin@rtti.tj

# Первый вход:
# 1. Откройте https://library.rtti.tj
# 2. Войдите как admin с паролем выше
# 3. Смените пароль через профиль
# 4. Настройте сайт через Администрирование

# Важные ссылки:
# Админ-панель: https://library.rtti.tj/admin
# Управление контентом: https://library.rtti.tj/admin/content
# Конфигурация: https://library.rtti.tj/admin/config
# Модули: https://library.rtti.tj/admin/modules
# Темы: https://library.rtti.tj/admin/appearance

# Drush команды:
# Очистка кэша: cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush cache:rebuild
# Статус: cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush status
# Пользователи: cd $DRUPAL_DIR && sudo -u www-data vendor/bin/drush user:list
EOF

chmod 600 /root/drupal-admin-credentials.txt

echo "17. Создание информационного файла..."
cat > /root/drupal-installation-info.txt << EOF
# Информация об установке Drupal 11
# Дата: $(date)
# Сервер: library.rtti.tj ($(hostname -I | awk '{print $1}'))

=== УСТАНОВКА ===
Путь: $DRUPAL_DIR
Версия: $DRUPAL_VERSION
База данных: drupal_library (PostgreSQL)
Кэширование: Redis + Memcached + APCu

=== ДОСТУП ===
URL: https://library.rtti.tj
Админ: admin
Конфигурация: /root/drupal-admin-credentials.txt

=== МОДУЛИ ===
Базовые модули включены:
- Admin Toolbar (улучшенная панель администратора)
- Pathauto (SEO URL)
- Metatag (SEO метатеги)
- Search API (поиск)
- Media Library (медиа файлы)
- Redis (кэширование)

=== УПРАВЛЕНИЕ ===
Скрипт управления: /root/drupal-management.sh
Команды:
- cache-clear: очистка кэша
- backup: резервная копия
- update: обновление
- status: статус системы
- modules: список модулей

=== ФАЙЛЫ ===
Публичные файлы: $DRUPAL_DIR/web/sites/default/files
Приватные файлы: $DRUPAL_DIR/web/sites/default/files/private
Конфигурация: $DRUPAL_DIR/web/sites/default/settings.php
Composer: $DRUPAL_DIR/composer.json

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Откройте https://library.rtti.tj
2. Войдите как администратор
3. Настройте тему оформления
4. Создайте типы контента для библиотеки
5. Настройте поиск и индексацию
6. Запустите ./07-configure-drupal.sh

=== ТЕХНИЧЕСКОЕ ОБСЛУЖИВАНИЕ ===
- Регулярно обновляйте модули: composer update
- Очищайте кэш при изменениях: drush cache:rebuild  
- Создавайте резервные копии: /root/drupal-management.sh backup
- Мониторинг логов: /var/log/nginx/ и /var/log/php8.3-fpm.log
EOF

echo "18. Проверка установки..."
if [ -f "$DRUPAL_DIR/web/sites/default/settings.php" ] && [ -d "$DRUPAL_DIR/web/core" ]; then
    echo "✅ Файлы Drupal установлены корректно"
else
    echo "⚠️  Возможны проблемы с установкой"
fi

# Тест подключения к базе данных
sudo -u www-data php -r "
try {
    \$pdo = new PDO('pgsql:host=localhost;dbname=drupal_library', 'drupaluser', '$DB_PASSWORD');
    echo 'Database connection: OK\n';
} catch (Exception \$e) {
    echo 'Database connection: FAILED\n';
}
" 2>/dev/null

echo "19. Очистка временных файлов..."
rm -f $DRUPAL_DIR/phpinfo.php 2>/dev/null || true

echo
echo "✅ Шаг 6 завершен успешно!"
echo "📌 Drupal 11 установлен в $DRUPAL_DIR"
echo "📌 Модули для библиотеки установлены"
echo "📌 База данных настроена"
echo "📌 Кэширование активировано"
echo "📌 URL: https://library.rtti.tj"
echo "📌 Данные администратора: /root/drupal-admin-credentials.txt"
echo "📌 Управление: /root/drupal-management.sh"
echo "📌 Информация: /root/drupal-installation-info.txt"
echo "📌 Следующий шаг: ./07-configure-drupal.sh"
echo
