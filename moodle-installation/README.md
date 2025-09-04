# Moodle Installation Scripts

## Описание
Автоматизированные скрипты для установки Moodle 5.0+ на Ubuntu 24.04 с оптимизациями для RTTI.

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
2. **02-install-webserver.sh** - Установка и настройка Nginx + PHP 8.2
3. **03-install-database.sh** - Установка PostgreSQL 16 СУБД
4. **04-install-cache.sh** - Установка и настройка Redis
5. **05-configure-ssl.sh** - Настройка SSL сертификатов
6. **06-download-moodle.sh** - Загрузка последней версии Moodle 5.0
7. **07-configure-moodle.sh** - Настройка конфигурации Moodle
8. **08-install-moodle.sh** - Установка Moodle в систему
9. **09-post-install.sh** - Пост-установочная настройка
10. **10-final-check.sh** - Финальная проверка и валидация

### 🛠️ Утилиты администрирования:
- **update-moodle.sh** - Обновление Moodle до новых версий
- **backup-moodle.sh** - Создание полных резервных копий
- **restore-moodle.sh** - Восстановление из резервных копий
- **diagnose-moodle.sh** - Полная диагностика системы Moodle
- **fix-config-issues.sh** - Исправление проблем конфигурации
- **diagnose-php-fpm.sh** - Диагностика и исправление PHP-FPM
- **fix-php-versions.sh** - Исправление проблем с версиями PHP (устанавливает только PHP 8.2)

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
sudo ./02-install-webserver.sh   # Установка Nginx и PHP 8.2
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
systemctl status nginx postgresql php8.2-fpm  # Статус сервисов
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
- **Код Moodle:** `/var/www/html/moodle`
- **Данные:** `/var/moodledata`
- **Конфигурация:** `/var/www/html/moodle/config.php`
- **Логи Nginx:** `/var/log/nginx/`
- **Логи PHP:** `/var/log/php8.2-fpm.log`

## Поддержка и troubleshooting

### 🚨 Распространенные проблемы и решения:

#### Ошибка "Command line scripts must define CLI_SCRIPT"
```bash
# Если получаете эту ошибку при выполнении 07-configure-moodle.sh
# Скрипт уже исправлен для корректной проверки подключений

# Проверьте вручную подключение к базе:
sudo -u postgres psql -d moodle -c "SELECT version();"

# Проверьте Redis:
redis-cli ping
```

#### Ошибка "php8.2-fpm.service not found" или проблемы с версиями PHP
```bash
# НОВАЯ ПРОБЛЕМА: Установилась PHP 8.4 вместо PHP 8.2
# Проявления: "database driver problem detected", "PGSQL extension is not loaded"
# Причина: репозиторий ppa:ondrej/php автоматически устанавливает PHP 8.4

# Решение 1: Полное исправление версий PHP - запустите:
sudo ./fix-php-versions.sh

# Решение 2: Используйте исправленный скрипт установки:
sudo ./02-install-webserver.sh  # Теперь гарантированно ставит только PHP 8.2

# Это полностью очистит все версии PHP и установит только PHP 8.2
# с всеми необходимыми расширениями для Moodle

# Проверка установленной версии:
php --version                    # Должна показать PHP 8.2.x
dpkg -l | grep php8.2           # Список установленных пакетов PHP 8.2
dpkg -l | grep -E "php[0-9]" | grep -v php8.2  # Проверка других версий

# Или определите версию PHP и исправьте вручную:
php --version
sudo systemctl start php8.1-fpm  # или другую доступную версию
sudo systemctl enable php8.1-fpm

# Запустите диагностику PHP-FPM:
sudo ./diagnose-php-fpm.sh
```

#### Ошибка "database driver problem detected" (PGSQL extension)
```bash
# Если PHP расширение PostgreSQL отсутствует:
sudo ./fix-php-versions.sh  # Это установит все необходимые расширения

# Или установите вручную:
sudo apt install -y php8.2-pgsql
sudo systemctl restart php8.2-fpm
```

#### Общие проблемы конфигурации
```bash
# Автоматическая диагностика и исправление:
sudo ./fix-config-issues.sh

# Проверка всех сервисов:
sudo ./diagnose-moodle.sh
```

### 📝 Проверка логов при проблемах
```bash
# Проверка логов при проблемах
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/php8.2-fpm.log
sudo journalctl -u nginx -f

# Перезапуск сервисов
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
sudo systemctl restart postgresql
```

## 📊 Мониторинг
После установки мониторинга (папка `monitoring-installation`):
- **Grafana:** http://ваш-ip:3000 (admin/admin)
- **Prometheus:** http://ваш-ip:9090
- **Alertmanager:** http://ваш-ip:9093

## 🏢 RTTI Информация
- **Проект:** LMS для Республиканского Технологического Техникума Информатизации
- **Сервер:** lms.rtti.tj
- **GitHub:** https://github.com/cheptura/LMS_Drupal
- **Автор:** cheptura

## 📝 Лицензия
Этот проект предназначен для использования в RTTI и распространяется под лицензией MIT.
