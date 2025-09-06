# RTTI Infrastructure Automation Scripts

Полный набор автоматизированных скриптов для развертывания и управления инфраструктурой Республиканского технологического техникума-интернета (RTTI).

## 🏗️ Архитектура проекта

Проект включает три основных компонента образовательной инфраструктуры:

### 📚 **LMS (Learning Management System)**
- **Платформа:** Moodle 5.0+
- **Назначение:** Система управления обучением
- **Домен:** omuzgorpro.tj
- **Папка:** `moodle-installation/`

### 📖 **Digital Library System**
- **Платформа:** Drupal 11 LTS
- **Назначение:** Цифровая библиотека и каталог ресурсов
- **Домен:** storage.omuzgorpro.tj
- **Папка:** `drupal-installation/`

### 📊 **Monitoring System**
- **Платформа:** Prometheus + Grafana + Alertmanager
- **Назначение:** Мониторинг всей инфраструктуры
- **Домен:** monitoring.omuzgorpro.tj
- **Папка:** `monitoring-installation/`

## 🚀 QUICK_INSTALL (Полная инфраструктура)

### Установка отдельных компонентов:
```bash
# Клонирование репозитория
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal

# Установка LMS Moodle
cd moodle-installation
sudo chmod +x *.sh && sudo ./install-moodle.sh

# Установка Digital Library
cd ../drupal-installation  
sudo chmod +x *.sh && sudo ./install-drupal.sh

# Установка системы мониторинга
cd ../monitoring-installation
sudo chmod +x *.sh && sudo ./install-monitoring.sh
```

### Быстрая установка одной командой (по системам):
```bash
# Moodle LMS
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-installation/install-moodle.sh && chmod +x install-moodle.sh && sudo ./install-moodle.sh

# Drupal Library  
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/drupal-installation/install-drupal.sh && chmod +x install-drupal.sh && sudo ./install-drupal.sh

# Monitoring System
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring-installation/install-monitoring.sh && chmod +x install-monitoring.sh && sudo ./install-monitoring.sh
```

## 📋 Состав проекта

### 🎓 Moodle Installation (14 скриптов)
**Основные скрипты:**
- `01-prepare-system.sh` - Подготовка системы
- `02-install-webserver.sh` - Nginx веб-сервер
- `03-install-database.sh` - PostgreSQL 16
- `04-install-cache.sh` - Redis кэш
- `05-configure-ssl.sh` - SSL сертификаты
- `06-download-moodle.sh` - Загрузка Moodle 5.0
- `07-configure-moodle.sh` - Конфигурация
- `08-install-moodle.sh` - Установка Moodle
- `09-post-install.sh` - Пост-установка
- `10-final-check.sh` - Финальная проверка

**Утилиты администрирования:**
- `update-moodle.sh` - Обновление Moodle
- `backup-moodle.sh` - Резервное копирование
- `restore-moodle.sh` - Восстановление
- `diagnose-moodle.sh` - Диагностика

### 📚 Drupal Installation (14 скриптов)
**Основные скрипты:**
- `01-prepare-system.sh` - Подготовка системы
- `02-install-webserver.sh` - Nginx веб-сервер
- `03-install-database.sh` - PostgreSQL 16
- `04-install-cache.sh` - Redis кэш
- `05-configure-ssl.sh` - SSL сертификаты
- `06-install-drupal.sh` - Загрузка Drupal 11
- `07-configure-drupal.sh` - Конфигурация
- `08-post-install.sh` - Пост-установка
- `09-security.sh` - Настройка безопасности
- `10-final-check.sh` - Финальная проверка

**Утилиты администрирования:**
- `update-drupal.sh` - Обновление через Composer
- `backup-drupal.sh` - Резервное копирование
- `restore-drupal.sh` - Восстановление
- `diagnose-drupal.sh` - Диагностика

### 📊 Monitoring Installation (14 скриптов)
**Основные скрипты:**
- `01-prepare-system.sh` - Подготовка системы
- `02-install-prometheus.sh` - Prometheus сервер
- `03-install-grafana.sh` - Grafana дашборды
- `04-install-alertmanager.sh` - Alertmanager для алертов
- `05-install-exporters.sh` - Экспортеры метрик
- `06-configure-alerts.sh` - Настройка алертов
- `07-create-dashboards.sh` - Дашборды
- `08-optimize-monitoring.sh` - Оптимизация
- `09-backup-monitoring.sh` - Бэкап настроек
- `10-final-check.sh` - Финальная проверка

