# RTTI LMS Project - Moodle + Drupal Integration

Комплексная система управления обучением для Республиканского института повышения квалификации и переподготовки работников в сфере образования имени А. Джоми (RTTI).

## 🎯 Обзор проекта

Данный проект представляет собой интегрированную LMS систему, состоящую из:

- **Moodle 5.0+** - современная платформа для проведения онлайн-обучения с ИИ инструментами
- **Drupal 11 Library** - цифровая библиотека электронных книг на LTS платформе
- **Облачное развертывание** - автоматическая установка в AWS, DigitalOcean, GCP, Azure
- **Продакшн миграция** - перенос из облака в продакшн с NAS интеграцией
- **Интеграция систем** - единая аутентификация (SSO) и синхронизация данных
- **Система резервного копирования** - многоуровневое резервное копирование с NAS
- **Мониторинг и безопасность** - комплексная система мониторинга и алертов

## 📁 Структура проекта

```
LMS_Drupal/
├── moodle-installation/                  # 🎓 Установка Moodle 5.0+ LMS
│   ├── README.md                         # Документация по установке Moodle
│   ├── install-moodle.sh                 # Автоматическая установка
│   ├── 01-prepare-system.sh              # Подготовка системы
│   ├── 02-install-webserver.sh           # Nginx + PHP 8.2
│   ├── 03-install-database.sh            # PostgreSQL 16
│   ├── 04-install-cache.sh               # Redis
│   ├── 05-configure-domain.sh            # Настройка домена
│   ├── 06-install-ssl.sh                 # SSL сертификаты
│   ├── 07-download-moodle.sh             # Загрузка Moodle
│   ├── 08-configure-moodle.sh            # Конфигурация
│   ├── 09-optimize-moodle.sh             # Оптимизация
│   └── 10-backup-setup.sh                # Настройка бэкапов
├── drupal-installation/                  # 📚 Установка Drupal 11 Library
│   ├── README.md                         # Документация по установке Drupal
│   ├── install-drupal.sh                 # Автоматическая установка
│   ├── 01-prepare-system.sh              # Подготовка системы
│   ├── 02-install-webserver.sh           # Nginx + PHP 8.3
│   ├── 03-install-database.sh            # PostgreSQL 16
│   ├── 04-install-cache.sh               # Redis
│   ├── 05-configure-domain.sh            # Настройка домена
│   ├── 06-install-ssl.sh                 # SSL сертификаты
│   ├── 07-install-composer.sh            # Composer
│   ├── 08-download-drupal.sh             # Установка Drupal
│   ├── 09-configure-drupal.sh            # Конфигурация
│   └── 10-setup-modules.sh               # Модули библиотеки
├── monitoring-installation/              # 📊 Система мониторинга
│   ├── README.md                         # Документация по мониторингу
│   ├── install-monitoring.sh             # Автоматическая установка
│   ├── 01-prepare-monitoring.sh          # Подготовка системы
│   ├── 02-install-prometheus.sh          # Prometheus
│   ├── 03-install-grafana.sh             # Grafana
│   ├── 04-install-alertmanager.sh        # Alertmanager
│   ├── 05-install-exporters.sh           # Exporters
│   ├── 06-configure-alerts.sh            # Правила алертов
│   ├── 07-setup-dashboards.sh            # Дашборды
│   ├── 08-configure-remote.sh            # Удаленный мониторинг
│   ├── 09-setup-backup.sh                # Резервное копирование
│   └── 10-test-monitoring.sh             # Тестирование
├── documentation/                        # 📖 Общая документация
│   ├── project-plan.md                   # Детальный план проекта  
│   ├── technical-requirements.md         # Технические требования
│   ├── deployment-guide.md               # Полное руководство развертывания
│   └── installation-guide.md             # Общее руководство установки
├── moodle-integration/                   # 🔗 Интеграция систем
│   ├── moodle_drupal_integration.php     # Модуль интеграции для Moodle
│   └── drupal_moodle_integration.module  # Модуль интеграции для Drupal
└── README.md                             # Этот файл
```

## 🚀 Быстрый старт

### Предварительные требования

