# Пошаговое руководство по установке LMS системы RTTI
## Moodle 5.0+ + Drupal 11 с облачным развертыванием и NAS интеграцией

**Версия документации**: 3.1 (обновлено для Moodle 5.0+ и решения проблем установки)  
**Дата обновления**: Сентябрь 2025  
**Серверы RTTI**: lms.rtti.tj (92.242.60.172), library.rtti.tj (92.242.61.204)

## Стратегия развертывания

Данное руководство предлагает **облако-первый подход** с последующей миграцией в продакшн:

1. **Этап 1**: Быстрое развертывание в облаке для тестирования
2. **Этап 2**: Тестирование и настройка функций  
3. **Этап 3**: Миграция в продакшн с NAS интеграцией

Альтернативно можно сразу развернуть в продакшн (см. раздел "Прямая продакшн установка").

## 🚨 Важные обновления версии 3.1

### Новые возможности установки
- ✅ **Автоматическое решение конфликтов базы данных**
- ✅ **Скрипт полной переустановки**
- ✅ **Улучшенная обработка ошибок**
- ✅ **Интерактивная очистка данных**
- ✅ **Конкретные серверы RTTI готовы**

### Решение проблем установки
- 🔧 "ERROR: database 'moodle' already exists" - автоматически решается
- 🔧 Неудачные установки - полная автоматическая очистка
- 🔧 Конфликты файлов - умная перезапись
- 🔧 Права доступа - автоматическая настройка

## Предварительные требования

### Системные требования (обновлено для v5.0+)
- **Готовые серверы RTTI**:
  - **lms.rtti.tj (92.242.60.172)**: Moodle 5.0+ + Мониторинг
  - **library.rtti.tj (92.242.61.204)**: Drupal 11 библиотека
- **Облачные серверы** (альтернативно): 2 инстанса (Ubuntu Server 24.04 LTS)
  - Moodle: 4-8 CPU cores, 16-32GB RAM, 200GB+ SSD
  - Drupal: 4-6 CPU cores, 8-16GB RAM, 500GB+ SSD
- **Продакшн серверы**: 2 физических/виртуальных сервера
  - Аналогичные характеристики + NAS интеграция
- **NAS сервер**: CIFS/SMB 3.0+, от 2TB, RAID 6+

### Подготовка доменов
1. **Домены RTTI готовы**:
   - ✅ `lms.rtti.tj` - для Moodle 5.0+ LMS
   - ✅ `library.rtti.tj` - для Drupal 11 библиотеки
2. DNS записи настроены: 92.242.60.172, 92.242.61.204
3. SSL сертификаты автоматически настраиваются через Let's Encrypt
4. Домены резолвятся корректно

---

## МЕТОД 1: Быстрая установка на серверах RTTI (РЕКОМЕНДУЕТСЯ)

### Этап 1: Установка Moodle 5.0+ на lms.rtti.tj (92.242.60.172)

#### 1.1 Подключение к серверу
```bash
# Подключение по SSH
ssh root@92.242.60.172
# или
ssh root@lms.rtti.tj
```

#### 1.2 Обычная установка Moodle
```bash
# Скачивание и запуск скрипта установки
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/install-moodle-cloud.sh
chmod +x install-moodle-cloud.sh

# Запуск установки
sudo ./install-moodle-cloud.sh
```

#### 1.3 Переустановка при конфликтах базы данных

**Если получили ошибку "ERROR: database 'moodle' already exists":**

##### Вариант A: Автоматическая очистка (рекомендуется)
```bash
sudo ./install-moodle-cloud.sh cleanup
```

##### Вариант B: Полная переустановка
```bash
# Скачать скрипт полной переустановки
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/reinstall-moodle.sh
chmod +x reinstall-moodle.sh

# Запустить полную переустановку (потребует подтверждения)
sudo ./reinstall-moodle.sh
```

