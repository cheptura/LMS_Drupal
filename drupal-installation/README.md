# Drupal Installation Scripts

## Описание
Автоматизированные скрипты для установки Drupal 11 Digital Library на Ubuntu 24.04 LTS с оптимизациями для RTTI.

## 🚀 QUICK_INSTALL
```bash
# Быстрая установка с заменой файлов (одной командой)
cd /tmp
rm -rf LMS_Drupal 2>/dev/null || true
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/drupal-installation
sudo chmod +x install-drupal.sh && sudo ./install-drupal.sh
```

⚠️ **ВАЖНО для SSL:** Если получите ошибку лимита сертификатов Let's Encrypt ("too many certificates"), см. раздел troubleshooting → "Ошибка лимита сертификатов Let's Encrypt"

⚠️ **ВАЖНО для старых версий:** Если при запуске встречается ошибка "location directive is not allowed here", обновите репозиторий:
```bash
cd /tmp/LMS_Drupal && git pull --force origin main
```

### 🔄 Обновление существующего репозитория:
```bash
# Если репозиторий уже склонирован
cd /tmp/LMS_Drupal
git reset --hard HEAD
git pull --force origin main
cd drupal-installation
sudo chmod +x *.sh
```

## Состав скриптов

### 📦 Основные установочные скрипты:
1. **01-prepare-system.sh** - Подготовка системы Ubuntu
2. **02-install-webserver.sh** - Установка и настройка Nginx веб-сервера
3. **03-install-database.sh** - Установка PostgreSQL 16 СУБД
4. **04-install-cache.sh** - Установка и настройка Redis
5. **05-configure-ssl.sh** - Настройка SSL сертификатов
6. **06-install-drupal.sh** - Загрузка и установка Drupal 11 LTS
7. **07-configure-drupal.sh** - Базовая настройка Drupal (облегченная версия)
8. **08-post-install.sh** - Пост-установочная оптимизация (облегченная версия)
9. **09-security.sh** - Базовая настройка безопасности (облегченная версия)
10. **10-final-check.sh** - Финальная проверка и валидация

### 🛠️ Утилиты администрирования:
- **update-drupal.sh** - Обновление Drupal через Composer и Drush
- **backup-drupal.sh** - Создание полных резервных копий с экспортом конфигураций
- **restore-drupal.sh** - Восстановление из резервных копий с импортом конфигураций
- **diagnose-drupal.sh** - Полная диагностика системы Drupal

### 📋 Автоматическая установка:
- **install-drupal.sh** - Полная автоматическая установка всех компонентов

### 🔄 Версии скриптов:
- **Облегченные версии** (по умолчанию) - быстрая установка с минимальными настройками
- **Полные версии** (резервные копии) - расширенные настройки с мониторингом:
  - `07-configure-drupal-full.sh.backup` - полная версия с созданием типов контента
  - `08-post-install-full.sh.backup` - полная версия со скриптами мониторинга
  - `09-security-full.sh.backup` - полная версия с Fail2Ban и расширенной безопасностью

## Поэтапная установка
```bash
# Подготовка с заменой файлов
cd /tmp
rm -rf LMS_Drupal 2>/dev/null || true
git clone https://github.com/cheptura/LMS_Drupal.git
cd /tmp/LMS_Drupal/drupal-installation
sudo chmod +x *.sh

# Поэтапное выполнение
sudo ./01-prepare-system.sh      # Подготовка системы Ubuntu
sudo ./02-install-webserver.sh   # Установка Nginx и PHP
sudo ./03-install-database.sh    # Установка PostgreSQL 16
sudo ./04-install-cache.sh       # Установка и настройка Redis
sudo ./05-configure-ssl.sh       # Настройка SSL сертификатов
sudo ./06-install-drupal.sh      # Загрузка и установка Drupal 11
sudo ./07-configure-drupal.sh    # Настройка конфигурации Drupal
sudo ./08-post-install.sh        # Пост-установочная настройка
sudo ./09-security.sh            # Настройка безопасности
sudo ./10-final-check.sh         # Финальная проверка
```

## Финальная проверка системы