**Утилиты администрирования:**
- `install-remote-agents.sh` - Установка удаленных агентов
- `update-monitoring.sh` - Обновление мониторинга
- `backup-monitoring.sh` - Резервное копирование
- `diagnose-monitoring.sh` - Диагностика

## ⚙️ Системные требования

### Минимальные требования (для тестирования):
- **ОС:** Ubuntu 24.04 LTS
- **RAM:** 8GB (по 2-3GB на систему)
- **CPU:** 4 ядра
- **Диск:** 100GB SSD
- **Сеть:** 100 Мбит/с

### Рекомендуемые требования (для продакшена):
- **ОС:** Ubuntu 24.04 LTS
- **RAM:** 32GB (по 8-12GB на систему)
- **CPU:** 8+ ядер
- **Диск:** 500GB+ NVMe SSD
- **Сеть:** 1 Гбит/с

### Требования по серверам:
- **Отдельные серверы:** Рекомендуется для продакшена
- **Один сервер:** Возможно для тестирования и малых нагрузок
- **Доступ:** root или sudo права
- **Интернет:** Необходим для загрузки пакетов

## 🌐 Сетевая архитектура

### Основные порты:
| Сервис | Порт | Протокол | Назначение |
|--------|------|----------|------------|
| HTTP | 80 | TCP | Веб-трафик (redirect to HTTPS) |
| HTTPS | 443 | TCP | Защищенный веб-трафик |
| PostgreSQL | 5432 | TCP | База данных (внутренний) |
| PHP-FPM | 9000 | TCP | PHP обработчик (внутренний) |
| Prometheus | 9090 | TCP | API метрик |
| Grafana | 3000 | TCP | Веб-интерфейс мониторинга |
| Alertmanager | 9093 | TCP | Система уведомлений |
| Node Exporter | 9100 | TCP | Системные метрики |

### Доменная структура:
- **omuzgorpro.tj** → Moodle LMS
- **storage.omuzgorpro.tj** → Drupal Digital Library
- **monitoring.omuzgorpro.tj** → Grafana + Prometheus

## 🔐 Безопасность

### Автоматически настраивается:
- ✅ SSL/TLS сертификаты Let's Encrypt
- ✅ Автоматическое обновление сертификатов
- ✅ Firewall правила (UFW)
- ✅ Secure headers в Nginx
- ✅ Ограничение доступа к административным панелям
- ✅ Автоматические обновления безопасности

### Учетные записи:
- **Moodle Admin:** Генерируется автоматически
- **Drupal Admin:** Генерируется автоматически  
- **PostgreSQL:** Уникальные пароли для каждой БД
- **Grafana:** admin/admin (изменить после установки)

## 📊 Мониторинг и алерты

### Автоматически мониторится:
- 🖥️ **Системные ресурсы:** CPU, RAM, диск, сеть
- 🌐 **Веб-сервисы:** Доступность, время ответа, ошибки
- 🗄️ **Базы данных:** Подключения, производительность, размер
- 📚 **Приложения:** Статус Moodle/Drupal, пользователи онлайн

### Алерты по умолчанию:
- ⚠️ Высокая загрузка CPU (>80%)
- ⚠️ Нехватка RAM (>90%)
- ⚠️ Заполнение диска (>85%)
- ⚠️ Недоступность сервисов
- ⚠️ Ошибки в приложениях

## 🛠️ Администрирование

### Диагностика всей инфраструктуры:
```bash
# Отдельная диагностика каждой системы
cd moodle-installation && sudo ./diagnose-moodle.sh
cd ../drupal-installation && sudo ./diagnose-drupal.sh  
cd ../monitoring-installation && sudo ./diagnose-monitoring.sh
```

### Резервное копирование:
```bash
# Отдельные бэкапы каждой системы
cd moodle-installation && sudo ./backup-moodle.sh
cd ../drupal-installation && sudo ./backup-drupal.sh
cd ../monitoring-installation && sudo ./backup-monitoring.sh
```

### Обновления:
```bash
# Отдельные обновления каждой системы
cd moodle-installation && sudo ./update-moodle.sh
cd ../drupal-installation && sudo ./update-drupal.sh
cd ../monitoring-installation && sudo ./update-monitoring.sh
```