- Ubuntu Server 24.04 LTS 
- Домены: lms.rtti.tj (92.242.60.172), library.rtti.tj (92.242.61.204)
- Базовые знания Linux администрирования

### Готовые серверы RTTI

- **LMS + Мониторинг**: lms.rtti.tj (92.242.60.172)
  - Moodle 5.0.2 LMS
  - Система мониторинга (Prometheus/Grafana)
  
- **Библиотека**: library.rtti.tj (92.242.61.204)
  - Drupal 11 Digital Library

### 🎓 Установка Moodle LMS

```bash
# Быстрая установка
wget -O install-moodle.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-installation/install-moodle.sh
chmod +x install-moodle.sh
sudo ./install-moodle.sh

# Или локально
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/moodle-installation
sudo ./install-moodle.sh
```

### 📚 Установка Drupal Library

```bash
# Быстрая установка
wget -O install-drupal.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/drupal-installation/install-drupal.sh
chmod +x install-drupal.sh
sudo ./install-drupal.sh

# Или локально
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/drupal-installation
sudo ./install-drupal.sh
```

### 📊 Установка системы мониторинга

```bash
# Быстрая установка (на сервере lms.rtti.tj)
wget -O install-monitoring.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring-installation/install-monitoring.sh
chmod +x install-monitoring.sh
sudo ./install-monitoring.sh

# Или локально
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/monitoring-installation
sudo ./install-monitoring.sh
```

## 📊 Система мониторинга

Централизованная система мониторинга установлена на lms.rtti.tj (92.242.60.172) и отслеживает все серверы RTTI LMS.

### � Prometheus + Grafana + AlertManager
```bash
# Установка полного стека мониторинга на lms.rtti.tj
cd LMS_Drupal/monitoring-installation
sudo ./install-monitoring.sh
```

**Доступ**: 
- **Prometheus**: http://lms.rtti.tj:9090 (метрики и алерты)
- **Grafana**: http://lms.rtti.tj:3000 (дашборды, admin/RTTIMonitor2024!)
- **AlertManager**: http://lms.rtti.tj:9093 (уведомления)

### � Мониторинг включает:
- 📊 **Серверы**: lms.rtti.tj + library.rtti.tj
- 🌐 **Веб-приложения**: Moodle, Drupal, Nginx, PHP-FPM
- 🗄️ **Базы данных**: PostgreSQL, Redis
- 💾 **Системные ресурсы**: CPU, RAM, Disk, Network
- 🔒 **SSL сертификаты** и безопасность
- 🚨 **Автоматические алерты** на email/telegram

### 📊 Дополнительные агенты
```bash
# Установка агентов мониторинга на library.rtti.tj
cd LMS_Drupal/monitoring-installation
sudo ./install-remote-agents.sh 92.242.61.204
```

Подробная документация: [monitoring-installation/README.md](monitoring-installation/README.md)

### Детальная документация

Полное руководство по развертыванию см. в [installation-guide.md](documentation/installation-guide.md)

## 📋 Основные функции

### ✅ Moodle 5.0+
- Современные ИИ инструменты и рекомендации
- Создание и управление курсами с расширенной аналитикой
- Система оценок и сертификации нового поколения
- Автоматизация учебных процессов с машинным обучением
- Поддержка SCORM пакетов и H5P контента
- Мобильное приложение с офлайн синхронизацией
- Интеграция с BigBlueButton и видеоконференциями
- Улучшенный пользовательский интерфейс и производительность

### ✅ Drupal 11 Library
- Цифровая библиотека на LTS платформе (поддержка до 2029)
- Расширенный поиск с ИИ-рекомендациями
- Современная система таксономий и метаданных
- API-first архитектура для интеграций
- Поддержка мультимедиа контента
- Адаптивный дизайн и PWA функциональность
- Интеграция с Moodle курсами через REST API

### ✅ Облачная инфраструктура
- Автоматическое развертывание в AWS, DigitalOcean, GCP, Azure
- Динамическое масштабирование ресурсов
- CDN для ускорения загрузки контента
- Автоматические SSL сертификаты Let's Encrypt
- Мониторинг производительности в реальном времени
- Облачные резервные копии с георепликацией

