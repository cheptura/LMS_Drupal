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
1. **01-prepare-system.sh** - Подготовка системы Ubuntu + базовый firewall
2. **02-install-webserver.sh** - Установка Nginx + PHP 8.3 + расширенная конфигурация + CSP + обработчики
3. **03-install-database.sh** - Установка PostgreSQL 16 СУБД
4. **04-install-cache.sh** - Установка и настройка Redis
5. **05-configure-ssl.sh** - Настройка SSL сертификатов + CSP + обработчики font.php/image.php
6. **06-download-moodle.sh** - Загрузка последней версии Moodle 5.0
7. **07-configure-moodle.sh** - Настройка конфигурации Moodle
8. **08-install-moodle.sh** - Умная установка Moodle (проверяет готовность PHP, автоматически обрабатывает все ситуации)
9. **09-post-install.sh** - Пост-установочная настройка
10. **10-security.sh** - 🛡️ **НОВОЕ**: Углубленная настройка безопасности (Fail2Ban, Rate Limiting, мониторинг)
11. **11-final-check.sh** - Финальная проверка и валидация

### 🛠️ Утилиты администрирования:
- **update-moodle.sh** - Обновление Moodle до новых версий
- **backup-moodle.sh** - Создание полных резервных копий
- **restore-moodle.sh** - Восстановление из резервных копий
- **diagnose-moodle.sh** - Полная диагностика системы Moodle
- **fix-permissions.sh** - Исправление прав доступа к файлам
- **fix-config-issues.sh** - Исправление проблем конфигурации

### 🆘 Emergency утилиты (для критических ситуаций):
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
sudo ./01-prepare-system.sh      # Подготовка системы Ubuntu + firewall
sudo ./02-install-webserver.sh   # Установка Nginx и PHP 8.3
sudo ./03-install-database.sh    # Установка PostgreSQL 16
sudo ./04-install-cache.sh       # Установка и настройка Redis
sudo ./05-configure-ssl.sh       # Настройка SSL сертификатов
sudo ./06-download-moodle.sh     # Загрузка Moodle 5.0
sudo ./07-configure-moodle.sh    # Настройка конфигурации Moodle
sudo ./08-install-moodle.sh      # Установка Moodle в систему
sudo ./09-post-install.sh        # Пост-установочная настройка
sudo ./10-security.sh            # 🛡️ Настройка безопасности
sudo ./11-final-check.sh         # Финальная проверка и валидация
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

## 🛡️ Безопасность

### Меры защиты (автоматически устанавливаются):

#### 🔥 Базовая защита (01-prepare-system.sh):
- **UFW Firewall** - базовые правила для портов 22, 80, 443
- **Автоматические обновления безопасности** 
- **Оптимизация системных лимитов**

#### 🌐 Веб-безопасность (02-install-webserver.sh, 05-configure-ssl.sh):
- **Content Security Policy (CSP)** с поддержкой YUI framework
- **HSTS заголовки** для принудительного HTTPS
- **Security Headers** (X-Frame-Options, X-XSS-Protection, X-Content-Type-Options)
- **Скрытие версии сервера**

#### 🛡️ Углубленная защита (10-security.sh):
- **Fail2Ban** - защита от атак перебора (brute force)
  - Мониторинг попыток входа в Moodle
  - Блокировка подозрительных IP
  - Защита от bot-атак
- **Rate Limiting** - защита от DDoS
  - Ограничение запросов к логину (5/минуту)
  - Ограничение API запросов (30/минуту)
  - Ограничение соединений на IP (25 одновременно)
- **PHP Hardening** - укрепление PHP
  - Отключение опасных функций
  - Безопасные настройки загрузки файлов
  - Скрытие версии PHP
- **Мониторинг безопасности**
  - Автоматическая проверка каждые 15 минут
  - Логирование подозрительной активности
  - Мониторинг ресурсов системы

### 🔧 Управление безопасностью:

```bash
# Проверка статуса Fail2Ban
sudo fail2ban-client status

# Разблокировка IP (если заблокирован по ошибке)
sudo fail2ban-client set moodle-auth unbanip ВАSH_IP

# Просмотр логов безопасности
sudo tail -f /var/log/moodle-security.log

# Проверка файрвола
sudo ufw status verbose

# Просмотр заблокированных IP
sudo fail2ban-client status moodle-auth
```

### 📊 Файлы мониторинга:
- **Логи безопасности:** `/var/log/moodle-security.log`
- **Логи Nginx:** `/var/log/nginx/security.log`
- **Логи Fail2Ban:** `/var/log/fail2ban.log`
- **Резервные копии конфигураций:** `/root/security-backup-YYYYMMDD/`

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

