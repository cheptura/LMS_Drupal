# RTTI Monitoring System - Полная установка

Система мониторинга для RTTI LMS инфраструктуры с Prometheus, Grafana и Alertmanager.

## 🎯 Целевой сервер

- **Основной сервер**: lms.rtti.tj (92.242.60.172)
- **Мониторинг**: library.rtti.tj (92.242.61.204)
- **ОС**: Ubuntu Server 24.04 LTS

## 🚀 Быстрая установка

### Одной командой
```bash
wget -O install-monitoring.sh https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring-installation/install-monitoring.sh
chmod +x install-monitoring.sh
sudo ./install-monitoring.sh
```

### Локальная установка
```bash
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/monitoring-installation
chmod +x *.sh
sudo ./install-monitoring.sh
```

## 📝 Пошаговая установка

```bash
sudo ./01-prepare-monitoring.sh     # Подготовка системы
sudo ./02-install-prometheus.sh     # Prometheus сервер
sudo ./03-install-grafana.sh        # Grafana дашборды
sudo ./04-install-alertmanager.sh   # Система алертов
sudo ./05-install-exporters.sh      # Node/Nginx/Postgres exporters
sudo ./06-configure-alerts.sh       # Настройка правил алертов
sudo ./07-setup-dashboards.sh       # Импорт дашбордов
sudo ./08-configure-remote.sh       # Мониторинг удаленных серверов
sudo ./09-setup-backup.sh          # Резервное копирование
sudo ./10-test-monitoring.sh       # Тестирование системы
```

## 🔧 Технические характеристики

### Программное обеспечение
- **Prometheus**: 2.45+ (метрики и алерты)
- **Grafana**: 10.0+ (визуализация)
- **Alertmanager**: 0.25+ (уведомления)
- **Node Exporter**: 1.6+ (системные метрики)
- **Nginx Exporter**: 0.11+ (веб-сервер метрики)
- **Postgres Exporter**: 0.13+ (БД метрики)

### Системные требования
- **CPU**: 2+ cores
- **RAM**: 4GB (рекомендуется 8GB)
- **Storage**: 100GB+ SSD
- **Network**: 1Gbps

## 📊 Компоненты мониторинга

### 🔍 Prometheus
- **Порт**: 9090
- **URL**: http://lms.rtti.tj:9090
- **Функции**: Сбор метрик, правила алертов
- **Хранение**: 30 дней данных

### 📈 Grafana
- **Порт**: 3000
- **URL**: http://lms.rtti.tj:3000
- **Данные**: admin / RTTIMonitor2024!
- **Функции**: Дашборды, визуализация

### 🚨 Alertmanager
- **Порт**: 9093
- **URL**: http://lms.rtti.tj:9093
- **Функции**: Управление алертами, уведомления

### 📡 Exporters
- **Node Exporter**: 9100 (системные метрики)
- **Nginx Exporter**: 9113 (веб-сервер)
- **Postgres Exporter**: 9187 (база данных)
- **Redis Exporter**: 9121 (кэш)

## 📊 Мониторинг серверов

### 🎓 Moodle сервер (lms.rtti.tj)
- Системные ресурсы (CPU, RAM, Disk)
- Nginx производительность
- PHP-FPM метрики
- PostgreSQL статистика
- Redis статистика
- Moodle специфичные метрики

### 📚 Drupal сервер (library.rtti.tj)
- Системные ресурсы
- Nginx производительность
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
./setup-email-alerts.sh admin@rtti.tj

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
- **Email**: admin@rtti.tj
- **Документация**: [RTTI LMS Wiki](https://github.com/cheptura/LMS_Drupal/wiki)
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/

---

**Версия**: 1.0  
**Дата**: Сентябрь 2025  
**Автор**: RTTI Development Team