##### Вариант C: Ручная очистка
```bash
# Остановить службы
sudo systemctl stop nginx

# Удалить базу данных
sudo -u postgres psql -c "DROP DATABASE IF EXISTS moodle;"
sudo -u postgres psql -c "DROP USER IF EXISTS moodleuser;"

# Удалить файлы
sudo rm -rf /var/www/html/moodle
sudo rm -rf /var/moodledata
sudo rm -f /root/moodle-credentials.txt

# Запустить установку
sudo ./install-moodle-cloud.sh
```

#### 1.4 Что произойдет автоматически
- ✅ Обнаружение облачного провайдера (если применимо)
- ✅ Установка PHP 8.2, PostgreSQL 16, Redis 7, Nginx
- ✅ Скачивание и настройка Moodle 5.0+ (latest stable)
- ✅ Настройка SSL сертификатов Let's Encrypt для lms.rtti.tj
- ✅ Конфигурация производительности и безопасности
- ✅ Настройка локального резервного копирования
- ✅ Установка системы мониторинга

#### 1.5 Проверка установки
```bash
# Проверить статус служб
sudo systemctl status nginx postgresql redis

# Проверить логи
sudo tail -f /var/log/nginx/access.log

# Доступ к Moodle
# Браузер: https://lms.rtti.tj
# Учетные данные сохранены в: /root/moodle-admin-credentials.txt
```

### Этап 2: Установка Drupal 11 на library.rtti.tj (92.242.61.204)

#### 2.1 Подключение к серверу библиотеки
```bash
# Подключение по SSH
ssh root@92.242.61.204
# или
ssh root@library.rtti.tj
```

#### 2.2 Установка Drupal 11
```bash
# Скачивание и запуск скрипта установки
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/install-drupal-cloud.sh
chmod +x install-drupal-cloud.sh

# Запуск установки
sudo ./install-drupal-cloud.sh
```

#### 2.3 Что произойдет автоматически
- ✅ Установка PHP 8.3 и современных зависимостей
- ✅ Создание проекта Drupal 11 через Composer
- ✅ Установка библиотечных модулей (Views, REST API, Search API)
- ✅ Настройка поиска и API интеграций
- ✅ Конфигурация Redis кэширования
- ✅ SSL сертификаты для library.rtti.tj
- ✅ Настройка безопасности и производительности

#### 2.4 Проверка установки
```bash
# Проверить статус
sudo systemctl status nginx postgresql

# Доступ к Drupal
# Браузер: https://library.rtti.tj
# Учетные данные в: /root/drupal-admin-credentials.txt
```

### Этап 3: Установка системы мониторинга

#### 3.1 Prometheus + Grafana на lms.rtti.tj (рекомендуется)
```bash
# На сервере lms.rtti.tj
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring/install-prometheus-stack.sh
chmod +x install-prometheus-stack.sh
sudo ./install-prometheus-stack.sh
```

**Доступ к мониторингу:**
- Prometheus: http://lms.rtti.tj:9090
- Grafana: http://lms.rtti.tj:3000 (admin/admin)
- AlertManager: http://lms.rtti.tj:9093

#### 3.2 Агенты мониторинга на library.rtti.tj
```bash
# На сервере library.rtti.tj
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring/install-monitoring-agents.sh
chmod +x install-monitoring-agents.sh
sudo ./install-monitoring-agents.sh
```

#### 3.3 Альтернативный Zabbix (опционально)
```bash
# На сервере lms.rtti.tj вместо Prometheus
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring/install-zabbix.sh
chmod +x install-zabbix.sh
sudo ./install-zabbix.sh

# Доступ: http://lms.rtti.tj/zabbix
```

---

## МЕТОД 2: Облачное развертывание (для тестирования)

### Этап 1: Создание облачных инстансов

#### 1.1 Выбор облачного провайдера
- **AWS**: EC2 instances (t3.large для Moodle, t3.medium для Drupal)
- **DigitalOcean**: Droplets (4GB+ для начала)  
- **Google Cloud**: Compute Engine instances
- **Azure**: Virtual Machines