После завершения установки скрипт `10-final-check.sh` проводит комплексную диагностику:

### ✅ Что проверяется:
- **Системные компоненты**: ОС, архитектура, время работы
- **Сетевая конфигурация**: IP-адрес, DNS, открытые порты (80, 443, 22, 5432, 6379)
- **Веб-сервер**: статус Nginx, версия, конфигурация, SSL сертификат
- **PHP**: статус PHP-FPM, версия, необходимые модули
- **База данных**: статус PostgreSQL, подключение, размер БД
- **Кэширование**: статус Redis и Memcached, использование памяти
- **Drupal**: статус приложения, модули, темы, конфигурация

### 🔧 Решение проблем после проверки:

#### Если отсутствует PHP OPcache:
```bash
sudo apt install php8.3-opcache
sudo systemctl restart php8.3-fpm
sudo systemctl restart nginx
```

#### Если проблемы с SSL сертификатом:
```bash
sudo certbot renew --dry-run
sudo systemctl reload nginx
```

#### Если Redis недоступен:
```bash
sudo systemctl restart redis-server
sudo systemctl status redis-server
```

## Администрирование

### 🔍 Диагностика системы
```bash
sudo ./diagnose-drupal.sh  # Полная проверка всех компонентов
systemctl status nginx postgresql php8.3-fpm  # Статус сервисов
drush status  # Статус Drupal через Drush
```

### 💾 Резервное копирование
```bash
sudo ./backup-drupal.sh    # Создание полного бэкапа с экспортом конфигураций
# Бэкапы сохраняются в /var/backups/drupal/
```

### 🔄 Обновление системы
```bash
sudo ./update-drupal.sh    # Обновление Drupal через Composer
drush updatedb  # Обновление базы данных
drush cache:rebuild  # Очистка кэша
```

### 🔧 Восстановление
```bash
sudo ./restore-drupal.sh /path/to/backup.tar.gz  # Восстановление из бэкапа
```

### 📦 Управление модулями через Drush
```bash
drush pm:list           # Список всех модулей
drush pm:enable module  # Включение модуля
drush pm:uninstall module  # Удаление модуля
drush config:export     # Экспорт конфигурации
drush config:import     # Импорт конфигурации
```

## Системные требования
- ✅ **ОС:** Ubuntu 24.04 LTS
- ✅ **RAM:** Минимум 4GB (рекомендуется 8GB)
- ✅ **Диск:** 20GB свободного места (рекомендуется 50GB)
- ✅ **Сеть:** Доступ к интернету для загрузки пакетов
- ✅ **Права:** root или sudo доступ
- ✅ **PHP:** 8.3+ с расширениями (gd, curl, dom, simplexml, etc.)

## Сетевые порты
- **80** - HTTP (веб-сервер)
- **443** - HTTPS (защищенный веб-сервер)
- **5432** - PostgreSQL (база данных)
- **9000** - PHP-FPM (внутренний)

## Доступ к системе

### 🌐 Веб-интерфейс Drupal:
- **HTTP:** http://storage.omuzgorpro.tj
- **HTTPS:** https://storage.omuzgorpro.tj (после настройки SSL)
- **Админ панель:** /admin

### 👤 Учетные данные:
- Данные администратора выводятся в конце установки
- Сохраняются в файле `/var/log/drupal-install.log`

### 📁 Важные директории:
- **Код Drupal:** `/var/www/drupal`
- **Файлы сайта:** `/var/www/drupal/web/sites/default/files`
- **Конфигурация:** `/var/www/drupal/config/sync`
- **Composer:** `/var/www/drupal/composer.json`
- **Логи Nginx:** `/var/log/nginx/`
- **Логи PHP:** `/var/log/php8.3-fpm.log`

## Установленные модули Digital Library
- **Media Library** - Управление медиафайлами
- **Views** - Создание списков и каталогов
- **Taxonomy** - Система категоризации
- **Search API** - Продвинутый поиск
- **Pathauto** - Автоматические URL
- **Metatag** - SEO оптимизация
- **Admin Toolbar** - Расширенная админ панель
- **Entity Reference** - Связи между контентом

## Поддержка и troubleshooting

