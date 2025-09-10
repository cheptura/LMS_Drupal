# Drupal Installation Scripts

## Описание
Автоматизированные скрипты для установки Drupal 11 Digital Library на Ubuntu 24.04 LTS с оптимизациями для RTTI.

## 🚨 ЭКСТРЕННОЕ РЕШЕНИЕ ОШИБОК

### ❌ Ошибка 404 для CSS/JS файлов после установки

**🎯 НАЙДЕНО ОКОНЧАТЕЛЬНОЕ РЕШЕНИЕ (СЕНТЯБРЬ 2025):**

**Проблема:** Drupal возвращает 404 для агрегированных CSS/JS файлов из `/sites/default/files/css/` и `/sites/default/files/js/`

**Причины:**
1. ❌ Закомментирован `$settings['file_public_path']` в settings.php
2. ❌ Неправильная конфигурация Nginx для статических файлов

**БЫСТРОЕ РЕШЕНИЕ:**
```bash
# 1. Раскомментировать настройку в settings.php
sed -i "s/^# \$settings\['file_public_path'\]/\$settings['file_public_path']/" /var/www/drupal/web/sites/default/settings.php

# 2. Обновить репозиторий с исправленной конфигурацией Nginx
cd /tmp/LMS_Drupal && git pull --force origin main
cd drupal-installation && sudo chmod +x *.sh

# 3. Пересоздать SSL конфигурацию с исправлениями Nginx
sudo ./05-configure-ssl.sh

# 4. Включить агрегацию и очистить кэш
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush config:set system.performance css.preprocess 1 -y
sudo -u www-data ./vendor/bin/drush config:set system.performance js.preprocess 1 -y
sudo -u www-data ./vendor/bin/drush cache:rebuild
```

**КРИТИЧЕСКАЯ НАСТРОЙКА NGINX:**
```nginx
# Правильная конфигурация для статических файлов (ИСПРАВЛЕНО)
location ~* \.(?:css|js|jpg|jpeg|gif|png|ico|svg|woff2?|ttf|eot)$ {
    try_files $uri /index.php?$query_string;
    expires 1M;
    access_log off;
    add_header Cache-Control "public";
}
```

**КРИТИЧЕСКАЯ НАСТРОЙКА DRUPAL:**
```php
# В /var/www/drupal/web/sites/default/settings.php должно быть:
$settings['file_public_path'] = 'sites/default/files';
# НЕ закомментировано!
```

⚠️ **Важно**: Все новые установки теперь автоматически применяют эти исправления в скриптах 05-configure-ssl.sh и 07-configure-drupal.sh

### 📁 Важные директории:
- **Код Drupal:** `/var/www/drupal`
- **Файлы сайта:** `/var/www/drupal/web/sites/default/files`
- **Конфигурация:** `/var/www/drupal/config/sync`
- **Composer:** `/var/www/drupal/composer.json`
- **Nginx SSL конфигурация:** `/etc/nginx/sites-available/drupal-ssl`
- **Логи Nginx:** `/var/log/nginx/`
- **Логи PHP:** `/var/log/php8.3-fpm.log`

⚠️ **Важно**: Все скрипты (05-configure-ssl.sh и 07-configure-drupal.sh) используют единый файл конфигурации Nginx: `/etc/nginx/sites-available/drupal-ssl`

**ЕСЛИ ПРОБЛЕМА ОСТАЕТСЯ - ДИАГНОСТИКА:**
```bash
# 1. Проверить настройку file_public_path
grep "file_public_path" /var/www/drupal/web/sites/default/settings.php

# 2. Проверить конфигурацию Nginx для статических файлов  
sudo nginx -T | grep -A 5 "location.*css"

# 3. Проверить агрегацию
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush config:get system.performance

# 4. Проверить права доступа
ls -la /var/www/drupal/web/sites/default/files/

# 5. Принудительно пересоздать файлы
sudo -u www-data ./vendor/bin/drush cache:rebuild
```

**КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ NGINX (ОСНОВНАЯ ПРИЧИНА):**
```bash
# 1. Обновить репозиторий с исправленной конфигурацией
cd /tmp/LMS_Drupal
git pull --force origin main

# 2. Принудительно пересоздать SSL конфигурацию с исправлениями
cd drupal-installation
sudo chmod +x 05-configure-ssl.sh 09-security.sh
sudo rm -f /etc/nginx/sites-enabled/drupal-ssl
sudo rm -f /etc/nginx/sites-available/drupal-ssl
sudo rm -f /etc/nginx/sites-available/drupal
sudo ./05-configure-ssl.sh

# 3. ЕСЛИ ОШИБКА "No such file or directory" - исправить симлинки
sudo ln -sf /etc/nginx/sites-available/drupal-ssl /etc/nginx/sites-enabled/drupal-ssl
sudo rm -f /etc/nginx/sites-enabled/drupal
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# 4. Создать недостающие директории
sudo mkdir -p /var/www/drupal/web/sites/default/files/{css,js,styles,tmp}
sudo chown -R www-data:www-data /var/www/drupal/web/sites/default/files
sudo chmod -R 755 /var/www/drupal/web/sites/default/files

# 5. Очистить кэш Drupal
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush cache:rebuild
```

