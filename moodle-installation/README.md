# Moodle 5.0+ LMS - Полная установка

Автоматическая установка Moodle Learning Management System для RTTI.

## 🎯 Целевой сервер

- **Домен**: lms.rtti.tj
- **IP**: 92.242.60.172
- **ОС**: Ubuntu Server 24.04 LTS
- **Версия**: Moodle 5.0+

## 🚀 Быстрая установка

### Одной командой
```bash
wget -O install-moodle.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-installation/install-moodle.sh
chmod +x install-moodle.sh
sudo ./install-moodle.sh
```

### Локальная установка
```bash
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/moodle-installation
chmod +x *.sh
sudo ./install-moodle.sh
```

## 📝 Пошаговая установка

Если нужен контроль над каждым этапом:

```bash
sudo ./01-prepare-system.sh      # Подготовка системы
sudo ./02-install-webserver.sh   # Nginx + PHP 8.2
sudo ./03-install-database.sh    # PostgreSQL 16
sudo ./04-install-cache.sh       # Redis
sudo ./05-configure-domain.sh    # Настройка домена
sudo ./06-install-ssl.sh         # SSL сертификаты
sudo ./07-download-moodle.sh     # Скачивание Moodle
sudo ./08-configure-moodle.sh    # Настройка и установка
sudo ./09-optimize-moodle.sh     # Оптимизация
sudo ./10-backup-setup.sh        # Настройка бэкапов
```

## 🔧 Технические характеристики

### Программное обеспечение
- **Moodle**: 5.0+ (Latest Stable)
- **PHP**: 8.2 + необходимые расширения
- **Database**: PostgreSQL 16
- **Web Server**: Nginx 1.24+
- **Cache**: Redis 7+
- **SSL**: Let's Encrypt

### Системные требования
- **CPU**: 4+ cores (рекомендуется 8)
- **RAM**: 16GB (рекомендуется 32GB)
- **Storage**: 200GB+ SSD
- **Network**: 1Gbps

## 📁 Структура после установки

```
/var/www/html/moodle/          # Moodle файлы
/var/moodledata/               # Данные Moodle
/root/moodle-credentials.txt   # Данные доступа
/etc/nginx/sites-available/    # Конфигурация Nginx
/etc/php/8.2/                 # Конфигурация PHP
```

## 🔑 Данные доступа

После установки данные сохранятся в:
- `/root/moodle-admin-credentials.txt` - Администратор
- `/root/moodle-db-credentials.txt` - База данных

**По умолчанию:**
- URL: https://lms.rtti.tj
- Пользователь: admin
- Пароль: RTTIAdmin2024!

## ✅ Проверка установки

```bash
# Проверка служб
systemctl status nginx
systemctl status postgresql
systemctl status redis-server
systemctl status php8.2-fpm

# Проверка сайта
curl -I https://lms.rtti.tj

# Проверка логов
tail -f /var/log/nginx/error.log
```

## 🔧 Управление

### Moodle CLI
```bash
cd /var/www/html/moodle
sudo -u www-data php admin/cli/maintenance.php --enable
sudo -u www-data php admin/cli/cron.php
sudo -u www-data php admin/cli/upgrade.php
```

### Обновления
```bash
./update-moodle.sh          # Обновление Moodle
./update-system.sh          # Обновление системы
```

### Резервное копирование
```bash
./backup-moodle.sh          # Создание бэкапа
./restore-moodle.sh         # Восстановление
```

## 🆘 Устранение проблем

### Частые проблемы
1. **Ошибка подключения к БД** - проверьте `/root/moodle-db-credentials.txt`
2. **403 Forbidden** - проверьте права доступа к файлам
3. **500 Error** - проверьте логи PHP и Nginx
4. **SSL проблемы** - перезапустите certbot

### Диагностика
```bash
./diagnose-moodle.sh         # Полная диагностика
./fix-permissions.sh         # Исправление прав
./reset-moodle.sh           # Сброс к начальным настройкам
```

## 📊 Мониторинг

После установки настройте мониторинг:
```bash
cd ../monitoring-installation
sudo ./install-monitoring.sh
```

## 📞 Поддержка

- **GitHub**: https://github.com/cheptura/LMS_Drupal/issues
- **Email**: admin@rtti.tj
- **Документация**: [RTTI LMS Wiki](https://github.com/cheptura/LMS_Drupal/wiki)

---

**Версия**: 1.0  
**Дата**: Сентябрь 2025  
**Автор**: RTTI Development Team