### 🚨 Распространенные проблемы:

#### Ошибка конфигурации Nginx
```bash
# Если nginx -t показывает ошибки синтаксиса:
sudo nginx -t                                    # Проверка конфигурации
sudo nginx -T                                    # Показать всю конфигурацию

# Если ошибка "location directive is not allowed here":
# Обновите репозиторий до последней версии:
cd /tmp/LMS_Drupal && git pull --force origin main
cd drupal-installation && sudo chmod +x *.sh

# Если проблема в drupal-static.conf (старые версии):
sudo rm -f /etc/nginx/conf.d/drupal-static.conf  # Удаление проблемного файла
sudo systemctl reload nginx                      # Перезагрузка Nginx
```

#### Проблемы с PHP версиями
```bash
# ВАЖНО: Скрипты теперь защищены от автоматического обновления PHP
# Если установилась PHP 8.4 вместо PHP 8.3:

# Проверка установленной версии:
php --version                    # Должна показать PHP 8.3.x
dpkg -l | grep php8.3           # Список установленных пакетов PHP 8.3
dpkg -l | grep -E "php[0-9]" | grep -v php8.3  # Проверка других версий

# Переустановка с правильной версией:
sudo ./02-install-webserver.sh  # Гарантированно ставит только PHP 8.3
```

#### Отсутствует PHP OPcache (важно для производительности)
```bash
# Установка OPcache для PHP 8.3:
sudo apt update
sudo apt install php8.3-opcache
sudo systemctl restart php8.3-fpm
sudo systemctl restart nginx

# Проверка установки:
php -m | grep -i opcache        # Должен показать OPcache в списке
php --ini | grep opcache        # Показать путь к конфигурации
```

#### Проблемы с Redis аутентификацией
```bash
# Если Drupal показывает "NOAUTH Authentication required":
# 1. Проверить настройки Redis в settings.php:
sudo grep -A5 "redis.connection" /var/www/drupal/web/sites/default/settings.php

# 2. Убедиться, что пароль Redis правильный:
redis-cli -a "RedisRTTI2024!" ping  # Должен ответить PONG

# 3. Если проблема продолжается, переустановить Redis конфигурацию:
sudo ./04-install-cache.sh
```

#### Общие проблемы:
```bash
# Проверка логов при проблемах
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/php8.3-fpm.log
drush watchdog:show  # Логи Drupal

# Перезапуск сервисов
sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm
sudo systemctl restart postgresql

# Очистка кэша Drupal
drush cache:rebuild
drush cache:clear
```

## Composer команды
```bash
# Обновление всех пакетов
composer update

# Установка нового модуля
composer require 'drupal/module_name'

# Удаление модуля
composer remove drupal/module_name

# Проверка безопасности
composer audit
```
- **Database**: PostgreSQL 16
- **Web Server**: Nginx 1.24+
- **Cache**: Redis 7+
- **SSL**: Let's Encrypt

### Системные требования
- **CPU**: 4+ cores (рекомендуется 6)
- **RAM**: 8GB (рекомендуется 16GB)
- **Storage**: 500GB+ SSD (для мультимедиа)
- **Network**: 1Gbps

## 📁 Структура после установки

```
/var/www/drupal/               # Drupal файлы
/var/drupalfiles/              # Приватные файлы
/root/drupal-credentials.txt   # Данные доступа
/etc/nginx/sites-available/    # Конфигурация Nginx
/etc/php/8.3/                 # Конфигурация PHP
```

## 🔑 Данные доступа

После установки данные сохранятся в:
- `/root/drupal-admin-credentials.txt` - Администратор
- `/root/drupal-db-credentials.txt` - База данных

**По умолчанию:**
- URL: https://storage.omuzgorpro.tj
- Пользователь: admin
- Пароль: RTTIDrupal2024!

## ✅ Проверка установки

```bash
# Проверка служб
systemctl status nginx
systemctl status postgresql
systemctl status redis-server
systemctl status php8.3-fpm

# Проверка сайта
curl -I https://storage.omuzgorpro.tj

# Проверка логов
tail -f /var/log/nginx/error.log
```

### 📊 Результаты финальной проверки

