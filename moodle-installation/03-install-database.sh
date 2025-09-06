#!/bin/bash

# RTTI Moodle - Шаг 3: Установка базы данных
# Сервер: omuzgorpro.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 3: Установка PostgreSQL ==="
echo "🗄️ PostgreSQL 16 для Moodle"
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

echo "5. Настройка подключений..."
# Разрешаем локальные подключения
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" $PG_CONF

# Настройка аутентификации для локальных подключений
sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' $PG_HBA
sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' $PG_HBA
sed -i 's/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/' $PG_HBA

echo "6. Оптимизация PostgreSQL для Moodle..."
# Настройки производительности
cat >> $PG_CONF << 'EOF'

# Moodle optimizations
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
EOF

echo "7. Генерация безопасного пароля для пользователя базы данных..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo "8. Перезапуск PostgreSQL для применения настроек..."
systemctl restart postgresql

echo "9. Ожидание запуска PostgreSQL..."
sleep 5

echo "10. Создание пользователя базы данных moodleuser..."
sudo -u postgres psql << EOF
-- Создание пользователя
CREATE USER moodleuser WITH PASSWORD '$DB_PASSWORD';

-- Предоставление необходимых прав
ALTER USER moodleuser CREATEDB;

-- Проверка создания пользователя
\du moodleuser
EOF

if [ $? -ne 0 ]; then
    echo "❌ Ошибка создания пользователя базы данных"
    exit 1
fi

echo "11. Создание базы данных moodle..."
sudo -u postgres psql << EOF
-- Создание базы данных
CREATE DATABASE moodle 
    WITH OWNER = moodleuser
    ENCODING = 'UTF8'
    LC_COLLATE = 'ru_RU.UTF-8'
    LC_CTYPE = 'ru_RU.UTF-8'
    TEMPLATE = template0;

-- Предоставление всех прав пользователю
GRANT ALL PRIVILEGES ON DATABASE moodle TO moodleuser;

-- Настройка часового пояса для базы данных
\c moodle
SET timezone = 'Asia/Dushanbe';
ALTER DATABASE moodle SET timezone = 'Asia/Dushanbe';

-- Проверка создания базы данных
\l moodle
EOF

if [ $? -ne 0 ]; then
    echo "❌ Ошибка создания базы данных"
    exit 1
fi

echo "12. Проверка подключения к базе данных..."
PGPASSWORD=$DB_PASSWORD psql -h localhost -U moodleuser -d moodle -c "SELECT version();"

if [ $? -eq 0 ]; then
    echo "✅ Подключение к базе данных успешно"
else
    echo "❌ Ошибка подключения к базе данных"
    exit 1
fi

echo "13. Сохранение данных подключения к базе данных..."
cat > /root/moodle-db-credentials.txt << EOF
# Данные подключения к базе данных Moodle
# Дата создания: $(date)
# Сервер: omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

Хост: localhost
База данных: moodle
Пользователь: moodleuser
Пароль: $DB_PASSWORD

# Команда для подключения:
# PGPASSWORD='$DB_PASSWORD' psql -h localhost -U moodleuser -d moodle

# Для восстановления доступа:
# sudo -u postgres psql -c "ALTER USER moodleuser WITH PASSWORD '$DB_PASSWORD';"
EOF

chmod 600 /root/moodle-db-credentials.txt

echo "14. Создание каталога для данных Moodle..."
mkdir -p /var/moodledata
chown -R www-data:www-data /var/moodledata
chmod -R 755 /var/moodledata

echo "15. Проверка статуса PostgreSQL..."
systemctl status postgresql --no-pager -l

echo
echo "✅ Шаг 3 завершен успешно!"
echo "📌 PostgreSQL 16 установлен и настроен"
echo "📌 База данных 'moodle' создана"
echo "📌 Пользователь 'moodleuser' создан"
echo "📌 Данные подключения: /root/moodle-db-credentials.txt"
echo "📌 Следующий шаг: ./04-install-cache.sh"
echo