### ✅ Продакшн интеграция с NAS
- Централизованное хранение файлов на NAS
- Автоматическая синхронизация облако ↔ продакшн
- Многоуровневое резервное копирование
- Высокая доступность данных
- Масштабируемое хранилище
- Интеграция с корпоративной инфраструктурой

### ✅ Интеграция
- Single Sign-On (SSO) аутентификация
- Синхронизация пользователей
- Автоматическое добавление ресурсов библиотеки в курсы
- Отслеживание прогресса обучения
- Единая система отчетности

### ✅ Безопасность
- SSL/TLS шифрование
- Защита от атак (Fail2ban)
- Регулярные обновления безопасности
- Мониторинг системы
- Аудит доступа

### ✅ Резервное копирование
- Автоматическое ежедневное резервное копирование БД
- Еженедельное резервное копирование файлов
- Ежемесячное полное резервное копирование
- Хранение на NAS сервере
- Процедуры восстановления

## 🛠️ Технический стек

### Серверное ПО
- **ОС**: Ubuntu Server 24.04 LTS
- **Web-сервер**: Nginx 1.24+
- **PHP**: 8.2+ (Moodle), 8.3+ (Drupal) с необходимыми расширениями
- **База данных**: PostgreSQL 16+
- **Кэширование**: Redis 7+
- **Node.js**: 20+ LTS для современных фронтенд-инструментов

### Платформы
- **Moodle**: 5.0+ (с ИИ инструментами и улучшенной производительностью)
- **Drupal**: 11.x LTS (поддержка до 2029 года)
- **SSL**: Let's Encrypt сертификаты с автообновлением
- **Контейнеризация**: Docker готовность для будущего масштабирования

### Облачные платформы
- **AWS**: EC2, RDS, S3, CloudFront
- **DigitalOcean**: Droplets, Managed Databases, Spaces
- **Google Cloud**: Compute Engine, Cloud SQL, Cloud Storage
- **Azure**: Virtual Machines, Database, Blob Storage

### Инструменты
- **Мониторинг**: Системные скрипты + логирование + облачные метрики
- **Резервное копирование**: Многоуровневые скрипты (облако + NAS)
- **Автоматизация**: Cron задачи + CI/CD готовность
- **Управление**: Drush (Drupal), Moodle CLI, WP-CLI совместимость
- **Развертывание**: Автоматические скрипты для облака и продакшн
- **Миграция**: Специализированные инструменты облако → продакшн

## 📊 Архитектура системы

```mermaid
graph TB
    subgraph "Пользователи"
        U1[Студенты]
        U2[Преподаватели]
        U3[Администраторы]
    end
    
    subgraph "LMS Сервер (92.242.60.172)"
        M[Moodle LMS<br/>lms.rtti.tj]
        M --> MDB[(PostgreSQL<br/>Moodle DB)]
        MON[Мониторинг<br/>Prometheus/Grafana]
    end
    
    subgraph "Библиотека Сервер (92.242.61.204)"
        D[Drupal Library<br/>library.rtti.tj]
        D --> DDB[(PostgreSQL<br/>Drupal DB)]
    end
    
    subgraph "Интеграция"
        SSO[Single Sign-On]
        API[REST API]
        SYNC[Синхронизация данных]
    end
    
    subgraph "Инфраструктура"
        NAS[NAS Storage]
        BACKUP[Backup System]
    end
    
    U1 --> M
    U2 --> M
    U3 --> M
    U1 --> D
    U2 --> D
    U3 --> D
    M <--> SSO
    D <--> SSO
    M <--> API
    D <--> API
    M --> SYNC
    D --> SYNC
    M --> BACKUP
    D --> BACKUP
    BACKUP --> NAS
    MON --> M
    MON --> D
```

## 📈 Производительность

### Рекомендуемые характеристики серверов

#### Moodle 5.0.2 сервер
- **CPU**: 4-8 cores (2.4GHz+)
- **RAM**: 16GB (рекомендуется 32GB для продакшн)
- **Storage**: 200GB+ SSD (базовая установка + рост данных)
- **Network**: 1Gbps
- **Cloud**: Поддержка автоскейлинга в облачных платформах