#### Ошибки конфигурации Nginx (не запускается)
```bash
# ❌ Проблема: Nginx не запускается или падает после настройки безопасности
# Проявления:
# - "nginx: configuration file /etc/nginx/nginx.conf test failed"
# - "nginx.service failed with result 'exit-code'"
# - Ошибки при выполнении nginx -t

# 🎯 ДИАГНОСТИКА:
sudo nginx -t
# Показывает точную ошибку в конфигурации

# 📋 ОСНОВНЫЕ ПРОБЛЕМЫ И РЕШЕНИЯ:

# 1. Дублирование log_format:
# Проблема: log_format security определен несколько раз
grep -n "log_format security" /etc/nginx/nginx.conf
# Решение: Оставить только одно определение в http блоке

# 2. Дублирование limit_req_zone:
# Проблема: "is already bound to key" - зоны определены дважды
grep -r "limit_req_zone.*login" /etc/nginx/
# Решение: Удалить из conf.d, оставить только в nginx.conf

# 3. Устаревшие директивы more_*_headers:
# Проблема: "unknown directive more_clear_headers"
find /etc/nginx/conf.d/ -name "*.conf" -exec grep -l "more_" {} \;
# Решение: Удалить файлы с more_* директивами

# 4. location в неправильном контексте:
# Проблема: "location directive is not allowed here"
grep -r "location " /etc/nginx/conf.d/
# Решение: Переместить location блоки в server секцию

# 🔧 ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ:
# 1. Остановить Nginx:
sudo systemctl stop nginx

# 2. Проверить конфигурацию:
sudo nginx -t

# 3. Удалить проблемные файлы:
sudo rm -f /etc/nginx/conf.d/security-headers.conf
sudo rm -f /etc/nginx/conf.d/rate-limiting.conf
sudo rm -f /etc/nginx/conf.d/ddos-protection.conf

# 4. Восстановить минимальную конфигурацию:
sudo cp /etc/nginx/nginx.conf.backup* /etc/nginx/nginx.conf 2>/dev/null || true

# 5. Протестировать и запустить:
sudo nginx -t && sudo systemctl start nginx

# 🚨 КРИТИЧЕСКОЕ ВОССТАНОВЛЕНИЕ:
# Если Nginx вообще не запускается:
sudo systemctl stop nginx
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.broken
sudo nginx -T > /tmp/default-nginx.conf 2>/dev/null || curl -s https://raw.githubusercontent.com/nginx/nginx/master/conf/nginx.conf > /tmp/default-nginx.conf
sudo cp /tmp/default-nginx.conf /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl start nginx

# 📊 ЛОГИ ДЛЯ ДИАГНОСТИКИ:
sudo journalctl -u nginx -f --no-pager
sudo tail -f /var/log/nginx/error.log

# ℹ️ КОРНЕВЫЕ ПРИЧИНЫ:
# Скрипт 10-security.sh может создавать конфликтующие конфигурации.
# Всегда проверяйте конфигурацию перед применением: sudo nginx -t
```

#### Ошибка "Call to undefined function curl_exec()"
```bash
# ❌ Проблема: Exception - Call to undefined function curl_exec()
# Проявления: Ошибка при загрузке языковых пакетов, обновлениях, веб-сервисах
# Причина: Функции cURL заблокированы в disable_functions файла 99-security.ini

# 🎯 АВТОМАТИЧЕСКОЕ РЕШЕНИЕ: Запустите пост-установку
cd /путь/к/moodle-installation
sudo ./09-post-install.sh

# Скрипт автоматически:
# - Обнаружит блокировку curl_exec в disable_functions
# - Исправит файлы безопасности (с резервными копиями)
# - Переустановит cURL модуль если нужно
# - Протестирует работу с реальным запросом

# 🎯 ЭКСТРЕННОЕ РУЧНОЕ ИСПРАВЛЕНИЕ:
# 1. Найти файлы с проблемой:
grep -r "disable_functions.*curl_exec" /etc/php/8.3/

# 2. Исправить 99-security.ini:
sudo sed -i 's/disable_functions = \(.*\),curl_exec,curl_multi_exec,\(.*\)/disable_functions = \1,\2/' /etc/php/8.3/fpm/conf.d/99-security.ini
sudo sed -i 's/disable_functions = \(.*\),curl_exec,\(.*\)/disable_functions = \1,\2/' /etc/php/8.3/fpm/conf.d/99-security.ini

# 3. Перезапустить PHP-FPM:
sudo systemctl restart php8.3-fpm

# 4. Проверить исправление:
php-fpm8.3 -i | grep "disable_functions"

# ℹ️ КОРНЕВАЯ ПРИЧИНА: 
# Скрипт 10-security.sh создает файл 99-security.ini с disable_functions,
# который блокирует curl_exec. Исправлено в новой версии скриптов!

# ✅ ПРЕВЕНТИВНАЯ МЕРА:
# В обновленной версии скрипта 10-security.sh curl_exec исключен
# из disable_functions, так как критически важен для Moodle

# 🔧 ЕСЛИ ОШИБКА ОСТАЕТСЯ В ВЕБ-ИНТЕРФЕЙСЕ:
# Проблема может быть в том, что cURL работает в CLI, но не в PHP-FPM (веб-версии)
# Выполните дополнительные команды:
sudo apt install -y --reinstall php8.3-curl
echo "extension=curl" | sudo tee -a /etc/php/8.3/fpm/php.ini
sudo systemctl restart php8.3-fpm nginx

# Проверка через веб (создайте тестовый файл):
# echo '<?php echo function_exists("curl_exec") ? "cURL OK" : "cURL FAIL"; ?>' | sudo tee /var/www/moodle/curl-test.php
# Откройте: https://ваш-домен/curl-test.php
# Удалите после проверки: sudo rm /var/www/moodle/curl-test.php
```

