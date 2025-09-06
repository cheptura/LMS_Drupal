# Moodle Installation Scripts

## Описание
Автоматизированные скрипты для установки Moodle 5.0+ на Ubuntu 24.04 с оптимизациями для RTTI.

**✅ Новое в сентябре 2025:** Все исправления JavaScript/CSS, CSP, PHP конфигурации и недостающих обработчиков полностью интегрированы в основную установку! Больше не нужны дополнительные fix-скрипты.

## 🚀 QUICK_INSTALL
```bash
# Быстрая установка с заменой файлов (одной командой)
rm -rf LMS_Drupal 2>/dev/null || true
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/moodle-installation
sudo chmod +x install-moodle.sh && sudo ./install-moodle.sh
```

### 🔄 Обновление существующего репозитория:
```bash
# Если репозиторий уже склонирован
cd /tmp/LMS_Drupal
git reset --hard HEAD
git pull --force origin main
cd moodle-installation
sudo chmod +x *.sh
```

## Состав скриптов

### 📦 Основные установочные скрипты:
1. **01-prepare-system.sh** - Подготовка системы Ubuntu
2. **02-install-webserver.sh** - Установка Nginx + PHP 8.3 + расширенная конфигурация + CSP + обработчики
3. **03-install-database.sh** - Установка PostgreSQL 16 СУБД
4. **04-install-cache.sh** - Установка и настройка Redis
5. **05-configure-ssl.sh** - Настройка SSL сертификатов + CSP + обработчики font.php/image.php
6. **06-download-moodle.sh** - Загрузка последней версии Moodle 5.0
7. **07-configure-moodle.sh** - Настройка конфигурации Moodle
8. **08-install-moodle.sh** - Умная установка Moodle (проверяет готовность PHP, автоматически обрабатывает все ситуации)
9. **09-post-install.sh** - Пост-установочная настройка
10. **10-final-check.sh** - Финальная проверка и валидация

### 🛠️ Утилиты администрирования:
- **update-moodle.sh** - Обновление Moodle до новых версий
- **backup-moodle.sh** - Создание полных резервных копий
- **restore-moodle.sh** - Восстановление из резервных копий
- **diagnose-moodle.sh** - Полная диагностика системы Moodle
- **diagnose-php-fpm.sh** - Диагностика и исправление PHP-FPM
- **fix-permissions.sh** - Исправление прав доступа к файлам
- **fix-config-issues.sh** - Исправление проблем конфигурации

### 🆘 Emergency утилиты (для критических ситуаций):
- **emergency-nginx-recovery.sh** - Полное восстановление конфигурации Nginx
- **emergency-stop-cron.sh** - Экстренная остановка cron задач Moodle
- **emergency-nginx-recovery.sh** - Экстренное восстановление Nginx при полной поломке конфигурации
- **manage-cron.sh** - Управление планировщиком задач Moodle (настройка, запуск, остановка)

### 📋 Автоматическая установка:
- **install-moodle.sh** - Полная автоматическая установка всех компонентов

## Поэтапная установка
```bash
# Подготовка с заменой файлов
rm -rf LMS_Drupal 2>/dev/null || true
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/moodle-installation
sudo chmod +x *.sh

# Поэтапное выполнение
sudo ./01-prepare-system.sh      # Подготовка системы Ubuntu
sudo ./02-install-webserver.sh   # Установка Nginx и PHP 8.3
sudo ./03-install-database.sh    # Установка PostgreSQL 16
sudo ./04-install-cache.sh       # Установка и настройка Redis
sudo ./05-configure-ssl.sh       # Настройка SSL сертификатов
sudo ./06-download-moodle.sh     # Загрузка Moodle 5.0
sudo ./07-configure-moodle.sh    # Настройка конфигурации Moodle
sudo ./08-install-moodle.sh      # Установка Moodle в систему
sudo ./09-post-install.sh        # Пост-установочная настройка
sudo ./10-final-check.sh         # Финальная проверка и валидация
```

## Администрирование

