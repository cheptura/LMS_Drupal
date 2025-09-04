#!/bin/bash

# RTTI Drupal - Шаг 3: Установка базы данных
# Сервер: library.rtti.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 3: Установка PostgreSQL для Drupal 11 ==="
echo "🗄️ PostgreSQL 16 - база данных для цифровой библиотеки"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Установка PostgreSQL 16..."
apt install -y postgresql postgresql-contrib postgresql-client

echo "2. Запуск и включение автозапуска PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

echo "3. Проверка версии PostgreSQL..."
sudo -u postgres psql -c "SELECT version();"

echo "4. Настройка аутентификации PostgreSQL..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT setting FROM pg_settings WHERE name='server_version_num';" | xargs | cut -c1-2)
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"

# Backup оригинальных файлов
cp $PG_HBA ${PG_HBA}.backup
cp $PG_CONF ${PG_CONF}.backup

echo "5. Настройка подключений PostgreSQL..."
# Разрешаем локальные подключения
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" $PG_CONF

# Настройка аутентификации для локальных подключений
sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' $PG_HBA
sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' $PG_HBA
sed -i 's/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/' $PG_HBA

echo "6. Оптимизация PostgreSQL для Drupal..."
# Настройки производительности для Drupal
cat >> $PG_CONF << 'EOF'

# Drupal 11 optimizations
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200

# Drupal specific settings
max_connections = 200
work_mem = 8MB
temp_buffers = 32MB

# Logging for Drupal debugging
log_statement = 'ddl'
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
EOF

echo "7. Генерация безопасного пароля для пользователя базы данных..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo "8. Перезапуск PostgreSQL для применения настроек..."
systemctl restart postgresql

echo "9. Ожидание запуска PostgreSQL..."
sleep 5

echo "10. Создание пользователя базы данных drupaluser..."
sudo -u postgres psql << EOF
-- Создание пользователя для Drupal
CREATE USER drupaluser WITH PASSWORD '$DB_PASSWORD';

-- Предоставление необходимых прав
ALTER USER drupaluser CREATEDB;

-- Проверка создания пользователя
\du drupaluser
EOF

if [ $? -ne 0 ]; then
    echo "❌ Ошибка создания пользователя базы данных"
    exit 1
fi

echo "11. Создание базы данных drupal_library..."
sudo -u postgres psql << EOF
-- Создание базы данных для цифровой библиотеки
CREATE DATABASE drupal_library 
    WITH OWNER = drupaluser
    ENCODING = 'UTF8'
    LC_COLLATE = 'ru_RU.UTF-8'
    LC_CTYPE = 'ru_RU.UTF-8'
    TEMPLATE = template0;

-- Предоставление всех прав пользователю
GRANT ALL PRIVILEGES ON DATABASE drupal_library TO drupaluser;

-- Подключение к базе данных для настройки схемы
\c drupal_library

-- Предоставление прав на схему public
GRANT ALL ON SCHEMA public TO drupaluser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO drupaluser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO drupaluser;

-- Установка прав по умолчанию для будущих объектов
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO drupaluser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO drupaluser;

-- Проверка создания базы данных
\l drupal_library
EOF

if [ $? -ne 0 ]; then
    echo "❌ Ошибка создания базы данных"
    exit 1
fi

echo "12. Проверка подключения к базе данных..."
PGPASSWORD=$DB_PASSWORD psql -h localhost -U drupaluser -d drupal_library -c "SELECT version();"

if [ $? -eq 0 ]; then
    echo "✅ Подключение к базе данных успешно"
else
    echo "❌ Ошибка подключения к базе данных"
    exit 1
fi

echo "13. Установка дополнительных расширений PostgreSQL для Drupal..."
sudo -u postgres psql -d drupal_library << EOF
-- Расширения для улучшения производительности Drupal
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Проверка установленных расширений
\dx
EOF

echo "14. Создание резервной копии схемы базы данных..."
mkdir -p /var/backups/drupal
sudo -u postgres pg_dump drupal_library > /var/backups/drupal/initial_schema.sql
chown root:root /var/backups/drupal/initial_schema.sql
chmod 600 /var/backups/drupal/initial_schema.sql

echo "15. Сохранение данных подключения к базе данных..."
cat > /root/drupal-db-credentials.txt << EOF
# Данные подключения к базе данных Drupal
# Дата создания: $(date)
# Сервер: library.rtti.tj ($(hostname -I | awk '{print $1}'))

Хост: localhost
База данных: drupal_library
Пользователь: drupaluser
Пароль: $DB_PASSWORD

# Команда для подключения:
# PGPASSWORD='$DB_PASSWORD' psql -h localhost -U drupaluser -d drupal_library

# Настройки для Drupal settings.php:
# \$databases['default']['default'] = [
#   'database' => 'drupal_library',
#   'username' => 'drupaluser',
#   'password' => '$DB_PASSWORD',
#   'prefix' => '',
#   'host' => 'localhost',
#   'port' => '5432',
#   'namespace' => 'Drupal\\Core\\Database\\Driver\\pgsql',
#   'driver' => 'pgsql',
# ];

# Для восстановления доступа:
# sudo -u postgres psql -c "ALTER USER drupaluser WITH PASSWORD '$DB_PASSWORD';"
EOF

chmod 600 /root/drupal-db-credentials.txt

echo "16. Создание скрипта мониторинга базы данных..."
cat > /root/drupal-db-monitor.sh << EOF
#!/bin/bash
echo "=== Drupal Database Monitor ==="
echo "Время: \$(date)"
echo

echo "1. Статус PostgreSQL:"
systemctl status postgresql --no-pager -l | head -3

