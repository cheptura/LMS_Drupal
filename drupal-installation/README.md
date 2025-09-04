# Drupal 11 Digital Library - Полная установка

Автоматическая установка Drupal Digital Library для RTTI.

## 🎯 Целевой сервер

- **Домен**: library.rtti.tj
- **IP**: 92.242.61.204
- **ОС**: Ubuntu Server 24.04 LTS
- **Версия**: Drupal 11 LTS

## 🚀 Быстрая установка

### Одной командой
```bash
wget -O install-drupal.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/drupal-installation/install-drupal.sh
chmod +x install-drupal.sh
sudo ./install-drupal.sh
```

### Локальная установка
```bash
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/drupal-installation
chmod +x *.sh
sudo ./install-drupal.sh
```

## 📝 Пошаговая установка

Если нужен контроль над каждым этапом:

```bash
sudo ./01-prepare-system.sh      # Подготовка системы
sudo ./02-install-webserver.sh   # Nginx + PHP 8.3
sudo ./03-install-database.sh    # PostgreSQL 16
sudo ./04-install-cache.sh       # Redis
sudo ./05-configure-domain.sh    # Настройка домена
sudo ./06-install-ssl.sh         # SSL сертификаты
sudo ./07-install-composer.sh    # Composer
sudo ./08-download-drupal.sh     # Установка Drupal
sudo ./09-configure-drupal.sh    # Настройка библиотеки
sudo ./10-setup-modules.sh       # Установка модулей
```

## 🔧 Технические характеристики

### Программное обеспечение
- **Drupal**: 11.x LTS (поддержка до 2029)
- **PHP**: 8.3 + необходимые расширения
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
/var/www/html/drupal/          # Drupal файлы
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
- URL: https://library.rtti.tj
- Пользователь: admin
- Пароль: RTTIAdmin2024!

## ✅ Проверка установки

```bash
# Проверка служб
systemctl status nginx
systemctl status postgresql
systemctl status redis-server
systemctl status php8.3-fpm

# Проверка сайта
curl -I https://library.rtti.tj

# Проверка логов
tail -f /var/log/nginx/error.log
```

## 🔧 Управление

### Drush CLI
```bash
cd /var/www/html/drupal
vendor/bin/drush status
vendor/bin/drush cache:rebuild
vendor/bin/drush user:login admin
vendor/bin/drush pm:enable module_name
```

### Composer
```bash
cd /var/www/html/drupal
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
cd /var/www/html/drupal
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
- **Email**: admin@rtti.tj
- **Документация**: [RTTI LMS Wiki](https://github.com/cheptura/LMS_Drupal/wiki)
- **Drupal.org**: https://www.drupal.org/docs

---

**Версия**: 1.0  
**Дата**: Сентябрь 2025  
**Автор**: RTTI Development Team