### 🔍 Диагностика системы
```bash
sudo ./diagnose-moodle.sh  # Полная проверка всех компонентов
systemctl status nginx postgresql php8.3-fpm  # Статус сервисов
```

### 💾 Резервное копирование
```bash
sudo ./backup-moodle.sh    # Создание полного бэкапа
# Бэкапы сохраняются в /var/backups/moodle/
```

### 🔄 Обновление системы
```bash
sudo ./update-moodle.sh    # Обновление до новой версии Moodle
```

### 🔧 Восстановление
```bash
sudo ./restore-moodle.sh /path/to/backup.tar.gz  # Восстановление из бэкапа
```

## Системные требования
- ✅ **ОС:** Ubuntu 24.04 LTS
- ✅ **RAM:** Минимум 4GB (рекомендуется 8GB)
- ✅ **Диск:** 20GB свободного места (рекомендуется 50GB)
- ✅ **Сеть:** Доступ к интернету для загрузки пакетов
- ✅ **Права:** root или sudo доступ

## Сетевые порты
- **80** - HTTP (веб-сервер)
- **443** - HTTPS (защищенный веб-сервер)
- **5432** - PostgreSQL (база данных)
- **9000** - PHP-FPM (внутренний)

## Доступ к системе

### 🌐 Веб-интерфейс Moodle:
- **HTTP:** http://ваш-ip-адрес
- **HTTPS:** https://ваш-домен (после настройки SSL)

### 🔑 Учетные данные:
- Данные администратора выводятся в конце установки
- Сохраняются в файле `/var/log/moodle-install.log`

### 📁 Важные директории:
- **Код Moodle:** `/var/www/moodle` (новые установки) или `/var/www/html/moodle` (старые установки)
- **Данные:** `/var/moodledata`
- **Конфигурация:** `/var/www/moodle/config.php`
- **Логи Nginx:** `/var/log/nginx/`
- **Логи PHP:** `/var/log/php8.3-fpm.log`

## 📦 PHP 8.3 Расширения

### ✅ Обязательные расширения (автоматически устанавливаются):
- **ctype** - Встроено в PHP 8.3
- **curl** - HTTP клиент (php8.3-curl)
- **dom** - Встроено в php8.3-xml
- **gd** - Обработка изображений (php8.3-gd)
- **iconv** - Встроено в PHP 8.3
- **intl** - Интернационализация (php8.3-intl)
- **json** - Встроено в PHP 8.3
- **mbstring** - Многобайтовые строки (php8.3-mbstring)
- **pcre** - Встроено в PHP 8.3
- **simplexml** - Встроено в php8.3-xml
- **spl** - Встроено в PHP 8.3
- **xml** - XML парсер (php8.3-xml)
- **zip** - Работа с архивами (php8.3-zip)
- **pgsql** - PostgreSQL драйвер (php8.3-pgsql)

### 🔧 Рекомендуемые расширения:
- **openssl** - Встроено в PHP 8.3
- **soap** - Web services (php8.3-soap)
- **sodium** - Встроено в PHP 8.3 (современная криптография)
- **tokenizer** - Встроено в PHP 8.3
- **xmlrpc** - XML-RPC протокол (php8.3-xmlrpc)
- **ldap** - LDAP аутентификация (php8.3-ldap)
- **redis** - Redis кэш (php8.3-redis)

## Поддержка и troubleshooting

### 🚨 Распространенные проблемы и решения:

#### Предупреждение "hard-set in the config.php, unable to change"
```bash
# ✅ Это предупреждение появляется при попытке изменить настройки
# которые уже заданы в файле config.php - это НОРМАЛЬНО!

# Проявления: "The configuration variable is hard-set in the config.php"
# Причина: Некоторые настройки задаются в config.php и имеют приоритет

# 🎯 РЕШЕНИЕ: Это НЕ ошибка, установка продолжается нормально!
# Настройки уже правильно заданы в config.php

# Если нужно изменить эти настройки:
sudo nano /var/www/moodle/config.php

# Найдите строки типа:
# $CFG->theme = 'boost';
# $CFG->enablecompletion = 1;

# И измените значения по необходимости
```