#### 1.2 Базовая настройка облачного сервера

```bash
# Обновление Ubuntu 24.04 LTS
sudo apt update && sudo apt upgrade -y

# Установка базовых утилит
sudo apt install -y curl wget git unzip htop

# Настройка временной зоны
sudo timedatectl set-timezone Asia/Dushanbe

# Настройка файрвола (основные порты откроются автоматически скриптами)
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
```

### Этап 2: Автоматическая установка Moodle 5.0+ в облаке

```bash
# Скачивание и запуск скрипта установки
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/install-moodle-cloud.sh
chmod +x install-moodle-cloud.sh

# Запуск установки (следуйте инструкциям на экране)
sudo ./install-moodle-cloud.sh

# При проблемах с базой данных
sudo ./install-moodle-cloud.sh cleanup
```

**Что произойдет автоматически:**
- Обнаружение облачного провайдера
- Установка PHP 8.2, PostgreSQL 16, Redis 7, Nginx
- Скачивание и настройка Moodle 5.0+ (latest stable)
- Настройка SSL сертификатов Let's Encrypt
- Конфигурация производительности и безопасности
- Настройка облачного резервного копирования
- Установка мониторинга

### Этап 3: Автоматическая установка Drupal 11 в облаке

```bash
# На втором облачном сервере
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/install-drupal-cloud.sh
chmod +x install-drupal-cloud.sh

# Запуск установки
sudo ./install-drupal-cloud.sh
```

**Что произойдет автоматически:**
- Установка PHP 8.3 и современных зависимостей
- Создание проекта Drupal 11 через Composer
- Установка библиотечных модулей
- Настройка поиска и API
- Конфигурация Redis кэширования
- SSL и безопасность
- Интеграция с CDN (если доступно)

### Этап 4: Тестирование облачной среды

После установки обеих систем:

1. **Проверьте доступность:**
   - Moodle: https://your-cloud-domain.com
   - Drupal: https://your-library-domain.com

2. **Протестируйте основные функции:**
   - Создание курса в Moodle
   - Загрузка контента в Drupal
   - Регистрация тестовых пользователей
   - Проверка производительности

3. **Настройте интеграции:**
   - SSO между системами
   - API связи
---

## 🔧 Устранение неполадок

### Проблемы установки

#### "ERROR: database 'moodle' already exists"
Самая частая проблема при повторной установке.

**Автоматическое решение (рекомендуется):**
```bash
sudo ./install-moodle-cloud.sh cleanup
```

**Полная переустановка:**
```bash
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/reinstall-moodle.sh
chmod +x reinstall-moodle.sh
sudo ./reinstall-moodle.sh
```

**Ручная очистка:**
```bash
sudo -u postgres psql -c "DROP DATABASE IF EXISTS moodle;"
sudo -u postgres psql -c "DROP USER IF EXISTS moodleuser;"
sudo rm -rf /var/www/html/moodle /var/moodledata
sudo rm -f /root/moodle-credentials.txt
sudo ./install-moodle-cloud.sh
```

#### Ошибки загрузки Moodle
**Проблема**: 404 ошибка при скачивании Moodle 5.0.2
```bash
# Скрипт автоматически использует fallback URL:
# https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz
# Если проблема продолжается, проверьте интернет-соединение
curl -I https://download.moodle.org/download.php/stable500/moodle-latest-500.tgz
```

#### Проблемы с SSL сертификатами
```bash
# Проверить статус SSL
sudo certbot certificates

# Обновить сертификаты
sudo certbot renew --dry-run

# Перезагрузить Nginx
sudo systemctl reload nginx
```

#### Ошибки PHP/Nginx
```bash
# Проверить логи
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/php8.2-fpm.log

# Перезапустить службы
sudo systemctl restart nginx php8.2-fpm

# Проверить конфигурацию
sudo nginx -t
sudo php-fpm8.2 -t
```