echo -e "\n2. Активные подключения:"
sudo -u postgres psql -d drupal_library -c "SELECT count(*) as connections FROM pg_stat_activity WHERE datname='drupal_library';" 2>/dev/null

echo -e "\n3. Размер базы данных:"
sudo -u postgres psql -d drupal_library -c "SELECT pg_size_pretty(pg_database_size('drupal_library')) as size;" 2>/dev/null

echo -e "\n4. Количество таблиц:"
PGPASSWORD='$DB_PASSWORD' psql -h localhost -U drupaluser -d drupal_library -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null

echo -e "\n5. Статистика использования:"
sudo -u postgres psql -d drupal_library -c "SELECT schemaname,tablename,n_tup_ins,n_tup_upd,n_tup_del FROM pg_stat_user_tables ORDER BY n_tup_ins DESC LIMIT 5;" 2>/dev/null

echo -e "\n6. Последние запросы (если включено логирование):"
tail -5 /var/log/postgresql/postgresql-$PG_VERSION-main.log 2>/dev/null || echo "Логирование отключено"
EOF

chmod +x /root/drupal-db-monitor.sh

echo "17. Создание скрипта резервного копирования..."
cat > /root/drupal-db-backup.sh << EOF
#!/bin/bash
# Скрипт резервного копирования базы данных Drupal

BACKUP_DIR="/var/backups/drupal"
DATE=\$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="drupal_library_backup_\$DATE.sql"

echo "=== Drupal Database Backup ==="
echo "Дата: \$(date)"

# Создание каталога если не существует
mkdir -p \$BACKUP_DIR

echo "Создание резервной копии базы данных..."
sudo -u postgres pg_dump drupal_library > \$BACKUP_DIR/\$BACKUP_FILE

if [ \$? -eq 0 ]; then
    echo "✅ Резервная копия создана: \$BACKUP_DIR/\$BACKUP_FILE"
    
    # Сжатие резервной копии
    gzip \$BACKUP_DIR/\$BACKUP_FILE
    echo "✅ Резервная копия сжата: \$BACKUP_DIR/\$BACKUP_FILE.gz"
    
    # Удаление старых резервных копий (старше 7 дней)
    find \$BACKUP_DIR -name "drupal_library_backup_*.sql.gz" -mtime +7 -delete
    echo "🗑️ Старые резервные копии удалены"
    
    # Информация о размере
    SIZE=\$(du -h \$BACKUP_DIR/\$BACKUP_FILE.gz | cut -f1)
    echo "📊 Размер резервной копии: \$SIZE"
else
    echo "❌ Ошибка создания резервной копии"
    exit 1
fi
EOF

chmod +x /root/drupal-db-backup.sh

echo "18. Настройка автоматического резервного копирования..."
cat > /etc/cron.d/drupal-backup << 'EOF'
# Автоматическое резервное копирование базы данных Drupal
# Каждый день в 3:00
0 3 * * * root /root/drupal-db-backup.sh >/dev/null 2>&1
EOF

echo "19. Проверка статуса PostgreSQL..."
systemctl status postgresql --no-pager -l

echo "20. Создание информационного файла о базе данных..."
cat > /root/drupal-database-info.txt << EOF
# Информация о базе данных Drupal
# Дата создания: $(date)
# Сервер: library.rtti.tj ($(hostname -I | awk '{print $1}'))

=== ПАРАМЕТРЫ БАЗЫ ДАННЫХ ===
СУБД: PostgreSQL $(sudo -u postgres psql -t -c "SELECT version();" | head -1 | awk '{print $2}')
База данных: drupal_library
Пользователь: drupaluser
Кодировка: UTF8
Локаль: ru_RU.UTF-8

=== РАСШИРЕНИЯ ===
$(sudo -u postgres psql -d drupal_library -t -c "\dx" | grep -v "^$" | head -5)

=== НАСТРОЙКИ ПРОИЗВОДИТЕЛЬНОСТИ ===
shared_buffers: 256MB
effective_cache_size: 1GB
max_connections: 200
work_mem: 8MB

=== ФАЙЛЫ КОНФИГУРАЦИИ ===
PostgreSQL config: $PG_CONF
Authentication: $PG_HBA
Резервные копии: /var/backups/drupal/

=== СКРИПТЫ УПРАВЛЕНИЯ ===
Мониторинг: /root/drupal-db-monitor.sh
Резервное копирование: /root/drupal-db-backup.sh
Данные подключения: /root/drupal-db-credentials.txt

=== КОМАНДЫ ===
Подключение: PGPASSWORD='пароль' psql -h localhost -U drupaluser -d drupal_library
Резервная копия: sudo -u postgres pg_dump drupal_library > backup.sql
Восстановление: sudo -u postgres psql drupal_library < backup.sql
Мониторинг: sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

=== АВТОМАТИЗАЦИЯ ===
✅ Автоматическое резервное копирование (ежедневно в 3:00)
✅ Очистка старых резервных копий (>7 дней)
✅ Мониторинг производительности

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Запустите: ./04-install-cache.sh
2. Проверьте подключение: /root/drupal-db-monitor.sh
3. Тест резервного копирования: /root/drupal-db-backup.sh
EOF

echo
echo "✅ Шаг 3 завершен успешно!"
echo "📌 PostgreSQL 16 установлен и настроен"
echo "📌 База данных 'drupal_library' создана"
echo "📌 Пользователь 'drupaluser' создан"
echo "📌 Расширения PostgreSQL установлены"
echo "📌 Автоматическое резервное копирование настроено"
echo "📌 Данные подключения: /root/drupal-db-credentials.txt"
echo "📌 Мониторинг: /root/drupal-db-monitor.sh"
echo "📌 Информация: /root/drupal-database-info.txt"
echo "📌 Следующий шаг: ./04-install-cache.sh"
echo