#### Ошибка 404 для PHP файлов в админке (langimport, tool и др.)
```bash
# ❌ Проблема: GET /admin/tool/langimport/index.php 404 (Not Found)
# Проявления: 404 ошибки для PHP файлов в папках /admin/tool/, /admin/settings/ и др.
# Причина: Неправильная конфигурация PHP обработчиков в Nginx

# 🎯 РЕШЕНИЕ: Запустите обновленные скрипты безопасности
cd /путь/к/moodle-installation
sudo ./10-security.sh

# Скрипт автоматически исправит PHP обработчики для всех админских путей

# 🎯 РУЧНАЯ ПРОВЕРКА конфигурации Nginx:
sudo nginx -t
# Если есть ошибки синтаксиса, исправите их и перезапустите:
sudo systemctl reload nginx

# Проверьте что основной PHP обработчик правильный в /etc/nginx/sites-available/ваш-сайт:
# location ~ [^/]\.php(/|$) {
#     fastcgi_split_path_info ^(.+\.php)(/.+)$;
#     ...
# }
```

#### Ошибка "unknown directive more_clear_headers"
```bash
# ❌ Проблема: nginx: unknown directive "more_clear_headers" in /etc/nginx/conf.d/security-headers.conf
# Проявления: nginx: configuration file /etc/nginx/nginx.conf test failed
# Причина: Используется директива, которая требует модуль nginx-module-headers-more

# 🎯 РЕШЕНИЕ: Удалите проблемные конфигурации
sudo rm -f /etc/nginx/conf.d/security-headers.conf
sudo rm -f /etc/nginx/conf.d/headers-more.conf
sudo nginx -t && sudo systemctl reload nginx

# Альтернативно: Запустите обновленный скрипт безопасности
cd /путь/к/moodle-installation
sudo ./10-security.sh

# Проверка: sudo nginx -t должно показать "syntax is ok"
```

#### Языковые пакеты не доступны в Moodle
```bash
# ❌ Проблема: "Invalid current value: ru" или только английский язык
# Причина: Языковой пакет не загрузился из-за проблем с cURL

# 🎯 РЕШЕНИЕ: Пост-установка автоматически загружает языковые пакеты
cd /путь/к/moodle-installation
sudo ./09-post-install.sh

# Поддерживаемые языки:
# - Английский (en) - встроенный
# - Русский (ru) - загружается автоматически
# - Таджикский (tg) - загружается автоматически

# Альтернативно через веб-интерфейс:
# Администрирование сайта > Язык > Языковые пакеты > Russian (ru) / Tajik (tg) > Установить
```

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

# Решение 2: Остановка вручную
# Найти все запущенные процессы cron:
ps aux | grep cron.php

# Остановить процессы (замените PID на реальные номера):
sudo kill [PID1] [PID2] ...

# Или принудительно:
sudo pkill -f cron.php

# Решение 3: Правильная настройка системного cron
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

# Решение: Исправление вручную
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

# Решение: Используйте исправленный скрипт установки:
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
# Установите вручную:
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

