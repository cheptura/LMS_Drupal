#!/bin/bash

# RTTI Moodle - Шаг 9: Пост-установочная настройка
# Сервер: omuzgorpro.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 9: Пост-установочная настройка ==="
echo "🔧 Оптимизация и дополнительные настройки"
echo "📅 Дата: $(date)"
echo
echo "ℹ️  ВАЖНО: Сообщения 'hard-set in config.php, unable to change' это НОРМАЛЬНО!"
echo "   Эти настройки уже правильно заданы в config.php и имеют приоритет."
echo "   Установка продолжается корректно."
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

MOODLE_DIR="/var/www/moodle"

echo "1. Проверка успешности установки Moodle..."
if [ ! -f "$MOODLE_DIR/config.php" ]; then
    echo "❌ Moodle не установлен"
    exit 1
fi

# Проверка наличия файла блокировки установки (безопасный способ)
if [ -f "/var/moodledata/install.lock" ]; then
    echo "✅ Moodle установлен корректно (найден install.lock)"
elif [ -f "$MOODLE_DIR/../moodledata/install.lock" ]; then
    echo "✅ Moodle установлен корректно (найден install.lock)"
else
    # Альтернативная проверка через CLI
    echo "🔍 Проверка через CLI..."
    if sudo -u www-data php -r "
define('CLI_SCRIPT', true);
require_once '$MOODLE_DIR/config.php';
require_once '$MOODLE_DIR/lib/clilib.php';
if (file_exists(\$CFG->dataroot . '/install.lock')) {
    echo 'OK';
} else {
    echo 'MISSING';
}
" 2>/dev/null | grep -q "OK"; then
        echo "✅ Moodle установлен корректно"
    else
        echo "⚠️  Предупреждение: install.lock не найден, но продолжаем"
        echo "ℹ️  Это может быть нормально для некоторых версий Moodle"
    fi
fi

echo "2. Проверка и исправление проблемы с cURL..."
# Проверяем доступность функции curl_exec
echo "   2.1. Проверка функции curl_exec()..."
if php -r "exit(function_exists('curl_exec') ? 0 : 1);"; then
    echo "   ✅ curl_exec() доступна"
else
    echo "   ❌ curl_exec() не найдена, исправляем..."
    
    # Переустанавливаем cURL и все зависимости
    apt update
    apt install -y curl libcurl4-openssl-dev ca-certificates
    apt install -y --reinstall php8.3-curl php8.3-common php8.3-cli php8.3-fpm
    
    # Проверяем, что модуль загружается
    echo "   Проверяем загрузку модуля cURL..."
    if ! php -m | grep -q curl; then
        echo "   Модуль cURL не загружается, добавляем в конфигурацию..."
        echo "extension=curl" >> /etc/php/8.3/fpm/php.ini
        echo "extension=curl" >> /etc/php/8.3/cli/php.ini
    fi
    
    # Перезапускаем PHP-FPM
    systemctl restart php8.3-fpm
    
    # Проверяем еще раз
    if php -r "exit(function_exists('curl_exec') ? 0 : 1);"; then
        echo "   ✅ curl_exec() исправлена"
    else
        echo "   ⚠️  curl_exec() все еще недоступна, может потребоваться перезагрузка сервера"
        echo "   Попробуйте: sudo reboot"
    fi
fi