#### Проблемы с Moodle Cron (непрерывное выполнение)
```bash
# Если cron работает непрерывно и не останавливается
# Проявления: "Continuing to check for tasks for XXX more seconds"
# ИЛИ: "Execute scheduled task: Cleanup old sessions" и зависает

# БЫСТРОЕ РЕШЕНИЕ (в новом терминале):
sudo pkill -f "cron.php"
sudo pkill -9 -f "cron.php"

# Решение 1: Используйте утилиту управления cron:
sudo chmod +x manage-cron.sh && sudo ./manage-cron.sh
# В меню выберите:
# 3) Остановить все запущенные cron процессы
# 1) Настроить системный cron (рекомендуется)

# Решение 2: Экстренная остановка
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-installation/quick-stop-cron.sh
chmod +x quick-stop-cron.sh
sudo ./quick-stop-cron.sh

# Решение 3: Остановка вручную
# Найти все запущенные процессы cron:
ps aux | grep cron.php

# Остановить процессы (замените PID на реальные номера):
sudo kill [PID1] [PID2] ...

# Или принудительно:
sudo pkill -f cron.php

# Решение 4: Правильная настройка системного cron
# Создать файл /etc/cron.d/moodle:
sudo nano /etc/cron.d/moodle

# Добавить содержимое:
# * * * * * www-data /usr/bin/php /var/www/moodle/admin/cli/cron.php --quiet >/dev/null 2>&1

# Перезапустить cron службу:
sudo systemctl restart cron

# Проверить статус:
sudo systemctl status cron
```

#### Ошибка "max_input_vars должен быть не менее 5000"
```bash
# Эта ошибка появляется при установке Moodle, если PHP настроен неправильно
# Проявления: "max_input_vars !! [Система] этот тест должен быть пройден"

# Решение 1: Используйте специальный скрипт исправления PHP:
sudo ./fix-php-config.sh

# Решение 2: Исправление вручную
sudo nano /etc/php/8.3/fpm/php.ini
# Найдите строку max_input_vars и установите:
# max_input_vars = 5000

sudo nano /etc/php/8.3/cli/php.ini  
# Тоже самое для CLI версии

# Перезапустите PHP-FPM:
sudo systemctl restart php8.3-fpm

# Проверьте настройку:
php -r "echo 'max_input_vars = ' . ini_get('max_input_vars') . PHP_EOL;"
# Должно показать: max_input_vars = 5000
```

#### Ошибка "Command line scripts must define CLI_SCRIPT"
```bash
# ✅ Эта ошибка исправлена в скриптах версии 2.0+
# Если получаете эту ошибку при выполнении 09-post-install.sh
# Скрипт уже исправлен для корректной проверки подключений

# Проверьте вручную подключение к базе:
sudo -u postgres psql -d moodle -c "SELECT version();"

# Проверьте Redis:
redis-cli ping
```

#### Проблемы конфигурации config.php (Moodle 5.0+)
```bash
# ✅ Исправлено в версии скриптов 2.0+
# Новые требования Moodle 5.0:

# 1. Добавлена настройка routerconfigured
# Проявления: Предупреждения о роутере в логах
# Решение: Автоматически добавляется $CFG->routerconfigured = false;

# 2. Убрана неправильная коллация для PostgreSQL
# Проявления: "dbcollation not supported for pgsql"
# Решение: Удалена настройка 'dbcollation' => 'utf8_unicode_ci' для PostgreSQL

# 3. Правильные права директорий
# Решение: Использование 02777 вместо 0777 для совместимости

# Если у вас старая версия config.php:
sudo ./07-configure-moodle.sh  # Пересоздаст config.php с правильными настройками
```

