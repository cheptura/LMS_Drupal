# Monitoring Installation Scripts

## Описание
Автоматизированные скрипты для установки системы мониторинга RTTI с Prometheus, Grafana и Alertmanager на Ubuntu 24.04 LTS.

## 🚀 QUICK_INSTALL
```bash
# Быстрая установка (одной командой)
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/monitoring-installation
sudo chmod +x install-monitoring.sh && sudo ./install-monitoring.sh
```

## Состав скриптов

### 📦 Основные установочные скрипты:
1. **01-prepare-system.sh** - Подготовка системы для мониторинга
2. **02-install-prometheus.sh** - Установка Prometheus сервера метрик
3. **03-install-grafana.sh** - Установка Grafana для визуализации
4. **04-install-alertmanager.sh** - Установка Alertmanager для обработки алертов
5. **05-install-exporters.sh** - Установка экспортеров метрик (Node, Nginx, PostgreSQL, Redis)
6. **06-configure-alerts.sh** - Настройка правил алертов и уведомлений
7. **07-create-dashboards.sh** - Создание дашбордов Grafana
8. **08-optimize-monitoring.sh** - Оптимизация системы мониторинга
9. **09-setup-backup.sh** - Настройка системы резервного копирования
10. **10-final-check.sh** - Финальная проверка и валидация

### 🛠️ Утилиты администрирования:
- **install-remote-agents.sh** - Установка агентов мониторинга на удаленные серверы
- **update-monitoring.sh** - Обновление всех компонентов системы мониторинга
- **backup-monitoring.sh** - Создание резервных копий конфигураций и данных
- **diagnose-monitoring.sh** - Полная диагностика системы мониторинга

### 📋 Автоматическая установка:
- **install-monitoring.sh** - Полная автоматическая установка всех компонентов

## Поэтапная установка
```bash
# Подготовка
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/monitoring-installation
sudo chmod +x *.sh

# Поэтапное выполнение
sudo ./01-system-update.sh          # Обновление системы
sudo ./02-install-prometheus.sh     # Prometheus сервер
sudo ./03-install-grafana.sh        # Grafana дашборды
sudo ./04-install-alertmanager.sh   # Система алертов
sudo ./05-install-exporters.sh      # Экспортеры метрик
sudo ./06-configure-monitoring.sh   # Конфигурации
sudo ./07-setup-dashboards.sh       # Дашборды
sudo ./08-configure-alerts.sh       # Алерты
sudo ./09-install-ssl.sh            # SSL защита
sudo ./10-final-setup.sh            # Финализация
```

## Администрирование

### 🔍 Диагностика системы
```bash
sudo ./diagnose-monitoring.sh  # Полная проверка всех компонентов
systemctl status prometheus grafana-server alertmanager  # Статус сервисов
```

### 🌐 Установка удаленных агентов
```bash
sudo ./install-remote-agents.sh  # Установка на удаленные серверы
# Поддерживает SSH ключи и пароли
```

### 💾 Резервное копирование
```bash
sudo ./backup-monitoring.sh    # Создание полного бэкапа
# Бэкапы сохраняются в /var/backups/monitoring/
```

### 🔄 Обновление системы
```bash
sudo ./update-monitoring.sh    # Обновление всех компонентов мониторинга
```

### 📊 Веб-интерфейсы после установки:
- **Grafana:** http://server-ip:3000 (admin/admin)
- **Prometheus:** http://server-ip:9090
- **Alertmanager:** http://server-ip:9093

## Компоненты системы мониторинга

### 📈 Prometheus (порт 9090)
- Сбор и хранение метрик
- Система алертов
- PromQL запросы
- Retention: 15 дней по умолчанию

### 📊 Grafana (порт 3000)
- Визуализация метрик
- Дашборды и панели
- Пользователи и роли
- Уведомления

### 🚨 Alertmanager (порт 9093)
- Обработка алертов
- Группировка уведомлений
- Маршрутизация сообщений
- Интеграции (email, Slack, Telegram)

### 📡 Экспортеры метрик:
- **Node Exporter** (9100) - системные метрики
- **Nginx Exporter** (9113) - метрики веб-сервера
- **PostgreSQL Exporter** (9187) - метрики базы данных
- **Redis Exporter** (9121) - метрики кэша