#### Проблемы с правами доступа
```bash
# Moodle
sudo chown -R www-data:www-data /var/www/html/moodle
sudo chown -R www-data:www-data /var/moodledata
sudo chmod -R 755 /var/www/html/moodle
sudo chmod -R 777 /var/moodledata

# Drupal
sudo chown -R www-data:www-data /var/www/html/drupal
sudo chmod -R 755 /var/www/html/drupal
sudo chmod -R 777 /var/www/html/drupal/sites/default/files
```

#### Проблемы с базой данных PostgreSQL
```bash
# Проверить статус
sudo systemctl status postgresql

# Перезапустить PostgreSQL
sudo systemctl restart postgresql

# Подключиться к базе данных
sudo -u postgres psql

# Проверить существующие базы данных
sudo -u postgres psql -l

# Проверить пользователей
sudo -u postgres psql -c "\du"
```

### Мониторинг и диагностика

#### Системные ресурсы
```bash
# Использование CPU и памяти
htop

# Дисковое пространство
df -h

# Свободная память
free -m

# Сетевые подключения
netstat -tulpn
```

#### Логи приложений
```bash
# Nginx логи
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# PostgreSQL логи
sudo tail -f /var/log/postgresql/postgresql-16-main.log

# Системные логи
sudo journalctl -f
```

#### Проверка служб
```bash
# Статус всех ключевых служб
sudo systemctl status nginx postgresql redis php8.2-fpm

# Автозапуск служб
sudo systemctl is-enabled nginx postgresql redis php8.2-fpm
```

---

## МЕТОД 3: Продакшн развертывание с NAS

### Этап 1: Подготовка NAS сервера

#### 1.1 Настройка разделов NAS
```bash
# Создайте разделы на NAS:
# /moodle-files - для данных Moodle
# /drupal-files - для файлов Drupal  
# /backups - для резервных копий
# /monitoring - для данных мониторинга
```

#### 1.2 Настройка пользователей NAS
```bash
# На NAS создать пользователей:
# - moodleuser (доступ к /moodle-files, /backups)
# - drupaluser (доступ к /drupal-files, /backups)
# - backupuser (доступ ко всем разделам)
# - monitoruser (доступ к /monitoring)
```

#### 1.3 Проверка подключения к NAS
```bash
# Тест CIFS/SMB подключения
sudo apt install -y cifs-utils
sudo mkdir /mnt/test
sudo mount -t cifs //NAS_IP/moodle-files /mnt/test -o username=moodleuser,password=***
ls /mnt/test
sudo umount /mnt/test
```

### Этап 2: Продакшн установка Moodle с NAS

```bash
# На продакшн сервере lms.rtti.tj
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/production-deployment/install-moodle-production.sh
chmod +x install-moodle-production.sh

# Настройте переменные NAS в скрипте или экспортируйте:
export NAS_HOST="your-nas-ip"
export NAS_MOODLE_SHARE="/moodle-files"
export NAS_BACKUP_SHARE="/backups"
export NAS_USER="moodleuser"
export NAS_PASS="your-password"

# Запуск установки с NAS интеграцией
sudo ./install-moodle-production.sh
```

### Этап 3: Продакшн установка Drupal с NAS

```bash
# На продакшн сервере library.rtti.tj
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/production-deployment/install-drupal-production.sh
chmod +x install-drupal-production.sh

# Настройка переменных NAS
export NAS_HOST="your-nas-ip"
export NAS_DRUPAL_SHARE="/drupal-files"
export NAS_BACKUP_SHARE="/backups"
export NAS_USER="drupaluser"
export NAS_PASS="your-password"

# Запуск установки
sudo ./install-drupal-production.sh
```

### Этап 4: Миграция данных из облака

```bash
# Скрипт миграции облако → продакшн
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/migration-tools/cloud-to-production.sh
chmod +x cloud-to-production.sh

# Настройка параметров миграции
export CLOUD_MOODLE_HOST="cloud-moodle-ip"
export CLOUD_DRUPAL_HOST="cloud-drupal-ip"
export PROD_MOODLE_HOST="92.242.60.172"
export PROD_DRUPAL_HOST="92.242.61.204"

# Запуск миграции
sudo ./cloud-to-production.sh
```