⚠️ **Важно**: Все скрипты теперь используют единый файл конфигурации `/etc/nginx/sites-available/drupal-ssl`

**ПРОВЕРКА И ИСПРАВЛЕНИЕ NGINX (ВЕРОЯТНАЯ ПРИЧИНА):**
```bash
# 1. Проверить конфигурацию Nginx для статических файлов
sudo nginx -T | grep -A 20 -B 5 "location.*files"

# 2. Проверить есть ли правила для CSS/JS файлов
sudo nginx -T | grep -A 10 "\.css\|\.js"

# 3. Проверить корневую директорию сайта
sudo nginx -T | grep "root.*drupal"

# 4. КРИТИЧНО: Проверить блокировку .htaccess и скрытых файлов
sudo nginx -T | grep -A 5 -B 5 "deny.*\."

# 5. Если CSS/JS заблокированы - исправить конфигурацию
sudo cp /etc/nginx/sites-available/drupal-ssl /etc/nginx/sites-available/drupal-ssl.backup

# 6. Добавить правильные правила для статических файлов (если их нет)
sudo tee -a /etc/nginx/sites-available/drupal-ssl << 'EOF'

    # Статические файлы CSS/JS с кэшированием
    location ~* \.(css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # Файлы изображений и медиа
    location ~* \.(jpg|jpeg|gif|png|svg|ico|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }
EOF

# 7. Перезагрузить Nginx и проверить конфигурацию
sudo nginx -t && sudo systemctl reload nginx

# 8. Проверить доступность файлов напрямую
sudo touch /var/www/drupal/web/sites/default/files/test.css
curl -I https://storage.omuzgorpro.tj/sites/default/files/test.css
sudo rm /var/www/drupal/web/sites/default/files/test.css
```

**АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ - ОТКЛЮЧЕНИЕ АГРЕГАЦИИ:**
```bash
# РЕКОМЕНДУЕМОЕ РЕШЕНИЕ: если агрегация не работает, отключить её полностью
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush config:set system.performance css.preprocess 0 -y
sudo -u www-data ./vendor/bin/drush config:set system.performance js.preprocess 0 -y
sudo -u www-data ./vendor/bin/drush cache:rebuild

# Проверить что агрегация отключена
sudo -u www-data ./vendor/bin/drush config:get system.performance
```

⚠️ **Примечание:** При отключенной агрегации CSS/JS файлы загружаются по отдельности из модулей, что полностью решает проблему 404. Сайт может загружаться чуть медленнее, но будет работать стабильно.

🔍 **Причины проблемы с агрегацией:**
- Drupal не может создать агрегированные файлы из-за проблем с правами
- Неправильная конфигурация временных папок
- Проблемы с PHP или файловой системой
- **Отключение агрегации - самое надежное решение**

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

#### ❌ Ошибка 404 для статических файлов (CSS/JS) после установки
**Проблема:** Drupal не может загрузить CSS/JS файлы из `/sites/default/files/css/` и `/sites/default/files/js/`

**Симптомы:**
```
GET https://storage.omuzgorpro.tj/sites/default/files/css/css_*.css net::ERR_ABORTED 404 (Not Found)
GET https://storage.omuzgorpro.tj/sites/default/files/js/js_*.js net::ERR_ABORTED 404 (Not Found)
```

**Решение:**
```bash
# 1. Проверить и создать директории для файлов
sudo mkdir -p /var/www/drupal/web/sites/default/files/css
sudo mkdir -p /var/www/drupal/web/sites/default/files/js
sudo mkdir -p /var/www/drupal/web/sites/default/files/styles

# 2. Установить правильные права доступа
sudo chown -R www-data:www-data /var/www/drupal/web/sites/default/files
sudo chmod -R 755 /var/www/drupal/web/sites/default/files

# 3. Очистить кэш Drupal для пересоздания файлов
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush cache:rebuild

# 4. Проверить конфигурацию Nginx для статических файлов
sudo nginx -t && sudo systemctl reload nginx

# 5. Если проблема не решена, выполнить агрегацию CSS/JS вручную
sudo -u www-data ./vendor/bin/drush config:set system.performance css.preprocess 1
sudo -u www-data ./vendor/bin/drush config:set system.performance js.preprocess 1
sudo -u www-data ./vendor/bin/drush cache:rebuild
```