#### Drupal 11 сервер
- **CPU**: 4-6 cores (2.4GHz+)
- **RAM**: 8GB (рекомендуется 16GB для больших библиотек)
- **Storage**: 500GB+ SSD (для хранения мультимедиа контента)
- **Network**: 1Gbps
- **Cloud**: CDN интеграция для глобального доступа

#### NAS интеграция (продакшн)
- **Protocol**: CIFS/SMB 3.0+, NFS 4.1+
- **Capacity**: от 2TB (масштабируемо)
- **Redundancy**: RAID 6 или выше
- **Backup**: Автоматическая репликация
- **Performance**: 10Gbps сетевое подключение

### Ожидаемая нагрузка
- **Одновременные пользователи**: до 1000 (облако), до 500 (продакшн)
- **Курсы**: до 2000+
- **Электронные книги**: до 50,000
- **Мультимедиа контент**: до 10TB
- **API запросов**: до 10,000/час
- **Пиковая нагрузка**: обработка экзаменационных периодов

## 🔧 Администрирование

### Ежедневные задачи
- Мониторинг логов ошибок и производительности
- Проверка дискового пространства и NAS подключений
- Мониторинг облачных ресурсов и расходов
- Проверка автоматических резервных копий
- Анализ метрик пользователей и нагрузки

### Еженедельные задачи
- Проверка резервных копий в облаке и NAS
- Обновления безопасности (автоматические + ручная проверка)
- Анализ отчетов использования и производительности
- Оптимизация базы данных и кэша
- Проверка интеграций между системами

### Ежемесячные задачи
- Полное тестирование восстановления из бэкапов
- Мажорные обновления системы (с тестированием)
- Комплексный аудит безопасности
- Архивирование старых данных в холодное хранилище
- Планирование масштабирования и развития
- Анализ затрат на облачную инфраструктуру

## 📞 Поддержка

### Контакты
- **Техническая поддержка**: tech@rtti.tj
- **Администратор системы**: admin@rtti.tj
- **Поддержка пользователей**: support@rtti.tj

### Документация
- [Руководство администратора](documentation/deployment-guide.md)
- [Пошаговая установка](documentation/installation-guide.md)
- [Технические требования](documentation/technical-requirements.md)
- [Устранение неполадок](documentation/troubleshooting.md)
- [План проекта](documentation/project-plan.md)
- [API документация](documentation/api-docs.md) (в разработке)

### Уровни поддержки

#### Уровень 1 (L1) - Базовая поддержка
- Решение стандартных проблем пользователей
- Сброс паролей
- Помощь с навигацией

#### Уровень 2 (L2) - Техническая поддержка
- Проблемы с курсами и контентом
- Настройка интеграций
- Диагностика производительности

#### Уровень 3 (L3) - Экспертная поддержка
- Серьезные системные проблемы
- Изменения архитектуры
- Разработка новых функций

## 🔄 Обновления и развитие

### Планируемые улучшения
- [ ] Мобильное приложение для библиотеки с офлайн синхронизацией
- [ ] AI-рекомендации курсов и книг на базе ML
- [ ] Расширенная аналитика обучения с предиктивной моделью
- [ ] Интеграция с внешними системами (1С, LDAP, Active Directory)
- [ ] Многоязычная поддержка (русский, таджикский, английский)
- [ ] Микросервисная архитектура для лучшего масштабирования
- [ ] Блокчейн сертификация курсов
- [ ] VR/AR поддержка для иммерсивного обучения
- [ ] Интеграция с IoT устройствами в аудиториях
- [ ] Quantum-ready шифрование для будущей безопасности

### График обновлений
- **Критические патчи безопасности**: В течение 24 часов
- **Плановые обновления безопасности**: Еженедельно
- **Функциональные обновления**: Ежемесячно с тестированием
- **Мажорные версии**: Каждые 6-12 месяцев
- **Миграция платформ**: По LTS циклам (2-3 года)

## 📜 Лицензия

Этот проект разрабатывается для RTTI и содержит интеграцию с открытыми системами:
- Moodle - GPL v3
- Drupal - GPL v2+
- Собственные разработки - All rights reserved RTTI