---

## 📊 Настройка интеграций

### SSO интеграция между Moodle и Drupal

#### 1. Установка модулей интеграции
```bash
# На сервере Moodle
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-integration/moodle_drupal_integration.php
sudo cp moodle_drupal_integration.php /var/www/html/moodle/local/

# На сервере Drupal
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-integration/drupal_moodle_integration.module
sudo cp drupal_moodle_integration.module /var/www/html/drupal/web/modules/custom/
```

#### 2. Настройка API ключей
```bash
# Генерация общего секретного ключа
openssl rand -hex 32

# Настройка в Moodle: Администрирование → Плагины → Локальные плагины
# Настройка в Drupal: Расширения → Конфигурация модулей
```

### API интеграция

#### 1. Настройка REST API в Drupal
```bash
# Включение модулей REST
sudo -u www-data drush en rest serialization hal jsonapi -y

# Настройка прав доступа
sudo -u www-data drush config:set rest.settings bc_entity_resource_permissions true -y
```

#### 2. Настройка веб-сервисов в Moodle
```bash
# Через веб-интерфейс:
# Администрирование → Плагины → Веб-сервисы → Обзор
# Включить веб-сервисы → Включить протоколы → REST
```

---

## 📋 Послеустановочная настройка

### Безопасность

#### 1. Настройка файрвола
```bash
# Moodle сервер (lms.rtti.tj)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 3000/tcp  # Grafana
sudo ufw enable

# Drupal сервер (library.rtti.tj)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

#### 2. Настройка Fail2ban
```bash
# Установка на обоих серверах
sudo apt install -y fail2ban

# Настройка для Nginx
sudo tee /etc/fail2ban/jail.local <<EOF
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

sudo systemctl restart fail2ban
```

### Производительность

#### 1. Настройка кэширования Redis
```bash
# Проверка Redis
redis-cli ping

# Мониторинг Redis
redis-cli monitor
```

#### 2. Оптимизация PostgreSQL
```bash
# Настройка PostgreSQL для производительности
sudo tee -a /etc/postgresql/16/main/postgresql.conf <<EOF
# Настройки производительности
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
EOF

sudo systemctl restart postgresql
```

### Резервное копирование

#### 1. Настройка автоматических бэкапов
```bash
# На каждом сервере
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/production-deployment/nas-backup.sh
chmod +x nas-backup.sh

# Добавление в cron
sudo crontab -e
# Добавить строки:
# 0 2 * * * /path/to/nas-backup.sh daily
# 0 3 * * 0 /path/to/nas-backup.sh weekly  
# 0 4 1 * * /path/to/nas-backup.sh monthly
```

#### 2. Проверка бэкапов
```bash
# Список бэкапов на NAS
ls -la //NAS_IP/backups/

