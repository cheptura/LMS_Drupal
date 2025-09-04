# Moodle Installation Scripts

## Описание
Автоматизированные скрипты для установки Moodle 5.0+ на Ubuntu 24.04 LTS с оптимизациями для RTTI.

## 🚀 QUICK_INSTALL
```bash
# Быстрая установка (одной командой)
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/moodle-installation
sudo chmod +x install-all.sh && sudo ./install-all.sh
```

## Состав скриптов

### 📦 Основные установочные скрипты:
1. **01-system-update.sh** - Обновление системы и базовые пакеты
2. **02-install-nginx.sh** - Установка и настройка Nginx веб-сервера
3. **03-install-php.sh** - Установка PHP 8.3 с модулями для Moodle
4. **04-install-postgresql.sh** - Установка PostgreSQL 16 СУБД
5. **05-configure-database.sh** - Создание базы данных и пользователя
6. **06-download-moodle.sh** - Загрузка последней версии Moodle 5.0
7. **07-configure-moodle.sh** - Настройка конфигурации config.php
8. **08-configure-nginx-site.sh** - Настройка виртуального хоста
9. **09-install-ssl.sh** - Установка SSL сертификатов Let's Encrypt
10. **10-final-setup.sh** - Финальная настройка и оптимизация

### �️ Утилиты администрирования:
- **update-moodle.sh** - Обновление Moodle до новых версий
- **backup-moodle.sh** - Создание полных резервных копий
- **restore-moodle.sh** - Восстановление из резервных копий
- **diagnose-moodle.sh** - Полная диагностика системы Moodle

### 📋 Автоматическая установка:
- **install-all.sh** - Полная автоматическая установка всех компонентов

## Поэтапная установка
```bash
# Подготовка
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/moodle-installation
sudo chmod +x *.sh

# Поэтапное выполнение
sudo ./01-system-update.sh     # Обновление системы
sudo ./02-install-nginx.sh     # Веб-сервер
sudo ./03-install-php.sh       # PHP платформа
sudo ./04-install-postgresql.sh # База данных
sudo ./05-configure-database.sh # Настройка БД
sudo ./06-download-moodle.sh   # Загрузка Moodle
sudo ./07-configure-moodle.sh  # Конфигурация
sudo ./08-configure-nginx-site.sh # Веб-сервер
sudo ./09-install-ssl.sh       # SSL защита
sudo ./10-final-setup.sh       # Финализация
```

## Администрирование

### 🔍 Диагностика системы
```bash
sudo ./diagnose-moodle.sh  # Полная проверка всех компонентов
systemctl status nginx postgresql php8.3-fpm  # Статус сервисов
```

### � Резервное копирование
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

### � Учетные данные:
- Данные администратора выводятся в конце установки
- Сохраняются в файле `/var/log/moodle-install.log`

### � Важные директории:
- **Код Moodle:** `/var/www/html/moodle`
- **Данные:** `/var/moodledata`
- **Конфигурация:** `/var/www/html/moodle/config.php`
- **Логи Nginx:** `/var/log/nginx/`
- **Логи PHP:** `/var/log/php8.3-fpm.log`

## Поддержка и troubleshooting
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