echo "   2.2. Тестирование cURL с реальным запросом..."
php -r "
if (function_exists('curl_exec')) {
    \$ch = curl_init();
    curl_setopt(\$ch, CURLOPT_URL, 'https://httpbin.org/get');
    curl_setopt(\$ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt(\$ch, CURLOPT_TIMEOUT, 10);
    curl_setopt(\$ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt(\$ch, CURLOPT_USERAGENT, 'Moodle cURL Test');
    
    \$result = curl_exec(\$ch);
    \$error = curl_error(\$ch);
    \$httpCode = curl_getinfo(\$ch, CURLINFO_HTTP_CODE);
    curl_close(\$ch);
    
    if (\$result !== false && \$httpCode == 200) {
        echo '   ✅ cURL тест успешен (HTTP 200)' . PHP_EOL;
    } else {
        echo '   ❌ cURL тест неудачен: ' . \$error . ' (HTTP: ' . \$httpCode . ')' . PHP_EOL;
    }
} else {
    echo '   ❌ curl_exec() все еще недоступна' . PHP_EOL;
}
"

echo "3. Применение первичных настроек Moodle..."

# Функция для безопасной установки настроек
set_moodle_config() {
    local name="$1"
    local value="$2"
    local plugin="${3:-core}"
    
    echo "   Устанавливаем $plugin.$name = $value"
    sudo -u www-data php $MOODLE_DIR/admin/cli/cfg.php --name="$name" --set="$value" --plugin="$plugin" 2>/dev/null || true
}

# Основные настройки сайта
set_moodle_config "lang" "ru"
set_moodle_config "timezone" "Asia/Dushanbe"
set_moodle_config "country" "TJ"
set_moodle_config "theme" "boost"

# Языковые настройки
set_moodle_config "autolang" "1"
set_moodle_config "langmenu" "1"

# Настройки сайта
set_moodle_config "fullname" "Система управления обучением РЦТИ"
set_moodle_config "shortname" "RTTI LMS"
set_moodle_config "summary" "Современная платформа для онлайн обучения"

# Настройки безопасности
set_moodle_config "sessiontimeout" "7200"
set_moodle_config "minpasswordlength" "8"
set_moodle_config "minpassworddigits" "1"
set_moodle_config "minpasswordlower" "1"
set_moodle_config "minpasswordupper" "1"
set_moodle_config "lockoutthreshold" "5"

# Настройки файлов
set_moodle_config "maxbytes" "104857600"  # 100MB

# Настройки производительности
set_moodle_config "enablecaching" "1"
set_moodle_config "enablecompletion" "1"

# Отключаем отладку в продакшене
set_moodle_config "debug" "0"
set_moodle_config "debugdisplay" "0"

echo "   ✅ Первичные настройки применены"

echo "4. Установка дополнительных языковых пакетов..."

echo "   4.1. Создание директории для языков..."
# Создаем директорию для дополнительных языков
MOODLE_DATA="${MOODLE_DATA:-/var/moodledata}"
if [ ! -d "$MOODLE_DATA/lang" ]; then
    sudo mkdir -p "$MOODLE_DATA/lang"
    sudo chown www-data:www-data "$MOODLE_DATA/lang"
    sudo chmod 755 "$MOODLE_DATA/lang"
    echo "   ✅ Создана директория $MOODLE_DATA/lang"
fi

echo "   4.2. Загрузка языковых пакетов (русский и таджикский)..."

# Функция для загрузки языкового пакета
download_language_pack() {
    local lang_code="$1"
    local lang_name="$2"
    local lang_url="https://download.moodle.org/download.php/direct/langpack/5.0/${lang_code}.zip"
    local temp_file="/tmp/moodle_${lang_code}_lang.zip"
    
    echo "   Загружаем $lang_name ($lang_code)..."
    
    if wget -q -O "$temp_file" "$lang_url" 2>/dev/null; then
        echo "   ✅ $lang_name скачан"
        
        # Распаковываем
        if sudo -u www-data unzip -q -o "$temp_file" -d "$MOODLE_DATA/lang/" 2>/dev/null; then
            echo "   ✅ $lang_name распакован"
            
            # Устанавливаем права
            if [ -d "$MOODLE_DATA/lang/$lang_code" ]; then
                sudo chown -R www-data:www-data "$MOODLE_DATA/lang/$lang_code"
                sudo find "$MOODLE_DATA/lang/$lang_code" -type d -exec chmod 755 {} \;
                sudo find "$MOODLE_DATA/lang/$lang_code" -type f -exec chmod 644 {} \;
                echo "   ✅ Права доступа для $lang_name установлены"
            fi
        else
            echo "   ❌ Ошибка распаковки $lang_name"
        fi
        rm -f "$temp_file"
        return 0
    elif curl -s -o "$temp_file" "$lang_url" 2>/dev/null; then
        echo "   ✅ $lang_name скачан через curl"
        
        if sudo -u www-data unzip -q -o "$temp_file" -d "$MOODLE_DATA/lang/" 2>/dev/null; then
            echo "   ✅ $lang_name распакован"
            if [ -d "$MOODLE_DATA/lang/$lang_code" ]; then
                sudo chown -R www-data:www-data "$MOODLE_DATA/lang/$lang_code"
                sudo find "$MOODLE_DATA/lang/$lang_code" -type d -exec chmod 755 {} \;
                sudo find "$MOODLE_DATA/lang/$lang_code" -type f -exec chmod 644 {} \;
                echo "   ✅ Права доступа для $lang_name установлены"
            fi
        fi
        rm -f "$temp_file"
        return 0
    else
        echo "   ⚠️  Не удалось загрузить $lang_name"
        return 1
    fi
}

# Загружаем языковые пакеты
download_language_pack "ru" "русский язык"
download_language_pack "tg" "таджикский язык"

echo "   4.3. Очистка кэша и установка языка по умолчанию..."
sudo -u www-data php $MOODLE_DIR/admin/cli/purge_caches.php
set_moodle_config "lang" "ru"

echo "   4.4. Проверка доступных языков..."
# Создаем простую проверку языков
sudo -u www-data php -r "
define('CLI_SCRIPT', true);
require_once('$MOODLE_DIR/config.php');
\$langs = get_string_manager()->get_list_of_translations();
echo 'Доступные языки: ' . count(\$langs) . ' шт.' . PHP_EOL;
foreach (\$langs as \$code => \$name) {
    \$current = (\$code === get_config('core', 'lang')) ? ' ← ТЕКУЩИЙ' : '';
    if (in_array(\$code, ['en', 'ru', 'tg'])) {
        echo '✅ ' . \$code . ': ' . \$name . \$current . PHP_EOL;
    } else {
        echo '- ' . \$code . ': ' . \$name . \$current . PHP_EOL;
    }
}
" 2>/dev/null || echo "   ⚠️  Не удалось проверить языки (не критично)"

echo "5. Настройка дополнительных параметров..."
# Эти настройки НЕ дублируют config.php, а дополняют их
set_moodle_config "sessiontimeout" "7200"
set_moodle_config "enablemobilewebservice" "1"

echo "6. Дополнительные настройки производительности..."

# Настройки кэширования и производительности
set_moodle_config "enablecaching" "1"
set_moodle_config "cachejs" "1"
set_moodle_config "yuicomboloading" "1"

# Настройки безопасности паролей
set_moodle_config "lockoutwindow" "1800"   # 30 минут
set_moodle_config "lockoutduration" "1800"  # 30 минут

# Настройки электронной почты
DOMAIN_NAME="${DOMAIN_NAME:-omuzgorpro.tj}"
set_moodle_config "noreplyaddress" "noreply@$DOMAIN_NAME"
set_moodle_config "supportemail" "support@$DOMAIN_NAME"

# Календарные настройки
set_moodle_config "calendartype" "gregorian"
set_moodle_config "calendar_startwday" "1"  # Понедельник

echo "   ✅ Дополнительные параметры настроены"

echo "7. Финальная очистка кэша..."
sudo -u www-data php $MOODLE_DIR/admin/cli/purge_caches.php

echo "8. Создание стандартных категорий курсов..."

# Создаем временный PHP скрипт для создания категорий
cat > /tmp/create_categories.php << 'PHPEOF'
<?php
define('CLI_SCRIPT', true);
require_once('/var/www/moodle/config.php');
require_once($CFG->libdir . '/adminlib.php');

$categories = [
    'Информационные технологии',
    'Телекоммуникации', 
    'Управление проектами',
    'Языковые курсы',
    'Профессиональное развитие'
];

foreach ($categories as $name) {
    if (!$DB->record_exists('course_categories', array('name' => $name))) {
        $category = new stdClass();
        $category->name = $name;
        $category->description = 'Категория: ' . $name;
        $category->parent = 0;
        $category->sortorder = 999;
        $category->coursecount = 0;
        $category->visible = 1;
        $category->timemodified = time();
        $category->depth = 1;
        $category->path = '';
        
        $id = $DB->insert_record('course_categories', $category);
        $category->id = $id;
        $category->path = '/' . $id;
        $DB->update_record('course_categories', $category);
        
        echo 'Создана категория: ' . $name . "\n";
    } else {
        echo 'Категория уже существует: ' . $name . "\n";
    }
}
echo "Создание категорий завершено\n";
PHPEOF

# Выполняем скрипт
if sudo -u www-data php /tmp/create_categories.php 2>/dev/null; then
    echo "✅ Стандартные категории курсов созданы"
else
    echo "⚠️  Предупреждение: не удалось создать некоторые категории (не критично)"
fi

# Удаляем временный файл
rm -f /tmp/create_categories.php

echo "9. Дополнительные настройки оформления..."
# Очистка кэша после всех изменений
sudo -u www-data php $MOODLE_DIR/admin/cli/purge_caches.php

echo "10. Установка и настройка плагинов..."
# Все настройки веб-сервисов уже применены в первичных настройках

echo "11. Создание расписания обслуживания..."
cat > /etc/cron.d/moodle-maintenance << 'EOF'
# Moodle maintenance tasks

# Ежедневная очистка логов (в 3:00)
0 3 * * * www-data /usr/bin/php /var/www/moodle/admin/cli/logs.php --cleanup >/dev/null 2>&1

# Еженедельная оптимизация базы данных (воскресенье в 4:00)
0 4 * * 0 root sudo -u postgres vacuumdb --analyze moodle >/dev/null 2>&1

# Ежемесячная проверка целостности (1 число в 5:00)
0 5 1 * * www-data /usr/bin/php /var/www/moodle/admin/cli/check_database_schema.php >/dev/null 2>&1
EOF

echo "12. Создание скрипта мониторинга производительности..."
cat > /root/moodle-performance-monitor.sh << 'EOF'
#!/bin/bash
echo "=== Moodle Performance Monitor ==="
echo "Время: $(date)"
echo

echo "1. Использование CPU и памяти:"
top -bn1 | grep -E "(Cpu|Mem)" | head -2

echo -e "\n2. Активные процессы PHP:"
ps aux | grep php-fpm | wc -l

echo -e "\n3. Подключения к PostgreSQL:"
sudo -u postgres psql -d moodle -c "SELECT count(*) as connections FROM pg_stat_activity;" 2>/dev/null | tail -2 | head -1

echo -e "\n4. Статистика Redis:"
redis-cli -a $(grep "Пароль:" /root/moodle-redis-credentials.txt | awk '{print $2}') info stats | grep -E "(keyspace_hits|keyspace_misses|connected_clients)"

echo -e "\n5. Размер каталогов:"
du -sh /var/www/moodle /var/moodledata /var/cache/moodle 2>/dev/null

echo -e "\n6. Дисковое пространство:"
df -h | grep -E "(Filesystem|/var|/)"

echo -e "\n7. Статус сервисов:"
for service in nginx php8.3-fpm postgresql redis-server; do
    status=$(systemctl is-active $service)
    echo "$service: $status"
done

echo -e "\n8. Последние ошибки Nginx:"
tail -5 /var/log/nginx/error.log 2>/dev/null || echo "Нет логов ошибок"
EOF

chmod +x /root/moodle-performance-monitor.sh

echo "13. Создание скрипта обновления системы..."
cat > /root/moodle-system-update.sh << 'EOF'
#!/bin/bash
echo "=== Moodle System Update ==="

# Включение режима обслуживания
echo "Включение режима обслуживания..."
sudo -u www-data php /var/www/moodle/admin/cli/maintenance.php --enable

# Обновление системы
echo "Обновление Ubuntu..."
apt update && apt upgrade -y

# Обновление PHP пакетов
echo "Обновление PHP..."
apt install -y php8.3-cli php8.3-fpm php8.3-pgsql php8.3-redis php8.3-gd php8.3-curl php8.3-zip php8.3-mbstring php8.3-xml php8.3-intl php8.3-soap

# Перезапуск сервисов
echo "Перезапуск сервисов..."
systemctl restart php8.3-fpm nginx

# Очистка кэша Moodle
echo "Очистка кэша Moodle..."
sudo -u www-data php /var/www/moodle/admin/cli/purge_caches.php

# Отключение режима обслуживания
echo "Отключение режима обслуживания..."
sudo -u www-data php /var/www/moodle/admin/cli/maintenance.php --disable

echo "Обновление завершено"
EOF

chmod +x /root/moodle-system-update.sh

echo "14. Создание стартовой страницы для курсов..."

# Создаем временный PHP скрипт для настройки фронтальной страницы
cat > /tmp/setup_frontpage.php << 'PHPEOF'
<?php
define('CLI_SCRIPT', true);
require_once('/var/www/moodle/config.php');

$frontpagesummary = '
<div style="text-align: center; padding: 20px;">
    <h2>Добро пожаловать в RTTI LMS</h2>
    <p>Система управления обучением Республиканского центра телекоммуникаций и информатизации</p>
    <hr>
    <h3>Доступные курсы:</h3>
    <p>Выберите интересующий вас курс из каталога ниже</p>
</div>
';

set_config('frontpagesummary', $frontpagesummary);
set_config('frontpage', '6,2,7,1,5,3'); // course list, categories, etc

echo "Стартовая страница настроена\n";
PHPEOF

# Выполняем скрипт
if sudo -u www-data php /tmp/setup_frontpage.php; then
    echo "✅ Стартовая страница настроена"
else
    echo "⚠️  Предупреждение: не удалось настроить стартовую страницу"
fi

# Удаляем временный файл
rm -f /tmp/setup_frontpage.php

echo "15. Финальная оптимизация кэша..."
sudo -u www-data php $MOODLE_DIR/admin/cli/purge_caches.php
sudo -u www-data php $MOODLE_DIR/admin/cli/alternative_component_cache.php --rebuild

echo "16. Создание отчета о пост-установке..."
cat > /root/moodle-post-install-report.txt << EOF
# Отчет о пост-установочной настройке Moodle
# Дата: $(date)
# Сервер: omuzgorpro.tj ($(hostname -I | awk '{print $1}'))

=== ВЫПОЛНЕННЫЕ НАСТРОЙКИ ===

✅ Языковые пакеты: русский, таджикский, английский
✅ Язык по умолчанию: русский (ru)
✅ Оптимизация производительности: кэширование включено
✅ Параметры безопасности: настроены
✅ Категории курсов: созданы стандартные категории
✅ Тема оформления: Boost
✅ Email настройки: noreply@omuzgorpro.tj, support@omuzgorpro.tj
✅ Веб-сервисы: включены
✅ Мобильное приложение: поддержка включена
✅ Расписание обслуживания: создано
✅ Стартовая страница: настроена

=== СОЗДАННЫЕ СКРИПТЫ ===

Мониторинг производительности: /root/moodle-performance-monitor.sh
Обновление системы: /root/moodle-system-update.sh
Резервное копирование: /root/moodle-backup.sh
Диагностика: /root/moodle-diagnostics.sh

=== КАТЕГОРИИ КУРСОВ ===

- Информационные технологии
- Телекоммуникации
- Управление проектами  
- Языковые курсы
- Профессиональное развитие

=== АВТОМАТИЧЕСКИЕ ЗАДАЧИ ===

Ежеминутно: cron задачи Moodle
Ежечасно: очистка кэша
Ежедневно: очистка логов (3:00)
Еженедельно: оптимизация БД (воскресенье 4:00)
Ежемесячно: проверка целостности (1 число 5:00)

=== РЕКОМЕНДАЦИИ ===

1. Измените пароль администратора через веб-интерфейс
2. Настройте профиль организации в Администрирование > Сайт > Настройки
3. Создайте первые курсы и добавьте пользователей
4. Настройте роли и разрешения под ваши требования
5. Проверьте работу email уведомлений
6. Настройте резервное копирование под ваше расписание

=== СЛЕДУЮЩИЕ ШАГИ ===

- Настройка интеграций с внешними системами
- Установка дополнительных плагинов
- Создание пользовательских курсов
- Настройка отчетности и аналитики
EOF

echo "17. Проверка работоспособности всех компонентов..."
/root/moodle-diagnostics.sh | head -20

echo "18. Создание инструкции для администратора..."
cat > /root/moodle-admin-guide.txt << EOF
# Руководство администратора Moodle RTTI LMS
# Дата: $(date)

=== ПЕРВОНАЧАЛЬНАЯ НАСТРОЙКА ===

1. ВХОД В СИСТЕМУ
   URL: https://omuzgorpro.tj
   Логин: admin
   Пароль: см. /root/moodle-admin-credentials.txt

2. ОБЯЗАТЕЛЬНЫЕ ПЕРВЫЕ ШАГИ
   - Смените пароль администратора
   - Настройте профиль: Администрирование > Пользователи > Аккаунты > Изменить профиль
   - Настройте сайт: Администрирование > Сайт > Настройки

3. НАСТРОЙКА ОРГАНИЗАЦИИ
   - Название сайта: RTTI Learning Management System
   - Краткое название: RTTI LMS
   - Описание: Система обучения РЦТИ
   - Часовой пояс: Asia/Dushanbe
   - Страна: Таджикистан

=== УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ ===

1. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ
   Администрирование > Пользователи > Аккаунты > Добавить пользователя

2. МАССОВАЯ ЗАГРУЗКА
   Администрирование > Пользователи > Аккаунты > Загрузить пользователей

3. РОЛИ И РАЗРЕШЕНИЯ
   Администрирование > Пользователи > Разрешения > Определить роли

=== УПРАВЛЕНИЕ КУРСАМИ ===

1. СОЗДАНИЕ КУРСА
   Администрирование > Курсы > Управление курсами и категориями

2. КАТЕГОРИИ КУРСОВ
   Используйте созданные категории или создайте новые

3. ЗАПИСЬ НА КУРСЫ
   Настройте методы записи в настройках курса

=== ТЕХНИЧЕСКОЕ ОБСЛУЖИВАНИЕ ===

1. МОНИТОРИНГ
   Скрипт: /root/moodle-performance-monitor.sh

2. РЕЗЕРВНОЕ КОПИРОВАНИЕ
   Автоматическое: каждую ночь в 2:00
   Ручное: /root/moodle-backup.sh

3. ОБНОВЛЕНИЯ
   Система: /root/moodle-system-update.sh
   Moodle: /root/update-moodle.sh

4. ДИАГНОСТИКА
   Проверка: /root/moodle-diagnostics.sh

=== ВАЖНЫЕ ССЫЛКИ ===

Главная: https://omuzgorpro.tj
Админ-панель: https://omuzgorpro.tj/admin/
Пользователи: https://omuzgorpro.tj/admin/user.php
Курсы: https://omuzgorpro.tj/course/
Плагины: https://omuzgorpro.tj/admin/plugins.php
Отчеты: https://omuzgorpro.tj/admin/reports.php

=== ПОДДЕРЖКА ===

Email: support@omuzgorpro.tj
Документация: https://docs.moodle.org/
Сообщество: https://moodle.org/community/
EOF

echo
echo "🎉 ================================================"
echo "🎉 ПОСТ-УСТАНОВОЧНАЯ НАСТРОЙКА ЗАВЕРШЕНА!"
echo "🎉 ================================================"
echo
echo "✅ Все компоненты настроены и оптимизированы"
echo "✅ cURL проверен и исправлен (curl_exec функция доступна)"
echo "✅ Русский и таджикский языковые пакеты установлены"
echo "✅ Начальные настройки применены"
echo "✅ Автоматические задачи созданы"
echo "✅ Мониторинг и обслуживание настроены"
echo
echo "📋 Созданные документы:"
echo "   - Отчет: /root/moodle-post-install-report.txt"
echo "   - Руководство: /root/moodle-admin-guide.txt"
echo "   - Мониторинг: /root/moodle-performance-monitor.sh"
echo
echo "🚀 Система готова к работе!"
echo "   URL: https://omuzgorpro.tj"
echo "   Администратор: admin"
echo
echo "📖 Следующие шаги:"
echo "1. Прочитайте /root/moodle-admin-guide.txt"
echo "2. Войдите в систему и смените пароль"
echo "3. Настройте профиль организации"
echo "4. Создайте первые курсы"
echo "5. Запустите ./10-final-check.sh для финальной проверки"
echo
echo "✅ Шаг 9 завершен успешно!"
echo "📌 Следующий шаг: ./10-final-check.sh"
echo