# Тест восстановления (на тестовой среде)
./nas-backup.sh restore latest
```

---

## ✅ Финальная проверка

### Checklist завершения установки

#### Moodle (lms.rtti.tj)
- [ ] Сайт доступен по https://lms.rtti.tj
- [ ] SSL сертификат установлен и валиден
- [ ] Административный доступ работает
- [ ] Создание тестового курса работает
- [ ] Регистрация пользователей работает
- [ ] Мониторинг доступен и собирает метрики
- [ ] Резервное копирование настроено

#### Drupal (library.rtti.tj)
- [ ] Сайт доступен по https://library.rtti.tj
- [ ] SSL сертификат установлен и валиден
- [ ] Административный доступ работает
- [ ] Загрузка контента работает
- [ ] Поиск функционирует
- [ ] API доступен для интеграций
- [ ] Агенты мониторинга работают

#### Интеграции
- [ ] SSO между системами работает
- [ ] API интеграция настроена
- [ ] Синхронизация пользователей работает
- [ ] Единая система авторизации функционирует

#### Мониторинг и безопасность
- [ ] Prometheus собирает метрики с обоих серверов
- [ ] Grafana отображает дашборды
- [ ] Alerting настроен и работает
- [ ] Файрвол настроен на обоих серверах
- [ ] Fail2ban защищает от атак
- [ ] Логи ротируются корректно

#### Бэкапы и восстановление
- [ ] NAS подключен и доступен
- [ ] Автоматические бэкапы работают
- [ ] Процедура восстановления протестирована
- [ ] Бэкапы хранятся в соответствии с политикой

---

## 📞 Поддержка и дополнительные ресурсы

### Документация проекта
- **GitHub Repository**: https://github.com/cheptura/LMS_Drupal
- **Issues & Bug Reports**: https://github.com/cheptura/LMS_Drupal/issues
- **Technical Requirements**: [technical-requirements.md](technical-requirements.md)
- **Troubleshooting Guide**: [troubleshooting.md](troubleshooting.md)

### Контакты RTTI
- **Техническая поддержка**: tech@rtti.tj
- **Администратор системы**: admin@rtti.tj  
- **Поддержка пользователей**: support@rtti.tj

### Полезные команды для администрирования

#### Быстрая диагностика
```bash
# Проверка всех ключевых служб
systemctl status nginx postgresql redis php8.2-fpm

# Проверка дискового пространства
df -h

# Проверка памяти
free -m

# Проверка сетевых подключений
netstat -tulpn | grep -E "(80|443|5432|6379)"

# Проверка логов за последний час
journalctl --since "1 hour ago" | grep -E "(error|ERROR|fail|FAIL)"
```

#### Управление службами
```bash
# Перезапуск веб-стека
sudo systemctl restart nginx php8.2-fpm

# Перезапуск баз данных
sudo systemctl restart postgresql redis

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Обновление SSL сертификатов
sudo certbot renew
```

---

**Последнее обновление**: Сентябрь 2025  
**Версия руководства**: 3.1  
**Совместимость**: Moodle 5.0+, Drupal 11, Ubuntu 24.04 LTS  
**Статус**: Готово к продакшн развертыванию

2. **Настройте пользователей NAS:**
   ```bash
   # На NAS (пример для Synology/QNAP)
   # Создать пользователей: moodleuser, drupaluser, backupuser
   # Настроить права доступа к соответствующим папкам
   ```

3. **Проверьте CIFS/SMB подключение:**
   ```bash
   # Тест с продакшн сервера
   sudo apt install -y cifs-utils
   sudo mkdir /mnt/test
   sudo mount -t cifs //NAS_IP/moodle-files /mnt/test -o username=moodleuser
   ```

#### 5.2 Подготовка продакшн серверов

```bash
# На каждом продакшн сервере
sudo apt update && sudo apt upgrade -y
sudo apt install -y cifs-utils nfs-common curl wget git

# Настройка временной зоны
sudo timedatectl set-timezone Asia/Dushanbe

# Создание точек монтирования для NAS
sudo mkdir -p /mnt/nas
```

### Этап 6: Автоматическая миграция

```bash
# На продакшн сервере (желательно единая машина для начала миграции)
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/migration-tools/cloud-to-production.sh
chmod +x cloud-to-production.sh

# Запуск миграции (следуйте инструкциям)
sudo ./cloud-to-production.sh
```

**Процесс миграции включает:**
1. Создание полных бэкапов облачных систем
2. Скачивание данных на продакшн сервер
3. Настройка продакшн среды с NAS
4. Восстановление Moodle 5.0.2 с NAS интеграцией
5. Восстановление Drupal 11 с NAS интеграцией
6. Обновление доменов и SSL
7. Тестирование функциональности
8. Копирование данных в NAS

---

## МЕТОД 3: Прямая продакшн установка (альтернативный)

Если вы хотите установить сразу в продакшн, минуя облачное тестирование:

### Этап 7: Установка Moodle в продакшн с NAS

```bash
# Скачивание и запуск скрипта продакшн установки
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/production-deployment/install-moodle-production.sh
chmod +x install-moodle-production.sh