#### Ошибка "php8.3-fpm.service not found" или проблемы с версиями PHP
```bash
# НОВАЯ ПРОБЛЕМА: Установилась PHP 8.4
# Проявления: "database driver problem detected", "PGSQL extension is not loaded"
# Причина: репозиторий ppa:ondrej/php автоматически устанавливает PHP 8.4

# Решение 1: Полное исправление версий PHP - запустите:
sudo ./fix-php-versions.sh

# Решение 2: Используйте исправленный скрипт установки:
sudo ./02-install-webserver.sh  # Теперь гарантированно ставит только PHP 8.3

# Это полностью очистит все версии PHP и установит только PHP 8.3
# с всеми необходимыми расширениями для Moodle

# Проверка установленной версии:
php --version                    # Должна показать PHP 8.3.x
dpkg -l | grep php8.3           # Список установленных пакетов PHP 8.3
dpkg -l | grep -E "php[0-9]" | grep -v php8.3  # Проверка других версий

# Или определите версию PHP и исправьте вручную:
php --version
sudo systemctl start php8.3-fpm  # или другую доступную версию
sudo systemctl enable php8.3-fpm

# Запустите диагностику PHP-FPM:
sudo ./diagnose-php-fpm.sh
```

#### Проверка PHP расширений для Moodle
```bash
# Проверка всех необходимых расширений:
php -m | grep -E "(curl|gd|intl|mbstring|xml|zip|pgsql|soap|sodium)"

# Создание тестового файла для проверки:
php -r "
echo 'PHP Version: ' . phpversion() . PHP_EOL;
echo 'Required extensions:' . PHP_EOL;
\$required = ['curl', 'gd', 'intl', 'mbstring', 'xml', 'zip', 'pgsql'];
foreach (\$required as \$ext) {
    echo \$ext . ': ' . (extension_loaded(\$ext) ? 'OK' : 'MISSING') . PHP_EOL;
}
"

# Установка недостающих расширений:
sudo apt install -y php8.3-pgsql php8.3-gd php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip php8.3-intl php8.3-soap
sudo systemctl restart php8.3-fpm
```

#### Ошибка "database driver problem detected" (PGSQL extension)
```bash
# Если PHP расширение PostgreSQL отсутствует:
sudo ./fix-php-versions.sh  # Это установит все необходимые расширения

# Или установите вручную:
sudo apt install -y php8.3-pgsql
sudo systemctl restart php8.3-fpm
```

#### Отсутствует файл блокировки установки (install.lock)
```bash
# ✅ Проблема: "Блокировка установки: отсутствует (установка может быть не завершена)"
# Проявления: При диагностике показывает предупреждение об отсутствии install.lock

# 🎯 РЕШЕНИЕ: Запустите умный скрипт установки
sudo ./08-install-moodle.sh

# Скрипт автоматически:
# 1. Определит состояние установки
# 2. Завершит прерванную установку
# 3. Создаст файл install.lock
# 4. Проверит целостность всех компонентов

# Альтернативные варианты:
# Если только нужно создать файл блокировки:
sudo touch /var/www/moodle/install.lock
sudo chown www-data:www-data /var/www/moodle/install.lock

# Проверка после исправления:
sudo ./diagnose-moodle.sh
```

#### Предупреждения при установке (НЕ критичные)
```bash
# ✅ Эти сообщения НОРМАЛЬНЫ и НЕ требуют исправления:

# 1. "integer expression expected" 
# Проявления: "./08-install-moodle.sh: line 191: [: 0 0: integer expression expected"
# Причина: Внутренняя проверка скрипта
# Решение: Игнорируйте - это не влияет на установку

# 2. "No upgrade needed for the installed version"
# Проявления: "No upgrade needed for the installed version 5.0.2+"
# Причина: Moodle уже установлен и актуален
# Решение: Это хорошо! Обновление не требуется

# 3. "Cron выполнен с предупреждениями (не критично)"
# Проявления: Предупреждения при тестировании cron
# Причина: Первый запуск cron может показывать предупреждения
# Решение: Это нормально при первой установке

# 4. "Предупреждение при переустановке кэша (не критично)"
# Проявления: Сообщения при очистке кэша
# Причина: Кэш может быть пустым при первой установке
# Решение: Нормальное поведение

# 🎯 ВАЖНО: Если установка завершилась сообщением
# "УМНАЯ УСТАНОВКА MOODLE ЗАВЕРШЕНА УСПЕШНО!" - всё в порядке!
```