## Системные требования
- ✅ **ОС:** Ubuntu 24.04 LTS
- ✅ **RAM:** Минимум 4GB (рекомендуется 8GB)
- ✅ **Диск:** 50GB свободного места (рекомендуется 100GB)
- ✅ **Сеть:** Доступ к интернету для загрузки пакетов
- ✅ **Права:** root или sudo доступ

## Сетевые порты
- **3000** - Grafana (веб-интерфейс)
- **9090** - Prometheus (API и веб-интерфейс)
- **9093** - Alertmanager (веб-интерфейс)
- **9100** - Node Exporter (метрики системы)
- **9113** - Nginx Exporter (метрики Nginx)
- **9187** - PostgreSQL Exporter (метрики БД)

## Мониторируемые метрики

### 🖥️ Системные метрики:
- Загрузка CPU и память
- Использование дисков
- Сетевой трафик
- Процессы и сервисы

### 🌐 Веб-сервер метрики:
- HTTP запросы и ответы
- Время ответа
- Активные соединения
- Ошибки 4xx/5xx

### 🗄️ База данных метрики:
- Подключения к БД
- Производительность запросов
- Размер таблиц
- Блокировки и конфликты

### 📚 Приложения (Moodle/Drupal):
- Доступность сервисов
- Время загрузки страниц
- Количество пользователей онлайн
- Ошибки приложений

## Настройка уведомлений

### 📧 Email уведомления:
```bash
# Редактирование конфигурации Alertmanager
sudo nano /etc/alertmanager/alertmanager.yml
sudo systemctl restart alertmanager
```

### 💬 Telegram уведомления:
```bash
# Добавление Telegram бота в конфигурацию
# Инструкции в файле /etc/alertmanager/telegram-config.yml
```

## Поддержка и troubleshooting
```bash
# Проверка логов компонентов
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server -f
sudo journalctl -u alertmanager -f

# Проверка конфигураций
promtool check config /etc/prometheus/prometheus.yml
amtool check-config /etc/alertmanager/alertmanager.yml

# Перезапуск сервисов
sudo systemctl restart prometheus
sudo systemctl restart grafana-server
sudo systemctl restart alertmanager
```

## Масштабирование
- Добавление новых серверов через `install-remote-agents.sh`
- Настройка federation для больших инфраструктур
- Длительное хранение метрик через Thanos (опционально)
- **Postgres Exporter**: 0.13+ (БД метрики)

### Системные требования
- **CPU**: 2+ cores
- **RAM**: 4GB (рекомендуется 8GB)
- **Storage**: 100GB+ SSD
- **Network**: 1Gbps

## 📊 Компоненты мониторинга

### 🔍 Prometheus
- **Порт**: 9090
- **URL**: http://monitoring.omuzgorpro.tj:9090
- **Функции**: Сбор метрик, правила алертов
- **Хранение**: 30 дней данных

### 📈 Grafana
- **Порт**: 3000
- **URL**: http://monitoring.omuzgorpro.tj:3000
- **Данные**: admin / RTTIMonitor2024!
- **Функции**: Дашборды, визуализация

### 🚨 Alertmanager
- **Порт**: 9093
- **URL**: http://monitoring.omuzgorpro.tj:9093
- **Функции**: Управление алертами, уведомления

### 📡 Exporters
- **Node Exporter**: 9100 (системные метрики)
- **Nginx Exporter**: 9113 (веб-сервер)
- **Postgres Exporter**: 9187 (база данных)
- **Redis Exporter**: 9121 (кэш)

## 📊 Мониторинг серверов

### 🎓 Moodle сервер (omuzgorpro.tj) - ЦЕНТРАЛЬНЫЙ МОНИТОРИНГ
- Системные ресурсы (CPU, RAM, Disk)
- Nginx производительность
- PHP-FPM метрики
- PostgreSQL статистика
- Redis статистика
- Moodle специфичные метрики
- **Prometheus сервер**: установлен здесь
- **Grafana дашборды**: установлены здесь
- **Alertmanager**: установлен здесь

### 📚 Drupal сервер (storage.omuzgorpro.tj) - УДАЛЕННЫЙ МОНИТОРИНГ
- Системные ресурсы
- Nginx производительность
- **Только экспортеры метрик**: данные отправляются на центральный сервер
- PHP-FPM метрики
- PostgreSQL статистика
- Drupal специфичные метрики
- Файловая система

## 📈 Дашборды

### Предустановленные дашборды
1. **System Overview** - Общий обзор систем
2. **Moodle LMS** - Специфичные метрики Moodle
3. **Drupal Library** - Метрики библиотеки
4. **Database Performance** - Производительность БД
5. **Web Server Stats** - Статистика веб-серверов
6. **Infrastructure Health** - Здоровье инфраструктуры