# Запуск установки с NAS интеграцией
sudo ./install-moodle-production.sh
```

### Этап 8: Установка Drupal в продакшн с NAS

```bash
# На втором продакшн сервере или том же (если ресурсы позволяют)
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/production-deployment/install-drupal-production.sh
chmod +x install-drupal-production.sh

# Запуск установки с NAS интеграцией
sudo ./install-drupal-production.sh
```

---

## Настройка резервного копирования

### Автоматическое многоуровневое резервное копирование

```bash
# Скачивание скрипта резервного копирования
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/production-deployment/nas-backup.sh
chmod +x nas-backup.sh
sudo cp nas-backup.sh /opt/

# Настройка расписания в cron
sudo crontab -e
```

**Добавить в crontab:**
```cron
# Ежедневные бэкапы в 2:00
0 2 * * * /opt/nas-backup.sh daily >> /var/log/lms-backup.log 2>&1

# Еженедельные бэкапы в воскресенье в 3:00
0 3 * * 0 /opt/nas-backup.sh weekly >> /var/log/lms-backup.log 2>&1

# Ежемесячные бэкапы в первый день месяца в 4:00
0 4 1 * * /opt/nas-backup.sh monthly >> /var/log/lms-backup.log 2>&1
```

---

## Настройка интеграции между системами

### SSO настройка

1. **В Moodle:**
   ```bash
   cd /var/www/moodle
   # Включение external authentication
   sudo -u www-data php admin/cli/cfg.php --name=auth --set=manual,external
   ```

2. **В Drupal:**
   ```bash
   cd /var/www/drupal
   # Установка модулей SSO
   sudo -u www-data composer require drupal/external_auth
   sudo -u www-data drush en external_auth -y
   ```

### API интеграция

1. **Настройка веб-сервисов Moodle:**
   - Административная панель → Расширения → Веб-сервисы
   - Включить веб-сервисы
   - Создать токен для Drupal

2. **Настройка REST API в Drupal:**
   ```bash
   sudo -u www-data drush en restui hal serialization -y
   ```

---

## Проверка установки

### Контрольный список

#### Инфраструктура
- [ ] Все сервисы запущены и работают
- [ ] SSL сертификаты установлены
- [ ] Домены резолвятся корректно
- [ ] NAS подключен и доступен для записи
- [ ] Файрвол настроен правильно

#### Приложения
- [ ] Moodle 5.0.2 доступен и функционален
- [ ] Drupal 11 доступен и функционален
- [ ] Интеграция SSO работает
- [ ] API интеграция настроена
- [ ] Резервное копирование работает

#### Безопасность
- [ ] SSL Grade A/A+ (проверить на ssllabs.com)
- [ ] Fail2Ban активен
- [ ] Обновления безопасности настроены
- [ ] Логирование работает

### Полезные команды для проверки

```bash
# Проверка статуса сервисов
sudo systemctl status nginx php8.2-fpm php8.3-fpm postgresql redis-server

# Проверка логов
sudo tail -f /var/log/nginx/error.log
sudo journalctl -f

# Проверка NAS
mountpoint /mnt/nas
df -h /mnt/nas

# Проверка SSL
curl -I https://lms.rtti.tj
curl -I https://library.rtti.tj

# Проверка баз данных
sudo -u postgres psql -l
```

---

## Поддержка и документация

### Дополнительные ресурсы
- [Технические требования](technical-requirements.md)
- [Полное руководство по развертыванию](deployment-guide.md)
- [Устранение неполадок](troubleshooting.md)

### Контакты поддержки
- **Техническая поддержка**: tech@rtti.tj
- **Администратор системы**: admin@rtti.tj
- **Экстренная поддержка**: +992 XX XXX XXXX

---

*Данное руководство обновлено для Moodle 5.0.2 и Drupal 11 с современной облачной архитектурой и NAS интеграцией. Сентябрь 2025.*