## 📁 Структура файлов после установки

```
/var/www/html/
├── moodle/                 # Moodle LMS файлы
└── drupal/                 # Drupal библиотека файлы

/var/moodledata/            # Данные Moodle
/var/drupaldata/            # Файлы Drupal

/etc/prometheus/            # Конфигурация Prometheus
/etc/grafana/               # Конфигурация Grafana
/etc/alertmanager/          # Конфигурация Alertmanager

/var/backups/
├── moodle/                 # Бэкапы Moodle
├── drupal/                 # Бэкапы Drupal
└── monitoring/             # Бэкапы мониторинга

/var/log/
├── nginx/                  # Логи веб-сервера
├── php8.3-fpm.log         # Логи PHP
└── postgresql/             # Логи базы данных
```

## 🎯 Веб-интерфейсы

После успешной установки доступны следующие интерфейсы:

### 🎓 Образовательные системы:
- **Moodle LMS:** https://omuzgorpro.tj
- **Digital Library:** https://storage.omuzgorpro.tj

### 📊 Система мониторинга:
- **Grafana Dashboard:** https://monitoring.omuzgorpro.tj:3000
- **Prometheus:** https://monitoring.omuzgorpro.tj:9090
- **Alertmanager:** https://monitoring.omuzgorpro.tj:9093

## 🔧 Troubleshooting

### Общие проблемы:
```bash
# Проверка всех сервисов
systemctl status nginx postgresql php8.3-fpm prometheus grafana-server

# Проверка логов
sudo tail -f /var/log/nginx/error.log
sudo journalctl -u nginx -f

# Проверка подключений к БД
sudo -u postgres psql -l

# Тест веб-доступности
curl -I https://omuzgorpro.tj
curl -I https://storage.omuzgorpro.tj
```

### Восстановление после сбоев:
```bash
# Перезапуск всех сервисов
sudo systemctl restart nginx postgresql php8.3-fpm
sudo systemctl restart prometheus grafana-server alertmanager

# Восстановление из бэкапа
cd moodle-installation && sudo ./restore-moodle.sh /path/to/backup.tar.gz
cd drupal-installation && sudo ./restore-drupal.sh /path/to/backup.tar.gz
```

## 📚 Документация и поддержка

### Документация по компонентам:
- **Moodle:** [moodle-installation/README.md](moodle-installation/README.md)
- **Drupal:** [drupal-installation/README.md](drupal-installation/README.md)
- **Monitoring:** [monitoring-installation/README.md](monitoring-installation/README.md)

### Полезные ссылки:
- **Moodle Documentation:** https://docs.moodle.org/
- **Drupal Guide:** https://www.drupal.org/docs/
- **Prometheus Guide:** https://prometheus.io/docs/
- **Grafana Documentation:** https://grafana.com/docs/

### Поддержка проекта:
- **GitHub Issues:** https://github.com/cheptura/LMS_Drupal/issues
- **Wiki:** https://github.com/cheptura/LMS_Drupal/wiki
- **Email:** admin@omuzgorpro.tj

## 📈 Масштабирование

### Горизонтальное масштабирование:
- Добавление дополнительных серверов Moodle/Drupal
- Настройка балансировщика нагрузки
- Кластер базы данных PostgreSQL

### Мониторинг дополнительных серверов:
```bash
cd monitoring-installation
sudo ./install-remote-agents.sh
```

## 🔄 Обновления и поддержка

### Регулярные задачи:
- **Еженедельно:** Проверка обновлений безопасности
- **Ежемесячно:** Обновление всех компонентов
- **Ежеквартально:** Полное резервное копирование
- **Ежегодно:** Аудит безопасности

### Автоматизация:
- Настроены cron задачи для регулярных операций
- Автоматические уведомления о проблемах
- Автоматическое обновление SSL сертификатов

---

**Проект:** RTTI Infrastructure Automation  
**Версия:** 2.0  
**Дата:** Сентябрь 2025  
**Автор:** RTTI Development Team  
**Лицензия:** MIT  

**Поддерживаемые версии:**
- Ubuntu 24.04 LTS
- Moodle 5.0+
- Drupal 11.x LTS
- PHP 8.3+
- PostgreSQL 16+
- Prometheus 2.45+
- Grafana 10.0+