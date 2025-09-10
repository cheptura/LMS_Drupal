# Drupal Installation Scripts

## Описание
Автоматизированные скрипты для установки Drupal 11 Digital Library на Ubuntu 24.04 LTS с оптимизациями для RTTI.

## 🚨 ЭКСТРЕННОЕ РЕШЕНИЕ ОШИБОК

### ❌ Ошибка "invalid number of arguments in try_files directive"
**Эта ошибка возникает из-за неправильного экранирования переменных Nginx.**

**Диагностика:**
```bash
# Проверить текущую проблему:
sudo cat /etc/nginx/sites-enabled/drupal-ssl | grep -n "try_files"
# Неправильно: try_files  /index.php?;
# Правильно: try_files $uri /index.php?$query_string;
```

**Решение:**
```bash
# 1. Принудительное обновление с исправлениями
cd /tmp/LMS_Drupal && git reset --hard HEAD && git pull --force origin main

# 2. Полная очистка проблемных конфигураций Nginx
sudo rm -f /etc/nginx/sites-enabled/drupal-ssl
sudo rm -f /etc/nginx/sites-available/drupal-ssl  
sudo rm -f /etc/nginx/sites-available/drupal-temp
sudo systemctl reload nginx

# 3. Перезапуск SSL с исправленными файлами
cd drupal-installation && sudo chmod +x *.sh
sudo ./05-configure-ssl.sh
```

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

⚠️ **КРИТИЧНО для try_files:** Если получите ошибку "invalid number of arguments in try_files directive", ОБЯЗАТЕЛЬНО обновите репозиторий:
```bash
cd /tmp/LMS_Drupal && git pull --force origin main
cd drupal-installation && sudo chmod +x *.sh
# Если ошибка повторяется, принудительно очистите Nginx конфигурацию:
sudo rm -f /etc/nginx/sites-enabled/drupal-ssl
sudo rm -f /etc/nginx/sites-available/drupal-ssl
sudo rm -f /etc/nginx/sites-available/drupal-temp
sudo ./05-configure-ssl.sh  # Перезапуск SSL с исправленными файлами
```

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

## Поддержка и troubleshooting

### 🚨 Распространенные проблемы:

#### Ошибка конфигурации Nginx
```bash
# Если nginx -t показывает ошибки синтаксиса:
sudo nginx -t                                    # Проверка конфигурации
sudo nginx -T                                    # Показать всю конфигурацию

# Если ошибка "invalid number of arguments in try_files directive":
# КРИТИЧНО: Обновите репозиторий до последней версии и перезапустите SSL:
cd /tmp/LMS_Drupal && git pull --force origin main
cd drupal-installation && sudo chmod +x *.sh
# Если ошибка повторяется, принудительно очистите Nginx конфигурацию:
sudo rm -f /etc/nginx/sites-enabled/drupal-ssl
sudo rm -f /etc/nginx/sites-available/drupal-ssl  
sudo rm -f /etc/nginx/sites-available/drupal-temp
sudo systemctl reload nginx  # Перезагрузка без проблемной конфигурации
sudo ./05-configure-ssl.sh  # Полный перезапуск настройки SSL

# Если ошибка "location directive is not allowed here":
# Обновите репозиторий до последней версии:
cd /tmp/LMS_Drupal && git pull --force origin main
cd drupal-installation && sudo chmod +x *.sh

# Если проблема в drupal-static.conf (старые версии):
sudo rm -f /etc/nginx/conf.d/drupal-static.conf  # Удаление проблемного файла
sudo systemctl reload nginx                      # Перезагрузка Nginx
```

## Системные требования
- ✅ **ОС:** Ubuntu 24.04 LTS
- ✅ **RAM:** Минимум 4GB (рекомендуется 8GB)
- ✅ **Диск:** 20GB свободного места (рекомендуется 50GB)
- ✅ **Сеть:** Доступ к интернету для загрузки пакетов
- ✅ **Права:** root или sudo доступ
- ✅ **PHP:** 8.3+ с расширениями (gd, curl, dom, simplexml, etc.)

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

---

**Версия**: 1.0  
**Дата**: Сентябрь 2025  
**Автор**: RTTI Development Team