#### Проблема "Defined in config.php" - настройки не меняются в админке
```bash
# ✅ ИСПРАВЛЕНО в версии скриптов от 6 сентября 2025!
# Теперь в config.php жестко прописаны только критически важные настройки

# ❌ Старая проблема: "The setting is defined in config.php, so it cannot be changed"
# Проявления: 
# - Невозможно изменить настройки через веб-интерфейс администратора
# - Серый текст "Defined in config.php" рядом с настройками
# - Заблокированные поля в форме настроек

# Причина: Слишком много параметров жестко задано в config.php

# 🎯 РЕШЕНИЕ в новой версии:
# В config.php остались только критически важные настройки:
# - Подключение к базе данных ($CFG->dbtype, $CFG->dbhost, etc.)
# - Пути к файлам ($CFG->wwwroot, $CFG->dataroot, etc.)
# - Настройки Redis кэширования
# - Критические настройки безопасности ($CFG->forcessl, $CFG->cookiesecure)
# - Отладка ($CFG->debug)

# ✅ Настройки, которые ТЕПЕРЬ можно изменять через админку:
# - Принудительный вход (forcelogin)
# - Защита имен пользователей (protectusernames)
# - Язык по умолчанию (lang)
# - Часовой пояс (timezone)
# - Тема оформления (theme)
# - Политика паролей (passwordpolicy, minpasswordlength, etc.)
# - Настройки email (smtphosts, noreplyaddress, etc.)
# - Резервное копирование (backup_auto_*)
# - Загрузка файлов (maxbytes)
# - Блоги и RSS (enableblogs, enablerssfeeds)
# - И многие другие...

# 📍 Где найти настройки в админке:
# Администрирование сайта → Настройки → Безопасность → Политики сайта
# Администрирование сайта → Настройки → Местоположение → Настройки местоположения
# Администрирование сайта → Настройки → Внешний вид → Темы → Настройки темы
# Администрирование сайта → Настройки → Сервер → Email → Исходящая почта

# 🔧 Если нужно вернуть старое поведение (НЕ рекомендуется):
# 1. Отредактировать /var/www/moodle/config.php
# 2. Добавить строку: $CFG->настройка = 'значение';
# 3. Сохранить файл

# ⚙️ Первичные настройки применяются автоматически при установке через:
# /root/moodle-initial-settings.sh (создается в 07-configure-moodle.sh)
```

#### Ошибка дублирования rate limiting зон "is already bound to key"
```bash
# ❌ Проблема: limit_req_zone "login" is already bound to key "$binary_remote_addr"
# Проявления: 
# - nginx: configuration file /etc/nginx/nginx.conf test failed
# - Дублирование зон в rate-limiting.conf и nginx.conf
# - Конфликт настроек rate limiting

# Причина: Rate limiting зоны определены дважды

# 🔧 РУЧНОЕ ИСПРАВЛЕНИЕ:
# 1. Удалить дублирующий файл:
sudo rm -f /etc/nginx/conf.d/rate-limiting.conf

# 2. Проверить что зоны есть в nginx.conf:
grep "limit_req_zone" /etc/nginx/nginx.conf

# 3. Если зон нет, добавить в http блок nginx.conf:
sudo nano /etc/nginx/nginx.conf
# Добавить после "http {":
# limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
# limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
# limit_req_zone $binary_remote_addr zone=uploads:10m rate=10r/m;
# limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;

# 4. Проверить и перезагрузить:
sudo nginx -t && sudo systemctl reload nginx

# ✅ После исправления: nginx -t должен показать "syntax is ok"
```

#### Ошибка конфигурации Nginx "location directive is not allowed here"
```bash
# ❌ Проблема: "location directive is not allowed here in /etc/nginx/conf.d/ddos-protection.conf"
# Проявления: 
# - nginx: configuration file /etc/nginx/nginx.conf test failed
# - Ошибка при проверке Nginx конфигурации
# - Сайт может работать, но конфигурация некорректна

# Причина: location блоки созданы в conf.d файле вместо server блока

# 🔧 ИСПРАВЛЕНИЕ:
sudo rm -f /etc/nginx/conf.d/ddos-protection.conf
sudo nginx -t && sudo systemctl reload nginx

# Запустите обновленную версию скрипта безопасности:
git pull origin main  # Получить последнюю версию
sudo ./10-security.sh  # Теперь корректно настраивает DDoS защиту
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

# 🔧 РУЧНОЕ ИСПРАВЛЕНИЕ (если установка была сделана старыми скриптами):
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

# ⚠️ ПРОБЛЕМА С КОНФЛИКТУЮЩИМИ КОНФИГУРАЦИЯМИ SSL
# Проявления: "conflicting server name omuzgorpro.tj on 0.0.0.0:80, ignored"
# Причина: Несколько файлов конфигурации для одного домена

# Решение конфликта SSL конфигураций:
# Проверьте наличие дублирующих файлов:
ls -la /etc/nginx/sites-available/ | grep omuzgorpro
ls -la /etc/nginx/sites-enabled/ | grep omuzgorpro

# Удалите дубликаты, оставив один корректный файл конфигурации
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