#### Проблемы с загрузкой JavaScript и CSS файлов
```bash
# ❌ Проблема: JavaScript и CSS файлы не загружаются (ошибки 404)
# Проявления: 
# - "GET /lib/javascript.php/1/lib/javascript-static.js net::ERR_ABORTED 404"
# - "GET /theme/styles.php/boost/xxx/all net::ERR_ABORTED 404"
# - "Uncaught EvalError: Refused to evaluate a string as JavaScript"
# - "Cannot read properties of undefined (reading 'js_pending')"

# 🎯 АВТОМАТИЧЕСКИ ВКЛЮЧЕНО в scripts 02-install-webserver.sh и 05-configure-ssl.sh
# ✅ CSP с поддержкой 'unsafe-eval' для YUI framework
# ✅ Обработчики font.php и image.php с PATH_INFO
# ✅ Все необходимые JavaScript/CSS handlers
# ✅ Расширенная конфигурация PHP с OPcache

# 🔧 РУЧНОЕ ИСПРАВЛЕНИЕ (только если установка была сделана старыми скриптами):
# Используйте emergency восстановление:
sudo ./emergency-nginx-recovery.sh

# 🆘 ЭКСТРЕННОЕ ВОССТАНОВЛЕНИЕ (если сайт вообще не работает):
sudo ./emergency-nginx-recovery.sh

# Что делают скрипты:
# fix-nginx-moodle.sh - исправляет HTTP конфигурацию
# fix-nginx-ssl-moodle.sh - исправляет HTTPS/SSL конфигурацию

# 1. Обновляет конфигурацию Nginx с правильными обработчиками
# 2. Добавляет специальные location для JavaScript и CSS
# 3. Настраивает правильное кэширование  
# 4. Очищает кэш Moodle
# 5. Перезапускает Nginx

# ⚠️ ПРОБЛЕМА С КОНФЛИКТУЮЩИМИ КОНФИГУРАЦИЯМИ SSL
# Проявления: "conflicting server name omuzgorpro.tj on 0.0.0.0:80, ignored"
# Причина: Несколько файлов конфигурации для одного домена

# Решение конфликта SSL конфигураций:
sudo ./fix-nginx-ssl-moodle.sh
# Этот скрипт:
# - Удаляет конфликтующие конфигурации
# - Создает объединенную SSL конфигурацию
# - Настраивает перенаправление HTTP → HTTPS
# - Добавляет все необходимые обработчики для Moodle

# Ручное исправление (если скрипт недоступен):
# 1. Проверьте корневую папку в Nginx:
sudo nano /etc/nginx/sites-available/omuzgorpro.tj
# Убедитесь что root указывает на /var/www/moodle (НЕ /var/www/html/moodle)

# 2. Добавьте обработчики для Moodle файлов:
# location ~ ^/lib/javascript\.php {
#     include snippets/fastcgi-php.conf;
#     fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
# }
# 
# location ~ ^/theme/styles\.php {
#     include snippets/fastcgi-php.conf;
#     fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
# }

# 3. Перезапустите Nginx:
sudo nginx -t && sudo systemctl reload nginx

# 4. Очистите кэш:
sudo -u www-data php /var/www/moodle/admin/cli/purge_caches.php

# 5. Очистите кэш браузера (Ctrl+F5)
```

### 📝 Проверка логов при проблемах
```bash
# Проверка логов при проблемах
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/php8.3-fpm.log
sudo journalctl -u nginx -f

# Перезапуск сервисов
sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm
sudo systemctl restart postgresql
```

## 📊 Мониторинг
После установки мониторинга (папка `monitoring-installation`):
- **Grafana:** http://ваш-ip:3000 (admin/admin)
- **Prometheus:** http://ваш-ip:9090
- **Alertmanager:** http://ваш-ip:9093

## 🏢 RTTI Информация
- **Проект:** LMS для Республиканского Технологического Техникума Информатизации
- **Сервер:** omuzgorpro.tj
- **GitHub:** https://github.com/cheptura/LMS_Drupal
- **Автор:** cheptura

## 📝 Лицензия
Этот проект предназначен для использования в RTTI и распространяется под лицензией MIT.