### Пользовательские дашборды
```bash
# Создание нового дашборда
./create-dashboard.sh "Dashboard Name"

# Импорт дашборда из файла
./import-dashboard.sh dashboard.json

# Экспорт дашборда
./export-dashboard.sh "Dashboard Name"
```

## 🚨 Алерты и уведомления

### Предустановленные алерты
- **High CPU Usage** (>80% на 5 минут)
- **High Memory Usage** (>90% на 5 минут)
- **Disk Space Low** (<10% свободного места)
- **Service Down** (Nginx, PostgreSQL, Redis)
- **Database Connections High** (>80% от лимита)
- **SSL Certificate Expiry** (<30 дней)

### Каналы уведомлений
```bash
# Email уведомления
./setup-email-alerts.sh admin@omuzgorpro.tj

# Telegram уведомления
./setup-telegram-alerts.sh

# Slack уведомления
./setup-slack-alerts.sh
```

## 📁 Структура после установки

```
/opt/prometheus/              # Prometheus сервер
/opt/grafana/                 # Grafana
/opt/alertmanager/            # Alertmanager
/etc/prometheus/              # Конфигурации
/var/lib/prometheus/          # Данные метрик
/var/lib/grafana/             # Данные Grafana
/root/monitoring-credentials.txt  # Данные доступа
```

## 🔑 Данные доступа

После установки данные сохранятся в:
- `/root/monitoring-credentials.txt` - Все данные доступа

**По умолчанию:**
- **Grafana**: admin / RTTIMonitor2024!
- **Prometheus**: без авторизации
- **Alertmanager**: без авторизации

## ✅ Проверка установки

```bash
# Проверка служб
systemctl status prometheus
systemctl status grafana-server
systemctl status alertmanager
systemctl status node_exporter

# Проверка портов
netstat -tlnp | grep -E "(9090|3000|9093|9100)"

# Проверка метрик
curl http://localhost:9090/api/v1/targets
```

## 🔧 Управление

### Prometheus
```bash
sudo systemctl restart prometheus
sudo systemctl reload prometheus
promtool check config /etc/prometheus/prometheus.yml
```

### Grafana
```bash
sudo systemctl restart grafana-server
sudo grafana-cli plugins list
sudo grafana-cli plugins install grafana-piechart-panel
```

### Alertmanager
```bash
sudo systemctl restart alertmanager
amtool check-config /etc/alertmanager/alertmanager.yml
```

## 📊 Добавление нового сервера

```bash
# Установка агентов на новом сервере
./install-remote-agents.sh 192.168.1.100

# Добавление в конфигурацию Prometheus
./add-server.sh "server-name" "192.168.1.100"

# Применение изменений
sudo systemctl reload prometheus
```

## 🔍 Запросы и метрики

### Полезные PromQL запросы
```promql
# Загрузка CPU
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Использование памяти
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Место на диске
100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)

# Подключения к БД
pg_stat_database_numbackends

# Nginx запросы
rate(nginx_http_requests_total[5m])
```

## 🆘 Устранение проблем

### Частые проблемы
1. **Prometheus не собирает метрики** - проверьте targets
2. **Grafana не показывает данные** - проверьте data source
3. **Алерты не работают** - проверьте Alertmanager конфигурацию
4. **Высокое потребление места** - настройте retention policy

### Диагностика
```bash
./diagnose-monitoring.sh      # Полная диагностика
./check-metrics.sh           # Проверка метрик
./test-alerts.sh            # Тест алертов
```

### Очистка данных
```bash
./cleanup-old-metrics.sh     # Очистка старых метрик
./rotate-logs.sh            # Ротация логов
```

## 🔒 Безопасность

### Защита доступа
```bash
./setup-auth.sh             # Настройка авторизации
./setup-ssl-monitoring.sh   # SSL для мониторинга
./configure-firewall.sh     # Настройка файрвола
```

## 📞 Поддержка

- **GitHub**: https://github.com/cheptura/LMS_Drupal/issues
- **Email**: admin@omuzgorpro.tj
- **Документация**: [RTTI LMS Wiki](https://github.com/cheptura/LMS_Drupal/wiki)
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/

---

**Версия**: 1.0  
**Дата**: Сентябрь 2025  
**Автор**: RTTI Development Team
