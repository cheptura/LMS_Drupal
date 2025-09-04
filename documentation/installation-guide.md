# Пошаговое руководство по установке LMS системы RTTI
## Moodle 5.0.2 + Drupal 11 с облачным развертыванием и NAS интеграцией

## Стратегия развертывания

Данное руководство предлагает **облако-первый подход** с последующей миграцией в продакшн:

1. **Этап 1**: Быстрое развертывание в облаке для тестирования
2. **Этап 2**: Тестирование и настройка функций
3. **Этап 3**: Миграция в продакшн с NAS интеграцией

Альтернативно можно сразу развернуть в продакшн (см. раздел "Прямая продакшн установка").

## Предварительные требования

### Системные требования (обновлено)
- **Облачные серверы**: 2 инстанса (Ubuntu Server 24.04 LTS)
  - Moodle: 4-8 CPU cores, 16-32GB RAM, 200GB+ SSD
  - Drupal: 4-6 CPU cores, 8-16GB RAM, 500GB+ SSD
- **Продакшн серверы**: 2 физических/виртуальных сервера
  - Аналогичные характеристики + NAS интеграция
- **NAS сервер**: CIFS/SMB 3.0+, от 2TB, RAID 6+
- **Домены**: lms.rtti.tj, library.rtti.tj
- **Облачный аккаунт**: AWS/DigitalOcean/GCP/Azure

### Подготовка доменов
1. Зарегистрируйте домены в зоне .tj:
   - `lms.rtti.tj` - для Moodle 5.0.2 LMS
   - `library.rtti.tj` - для Drupal 11 библиотеки
   - `test-lms.rtti.tj` и `test-library.rtti.tj` - для облачного тестирования (опционально)
2. Настройте DNS записи с поддержкой CDN (если используется)
3. Убедитесь, что домены резолвятся корректно
4. Подготовьте SSL сертификаты (автоматически через Let's Encrypt)

---

## МЕТОД 1: Облачное развертывание (РЕКОМЕНДУЕТСЯ)

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

### Этап 2: Автоматическая установка Moodle 5.0.2 в облаке

```bash
# Скачивание и запуск скрипта установки
wget https://raw.githubusercontent.com/rtti-tj/lms/main/cloud-deployment/install-moodle-cloud.sh
chmod +x install-moodle-cloud.sh

# Запуск установки (следуйте инструкциям на экране)
sudo ./install-moodle-cloud.sh
```

**Что произойдет автоматически:**
- Обнаружение облачного провайдера
- Установка PHP 8.2, PostgreSQL 16, Redis 7, Nginx
- Скачивание и настройка Moodle 5.0.2
- Настройка SSL сертификатов Let's Encrypt
- Конфигурация производительности и безопасности
- Настройка облачного резервного копирования
- Установка мониторинга

### Этап 3: Автоматическая установка Drupal 11 в облаке

```bash
# На втором облачном сервере
wget https://raw.githubusercontent.com/rtti-tj/lms/main/cloud-deployment/install-drupal-cloud.sh
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
   - Moodle: https://test-lms.rtti.tj (или IP)
   - Drupal: https://test-library.rtti.tj (или IP)

2. **Протестируйте основные функции:**
   - Создание курса в Moodle
   - Загрузка контента в Drupal
   - Регистрация тестовых пользователей
   - Проверка производительности

3. **Настройте интеграции:**
   - SSO между системами
   - API связи
   - Синхронизация пользователей

---

## МЕТОД 2: Миграция из облака в продакшн

### Этап 5: Подготовка продакшн среды

#### 5.1 Настройка NAS сервера
1. **Создайте разделы на NAS:**
   - `/moodle-files` - для данных Moodle
   - `/drupal-files` - для файлов Drupal
   - `/backups` - для резервных копий

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
wget https://raw.githubusercontent.com/rtti-tj/lms/main/migration-tools/cloud-to-production.sh
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
wget https://raw.githubusercontent.com/rtti-tj/lms/main/production-deployment/install-moodle-production.sh
chmod +x install-moodle-production.sh

# Запуск установки с NAS интеграцией
sudo ./install-moodle-production.sh
```

### Этап 8: Установка Drupal в продакшн с NAS

```bash
# На втором продакшн сервере или том же (если ресурсы позволяют)
wget https://raw.githubusercontent.com/rtti-tj/lms/main/production-deployment/install-drupal-production.sh
chmod +x install-drupal-production.sh

# Запуск установки с NAS интеграцией
sudo ./install-drupal-production.sh
```

---

## Настройка резервного копирования

### Автоматическое многоуровневое резервное копирование

```bash
# Скачивание скрипта резервного копирования
wget https://raw.githubusercontent.com/rtti-tj/lms/main/production-deployment/nas-backup.sh
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