После запуска `./10-final-check.sh` вы получите детальный отчет:

**✅ Успешная установка покажет:**
- Все сервисы активны (Nginx, PHP-FPM, PostgreSQL, Redis)
- Порты 80, 443, 22, 5432, 6379 открыты
- SSL сертификат действителен
- База данных содержит ~97 таблиц Drupal
- Все необходимые PHP модули установлены
- Drupal загружается и отвечает на запросы

**⚠️ Возможные предупреждения:**
- `❌ opcache: не установлен` - не критично, но рекомендуется установить для производительности
- Предупреждения о SSL сертификате - проверьте домен и настройки Let's Encrypt

**🔴 Критические ошибки:**
- Сервисы неактивны - проверьте логи и перезапустите
- База данных недоступна - проверьте пароли и конфигурацию
- Drupal не отвечает - проверьте Nginx и PHP конфигурацию

## 🔧 Управление

### Drush CLI
```bash
cd /var/www/drupal
vendor/bin/drush status
vendor/bin/drush cache:rebuild
vendor/bin/drush user:login admin
vendor/bin/drush pm:enable module_name
```

### Composer
```bash
cd /var/www/drupal
composer require drupal/module_name
composer update
```

### Обновления
```bash
./update-drupal.sh          # Обновление Drupal
./update-system.sh          # Обновление системы
```

### Резервное копирование
```bash
./backup-drupal.sh          # Создание бэкапа
./restore-drupal.sh         # Восстановление
```

## 📚 Модули библиотеки

### Предустановленные модули
- **Book** - Организация книг в иерархию
- **Taxonomy** - Система категорий и тегов
- **Search** - Поиск по контенту
- **Media** - Управление мультимедиа
- **Views** - Создание списков контента
- **File** - Управление файлами

### Рекомендуемые дополнительные модули
```bash
cd /var/www/drupal
composer require drupal/facets              # Фасетный поиск
composer require drupal/search_api          # Расширенный поиск
composer require drupal/pdf                 # Поддержка PDF
composer require drupal/backup_migrate      # Резервное копирование
vendor/bin/drush pm:enable facets search_api pdf backup_migrate
```

## 🎨 Темы

### Установка пользовательской темы
```bash
cd /var/www/html/drupal
composer require drupal/bootstrap5
vendor/bin/drush theme:enable bootstrap5
vendor/bin/drush config:set system.theme default bootstrap5
```

## 🔍 Поиск и индексация

### Настройка поиска
```bash
# После установки search_api
vendor/bin/drush search-api:index
vendor/bin/drush search-api:reset-tracker
```

## 🆘 Устранение проблем

### Частые проблемы
1. **Ошибка подключения к БД** - проверьте `/root/drupal-db-credentials.txt`
2. **403 Forbidden** - проверьте права доступа к файлам
3. **500 Error** - проверьте логи PHP и Nginx
4. **Composer ошибки** - очистите кэш: `composer clear-cache`

### Диагностика
```bash
./diagnose-drupal.sh         # Полная диагностика
./fix-permissions.sh         # Исправление прав
./reset-drupal.sh           # Сброс к начальным настройкам
```

### Права доступа
```bash
# Восстановление прав
sudo chown -R www-data:www-data /var/www/html/drupal
sudo chmod -R 755 /var/www/html/drupal
sudo chmod -R 777 /var/www/html/drupal/web/sites/default/files
```

## 📊 Мониторинг

После установки настройте мониторинг:
```bash
cd ../monitoring-installation
sudo ./install-monitoring.sh
```

## 🔗 Интеграция с Moodle

Для настройки интеграции с Moodle LMS:
```bash
./setup-moodle-integration.sh
```

## 📞 Поддержка

- **GitHub**: https://github.com/cheptura/LMS_Drupal/issues
- **Email**: admin@omuzgorpro.tj
- **Документация**: [RTTI LMS Wiki](https://github.com/cheptura/LMS_Drupal/wiki)
- **Drupal.org**: https://www.drupal.org/docs

---

**Версия**: 1.0  
**Дата**: Сентябрь 2025  
**Автор**: RTTI Development Team