## 🤝 Участие в разработке

### Процесс разработки
1. Создание задачи в системе управления проектами
2. Разработка в отдельной ветке
3. Code review
4. Тестирование на staging среде
5. Развертывание на production

### Стандарты кодирования
- Следование стандартам Moodle и Drupal
- Документирование всех функций
- Обязательное тестирование
- Следование принципам безопасности

---

## 🆘 Поддержка и устранение проблем

### 📋 Документация по установке
- **Moodle LMS**: [moodle-installation/README.md](moodle-installation/README.md)
- **Drupal Library**: [drupal-installation/README.md](drupal-installation/README.md)
- **Мониторинг**: [monitoring-installation/README.md](monitoring-installation/README.md)

### 🔧 Диагностика проблем
```bash
# Проверка служб
systemctl status nginx postgresql redis-server php8.2-fpm php8.3-fpm

# Проверка логов
tail -f /var/log/nginx/error.log
tail -f /var/log/postgresql/postgresql-16-main.log

# Проверка конфигурации
nginx -t
```

### 📞 Получение помощи
- **GitHub Issues**: [https://github.com/cheptura/LMS_Drupal/issues](https://github.com/cheptura/LMS_Drupal/issues)
- **Email**: admin@rtti.tj
- **Документация**: [RTTI LMS Wiki](https://github.com/cheptura/LMS_Drupal/wiki)

**Принцип**: Каждый установщик должен работать с первого раза без дополнительных исправлений.

---

## 🔗 Полезные ссылки
- [ ] Облачные серверы настроены и оптимизированы
- [ ] Продакшн серверы подготовлены с NAS интеграцией
- [ ] SSL сертификаты установлены и автообновляются
- [ ] Домены корректно настроены с CDN
- [ ] Мониторинг работает в облаке и продакшн
- [ ] Многоуровневое резервное копирование настроено
- [ ] Автоскейлинг настроен в облачной среде
- [ ] Сеть безопасности и файрволы сконфигурированы

### Приложения
- [ ] Moodle 5.0.2 установлен с ИИ модулями
- [ ] Drupal 11 установлен с библиотечными модулями
- [ ] Интеграция SSO функционирует между системами
- [ ] Современные темы и брендинг RTTI применены
- [ ] Все необходимые плагины установлены и настроены
- [ ] API интеграции протестированы и работают
- [ ] Мобильная адаптация проверена
- [ ] Производительность оптимизирована

### Миграция и развертывание
- [ ] Облачное тестирование завершено успешно
- [ ] Данные мигрированы в продакшн через NAS
- [ ] Интеграция облако ↔ продакшн настроена
- [ ] Процедуры отката проверены
- [ ] Синхронизация между средами работает
- [ ] Нагрузочное тестирование пройдено

### Контент
- [ ] Пользователи загружены
- [ ] Курсы созданы
- [ ] Библиотека наполнена
- [ ] Права доступа настроены
- [ ] Тестовые данные проверены

### Документация и обучение
- [ ] Документация подготовлена
- [ ] Администраторы обучены
- [ ] Преподаватели обучены
- [ ] Процедуры поддержки готовы
- [ ] Планы развития утверждены

---

## � Устранение неполадок

### Проблемы установки

#### "ERROR: database 'moodle' already exists"
Эта ошибка возникает при повторной установке Moodle.

**Решение 1 (автоматическое, рекомендуется):**
```bash
sudo ./install-moodle-cloud.sh cleanup
```

**Решение 2 (полная переустановка):**
```bash
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/reinstall-moodle.sh
chmod +x reinstall-moodle.sh
sudo ./reinstall-moodle.sh
```

**Решение 3 (ручная очистка):**
```bash
sudo -u postgres psql -c "DROP DATABASE IF EXISTS moodle;"
sudo -u postgres psql -c "DROP USER IF EXISTS moodleuser;"
sudo rm -rf /var/www/html/moodle /var/moodledata
sudo ./install-moodle-cloud.sh
```

#### "ERROR: database 'drupal' already exists"
Аналогичная ошибка для Drupal при повторной установке.

**Решение 1 (автоматическое, рекомендуется):**
```bash
sudo ./install-drupal-cloud.sh cleanup
```

**Решение 2 (полная переустановка):**
```bash
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/reinstall-drupal.sh
chmod +x reinstall-drupal.sh
sudo ./reinstall-drupal.sh
```

**Решение 3 (ручная очистка):**
```bash
sudo -u postgres psql -c "DROP DATABASE IF EXISTS drupal;"
sudo -u postgres psql -c "DROP USER IF EXISTS drupaluser;"
sudo rm -rf /var/www/html/drupal
sudo ./install-drupal-cloud.sh
```

#### Ошибки PHP или Nginx
- Проверьте логи: `sudo tail -f /var/log/nginx/error.log`
- Перезапустите службы: `sudo systemctl restart nginx php8.2-fpm php8.3-fpm`
- Проверьте конфигурацию: `sudo nginx -t`

#### Проблемы с правами доступа

**Для Moodle:**
```bash
sudo chown -R www-data:www-data /var/www/html/moodle
sudo chown -R www-data:www-data /var/moodledata
sudo chmod -R 755 /var/www/html/moodle
sudo chmod -R 777 /var/moodledata
```

**Для Drupal:**
```bash
sudo chown -R www-data:www-data /var/www/html/drupal
sudo chmod -R 755 /var/www/html/drupal
sudo chmod -R 777 /var/www/html/drupal/web/sites/default/files
```

### Мониторинг и диагностика
- **Системные ресурсы**: `htop`, `df -h`, `free -m`
- **Логи приложений**: `/var/log/nginx/`, `/var/log/postgresql/`
- **Статус служб**: `systemctl status nginx postgresql redis`

### Полезные скрипты переустановки
- **Moodle**: [cloud-deployment/reinstall-moodle.sh](cloud-deployment/reinstall-moodle.sh)
- **Drupal**: [cloud-deployment/reinstall-drupal.sh](cloud-deployment/reinstall-drupal.sh)
- **Database Fix Guide**: [cloud-deployment/database-fix-guide.md](cloud-deployment/database-fix-guide.md)

---

## �🔗 Полезные ссылки

### RTTI LMS Серверы
- **🎓 Moodle LMS**: [https://lms.rtti.tj](https://lms.rtti.tj) (92.242.60.172)
- **📚 Digital Library**: [https://library.rtti.tj](https://library.rtti.tj) (92.242.61.204)
- **📊 Мониторинг**: [http://lms.rtti.tj:3000](http://lms.rtti.tj:3000) (Grafana)

### Проект
- **🌐 GitHub Repository**: [https://github.com/cheptura/LMS_Drupal](https://github.com/cheptura/LMS_Drupal)
- **🐛 Issues & Support**: [https://github.com/cheptura/LMS_Drupal/issues](https://github.com/cheptura/LMS_Drupal/issues)
- **📖 Wiki**: [https://github.com/cheptura/LMS_Drupal/wiki](https://github.com/cheptura/LMS_Drupal/wiki)
- **🏷️ Releases**: [https://github.com/cheptura/LMS_Drupal/releases](https://github.com/cheptura/LMS_Drupal/releases)

### Документация
- **📋 Installation Guide**: [documentation/installation-guide.md](documentation/installation-guide.md)
- **📊 Monitoring Guide**: [monitoring/README.md](monitoring/README.md)
- **🔧 Technical Requirements**: [documentation/technical-requirements.md](documentation/technical-requirements.md)
- **🚨 Troubleshooting**: [documentation/troubleshooting.md](documentation/troubleshooting.md)

### Платформы
- **Moodle 5.0.2**: [https://moodle.org](https://moodle.org)
- **Drupal 11**: [https://drupal.org](https://drupal.org)
- **Ubuntu 24.04**: [https://ubuntu.com](https://ubuntu.com)

---

**Последнее обновление**: Сентябрь 2025  
**Версия документации**: 3.0 (Moodle 5.0+ + Drupal 11 + Monitoring System)  
**Ответственный**: Команда разработки RTTI LMS  
**Архитектура**: Продакшн готовое решение с современными технологиями