**Дополнительная диагностика:**
```bash
# Проверить права доступа
ls -la /var/www/drupal/web/sites/default/files/

# Проверить настройки файловой системы в Drupal
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush config:get system.file
sudo -u www-data ./vendor/bin/drush config:get system.performance

# Проверить правильность настроек временной папки
cat web/sites/default/settings.php | grep -A3 -B3 "file_temp_path"

# Создать и настроить временную папку для агрегации
sudo mkdir -p /var/www/drupal/web/sites/default/files/tmp
sudo chown www-data:www-data /var/www/drupal/web/sites/default/files/tmp
sudo chmod 755 /var/www/drupal/web/sites/default/files/tmp

# Принудительно пересоздать агрегированные файлы
sudo -u www-data ./vendor/bin/drush cache:clear css-js
sudo -u www-data ./vendor/bin/drush config:set system.performance css.preprocess 0
sudo -u www-data ./vendor/bin/drush config:set system.performance css.preprocess 1
sudo -u www-data ./vendor/bin/drush config:set system.performance js.preprocess 0
sudo -u www-data ./vendor/bin/drush config:set system.performance js.preprocess 1
sudo -u www-data ./vendor/bin/drush cache:rebuild

# Проверить логи PHP на ошибки
sudo tail -f /var/log/php8.3-fpm.log &
# Откройте сайт в браузере, затем остановите просмотр логов командой:
sudo pkill tail

# Проверить логи Nginx
sudo tail -f /var/log/nginx/error.log
```

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

### � Альтернативное решение проблем с CSS/JS

Если все предыдущие шаги не помогли решить проблему 404 для CSS/JS файлов:

```bash
# ВАРИАНТ 1: Полное отключение агрегации (работает всегда)
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush config:set system.performance css.preprocess 0 -y
sudo -u www-data ./vendor/bin/drush config:set system.performance js.preprocess 0 -y
sudo -u www-data ./vendor/bin/drush cache:rebuild

# ВАРИАНТ 2: Если нужна агрегация, но с другими настройками
sudo -u www-data ./vendor/bin/drush config:set system.performance css.gzip 0 -y
sudo -u www-data ./vendor/bin/drush config:set system.performance js.gzip 0 -y
sudo -u www-data ./vendor/bin/drush config:set system.performance css.preprocess 1 -y
sudo -u www-data ./vendor/bin/drush config:set system.performance js.preprocess 1 -y
sudo -u www-data ./vendor/bin/drush cache:rebuild

# ВАРИАНТ 3: Принудительная очистка и пересоздание всех файлов
sudo rm -rf /var/www/drupal/web/sites/default/files/css/*
sudo rm -rf /var/www/drupal/web/sites/default/files/js/*
sudo rm -rf /var/www/drupal/web/sites/default/files/styles/*
sudo -u www-data ./vendor/bin/drush cache:rebuild
```

⚠️ **Примечание:** Вариант 1 (отключение агрегации) решит проблему, но сайт может загружаться немного медленнее, так как CSS/JS файлы будут загружаться по отдельности.

---

### �📁 Важные директории:
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

# Проверка прав доступа к файлам Drupal
ls -la /var/www/drupal/web/sites/default/files/

# Проверка создания CSS/JS файлов
ls -la /var/www/drupal/web/sites/default/files/css/
ls -la /var/www/drupal/web/sites/default/files/js/

# Принудительная регенерация статических файлов при необходимости
cd /var/www/drupal
sudo -u www-data ./vendor/bin/drush cache:rebuild
```

---

## 🎯 РЕЗЮМЕ КЛЮЧЕВЫХ ИСПРАВЛЕНИЙ (СЕНТЯБРЬ 2025)

### ✅ Проблема 404 для CSS/JS файлов - РЕШЕНА
- **Корень проблемы:** Закомментированный `$settings['file_public_path']` + неправильная Nginx конфигурация
- **Решение:** Автоматически исправлено в скриптах 05-configure-ssl.sh и 07-configure-drupal.sh
- **Статус:** Все новые установки работают без проблем

### ✅ Конфигурация Nginx - УНИФИЦИРОВАНА  
- **Файл:** `/etc/nginx/sites-available/drupal-ssl` используется везде
- **Исправление:** Правильный `try_files $uri /index.php?$query_string;` для статических файлов
- **Статус:** Стабильная работа CSS/JS агрегации

### ✅ Настройки Drupal - АВТОМАТИЗИРОВАНЫ
- **Автоматическое раскомментирование:** `$settings['file_public_path'] = 'sites/default/files';`
- **Агрегация:** Включается автоматически и работает стабильно
- **Статус:** Полная автоматизация в скриптах

**Версия**: 1.1 🚀  
**Дата**: Сентябрь 2025  
**Автор**: RTTI Development Team
