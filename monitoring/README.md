# 📊 Мониторинг LMS RTTI - Полная система наблюдения

Комплексные решения мониторинга для инфраструктуры **Moodle 5.0.2 + Drupal 11** RTTI с поддержкой **Prometheus + Grafana** и **Zabbix**.

## 🎯 Обзор систем мониторинга

### 🔵 Prometheus + Grafana + AlertManager
**Современный стек мониторинга с метриками и визуализацией**

✅ **Преимущества:**
- Высокопроизводительная база данных временных рядов
- Богатые возможности визуализации Grafana
- Гибкая система алертов
- Поддержка микросервисов и контейнеров
- REST API для интеграций

❌ **Недостатки:**
- Более сложная настройка
- Требует больше ресурсов
- Кривая обучения

### 🟠 Zabbix Server + Agent
**Классическое корпоративное решение мониторинга**

✅ **Преимущества:**
- Простота настройки и использования
- Встроенная система уведомлений
- Автообнаружение хостов и сервисов
- Готовые шаблоны мониторинга
- Низкие требования к ресурсам

❌ **Недостатки:**
- Менее гибкая система метрик
- Ограниченные возможности API
- Устаревший интерфейс

---

## 🚀 Быстрый старт

### 1️⃣ Prometheus Stack (рекомендуется для новых установок)

```bash
# Скачайте и запустите установку
cd /tmp
wget https://github.com/rtti-lms/setup/monitoring/install-prometheus-stack.sh
chmod +x install-prometheus-stack.sh
sudo ./install-prometheus-stack.sh
```

**Результат:** Полный стек с Prometheus (9090), Grafana (3000), AlertManager (9093)

### 2️⃣ Zabbix (рекомендуется для существующих сред)

```bash
# Установка Zabbix Server
cd /tmp
wget https://github.com/rtti-lms/setup/monitoring/install-zabbix.sh
chmod +x install-zabbix.sh
sudo ./install-zabbix.sh
# Выберите: 1 (Zabbix Server)
```

**Результат:** Zabbix Server с веб-интерфейсом и PostgreSQL

### 3️⃣ Только агенты (для дополнительных серверов)

```bash
# Установка агентов на существующие серверы
cd /tmp
wget https://github.com/rtti-lms/setup/monitoring/install-monitoring-agents.sh
chmod +x install-monitoring-agents.sh
sudo ./install-monitoring-agents.sh
# Выберите тип мониторинга: 1, 2 или 3
```

---

## 📋 Скрипты установки

| Скрипт | Назначение | Компоненты |
|--------|------------|------------|
| `install-prometheus-stack.sh` | Полный стек Prometheus | Prometheus, Grafana, AlertManager, Node Exporter, Nginx/PostgreSQL exporters |
| `install-zabbix.sh` | Сервер Zabbix | Zabbix Server, Web UI, PostgreSQL, Agent |
| `install-monitoring-agents.sh` | Агенты для серверов | Node Exporter и/или Zabbix Agent |

---

## 🏗️ Архитектура мониторинга

### Prometheus архитектура
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Grafana       │    │   Prometheus     │    │  AlertManager   │
│   :3000         │◄───┤   :9090          │───►│   :9093         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
            ┌───────▼───┐ ┌─────▼────┐ ┌────▼──────┐
            │Node Export│ │Nginx Exp.│ │PostgreSQL │
            │   :9100   │ │   :9113  │ │Exporter   │
            └───────────┘ └──────────┘ │   :9187   │
                                      └───────────┘
```

### Zabbix архитектура
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Zabbix Web    │    │   Zabbix Server  │    │   PostgreSQL    │
│   :80/zabbix    │◄───┤   :10051         │───►│   :5432         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
            ┌───────▼───┐ ┌─────▼────┐ ┌────▼──────┐
            │Zabbix Ag. │ │Zabbix Ag.│ │Zabbix Ag. │
            │   :10050  │ │   :10050 │ │   :10050  │
            │ (Moodle)  │ │ (Drupal) │ │ (Gateway) │
            └───────────┘ └──────────┘ └───────────┘
```

---

## 📊 Метрики мониторинга

### 🎯 Системные метрики
- **CPU**: использование, загрузка, количество ядер
- **Память**: использование RAM, swap, буферы
- **Диск**: использование, I/O операции, свободное место
- **Сеть**: трафик, пакеты, ошибки
- **Процессы**: количество, статус, время работы

### 🌐 Веб-приложения
- **Moodle**: доступность, время отклика, онлайн пользователи, cron задачи
- **Drupal**: доступность, время отклика, узлы, пользователи
- **Nginx**: активные соединения, запросы в секунду, статус
- **PHP-FPM**: активные процессы, очередь, время выполнения

### 🗄️ Базы данных
- **PostgreSQL**: подключения, запросы, блокировки, размер БД
- **Redis**: память, количество ключей, операции
- **Репликация**: статус, задержка

### 💾 Хранилище
- **NAS**: статус монтирования, доступность записи, свободное место
- **Резервные копии**: время последнего бэкапа, размер, статус

### 🔒 Безопасность
- **SSL сертификаты**: дни до истечения, валидность
- **Firewall**: активные правила, заблокированные соединения
- **Логи безопасности**: попытки входа, подозрительная активность

---

## 🔧 Конфигурация и настройка

### Prometheus Stack

#### Доступ к интерфейсам
```bash
# Prometheus
http://your-server:9090

# Grafana (admin/rtti_admin_2025)
http://your-server:3000

# AlertManager
http://your-server:9093

# Через Nginx прокси
http://monitoring.rtti.tj/prometheus/
http://monitoring.rtti.tj/grafana/
http://monitoring.rtti.tj/alertmanager/
```

#### Импорт дашбордов Grafana
```bash
# Рекомендуемые дашборды для импорта
1860  - Node Exporter Full
12708 - Nginx
9628  - PostgreSQL Database
3662  - Prometheus 2.0 Overview
```

#### Настройка алертов
```yaml
# Файл: /opt/prometheus/config/alertmanager.yml
# Замените email настройки
global:
  smtp_smarthost: 'your-smtp-server:587'
  smtp_from: 'monitoring@rtti.tj'
  smtp_auth_username: 'your-username'
  smtp_auth_password: 'your-password'

receivers:
- name: 'admin-email'
  email_configs:
  - to: 'admin@rtti.tj'
    subject: 'RTTI LMS Alert: {{ .GroupLabels.alertname }}'
```

### Zabbix

#### Доступ к веб-интерфейсу
```bash
# Zabbix Web Interface
http://your-server/zabbix

# Первоначальная настройка
Логин: Admin
Пароль: (пустой)
```

#### Импорт шаблонов
1. Administration → General → Macros → Add macros:
   - `{$MOODLE.URL}` = `http://localhost`
   - `{$DRUPAL.URL}` = `http://localhost`
   - `{$NAS.PATH}` = `/mnt/nas`

2. Configuration → Templates → Import
   - Загрузите файлы из `/tmp/zabbix_templates/`

#### Настройка уведомлений
1. Administration → Media types → Email
2. Configuration → Actions → Create action
3. Users → Admin → Media → Add email

---

## 🚨 Алерты и уведомления

### Критические алерты
- ❌ **Сервер недоступен** (5 минут)
- ❌ **Веб-приложение не отвечает** (3 минуты)
- ❌ **База данных недоступна** (2 минуты)
- ❌ **Диск заполнен** (< 10% свободного места)
- ❌ **NAS отключен** (1 минута)

### Предупреждения
- ⚠️ **Высокая загрузка CPU** (> 80%, 10 минут)
- ⚠️ **Высокое использование памяти** (> 85%, 10 минут)
- ⚠️ **Медленные запросы** (> 5 секунд)
- ⚠️ **SSL сертификат истекает** (< 30 дней)
- ⚠️ **Старые резервные копии** (> 24 часов)

### Информационные
- ℹ️ **Высокая активность пользователей**
- ℹ️ **Обновления системы доступны**
- ℹ️ **Успешные резервные копии**

---

## 🔍 Поиск и устранение неисправностей

### Prometheus Stack

#### Проверка сервисов
```bash
# Статус всех сервисов
systemctl status prometheus grafana-server alertmanager node_exporter

# Логи
journalctl -u prometheus -f
journalctl -u grafana-server -f

# Проверка конфигурации
/opt/prometheus/bin/promtool check config /opt/prometheus/config/prometheus.yml
/opt/prometheus/bin/promtool check rules /opt/prometheus/config/rules/*.yml
```

#### Общие проблемы
```bash
# Prometheus не собирает метрики
curl http://localhost:9090/api/v1/targets

# Grafana не может подключиться к Prometheus
curl http://localhost:9090/api/v1/query?query=up

# AlertManager не отправляет уведомления
curl http://localhost:9093/api/v1/alerts
```

### Zabbix

#### Проверка сервисов
```bash
# Статус сервисов
systemctl status zabbix-server zabbix-agent2

# Логи
tail -f /var/log/zabbix/zabbix_server.log
tail -f /var/log/zabbix/zabbix_agent2.log

# Тестирование агента
zabbix_agent2 -t system.uptime
```

#### Общие проблемы
```bash
# Агент не отвечает серверу
zabbix_get -s localhost -k system.uptime

# Проблемы с базой данных
sudo -u postgres psql -d zabbix -c "SELECT * FROM hosts LIMIT 5;"

# Проблемы с разрешениями
chown -R zabbix:zabbix /var/log/zabbix/
```

---

## 📈 Лучшие практики

### Производительность
1. **Retention политики**: настройте хранение метрик на 30-90 дней
2. **Sampling**: используйте разные интервалы для разных метрик
3. **Aggregation**: агрегируйте метрики для долгосрочного хранения
4. **Индексирование**: оптимизируйте запросы к базе данных

### Безопасность
1. **Firewall**: ограничьте доступ к портам мониторинга
2. **Authentication**: используйте сильные пароли и 2FA
3. **Encryption**: настройте HTTPS для веб-интерфейсов
4. **Backup**: регулярно создавайте резервные копии конфигураций

### Масштабирование
1. **Federation**: используйте федерацию Prometheus для больших сред
2. **Clustering**: настройте кластеризацию Zabbix для HA
3. **Load balancing**: распределите нагрузку между серверами мониторинга
4. **Automation**: автоматизируйте добавление новых хостов

---

## 🎛️ Дашборды и визуализация

### Готовые дашборды

#### Для Grafana
- **RTTI LMS Overview**: общий обзор всей инфраструктуры
- **Moodle Performance**: детальные метрики Moodle
- **Drupal Performance**: метрики производительности Drupal
- **Database Monitoring**: мониторинг PostgreSQL
- **System Resources**: системные ресурсы всех серверов

#### Для Zabbix
- **Network map**: сетевая карта инфраструктуры
- **Problems**: текущие проблемы и алерты
- **Latest data**: последние значения метрик
- **Graphs**: графики производительности

### Пользовательские метрики
```bash
# Prometheus
curl "http://localhost:9090/api/v1/query?query=up"

# Zabbix
zabbix_agent2 -t moodle.health
zabbix_agent2 -t drupal.health
zabbix_agent2 -t lms.nas.status
```

---

## 🔄 Интеграции

### Уведомления
- **Email**: SMTP интеграция
- **Slack**: webhook уведомления
- **Telegram**: bot API
- **SMS**: провайдер SMS услуг
- **PagerDuty**: корпоративные алерты

### API интеграции
```bash
# Prometheus API
curl http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes

# Grafana API
curl -H "Authorization: Bearer YOUR_API_KEY" http://localhost:3000/api/dashboards/home

# Zabbix API
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"host.get","params":{},"id":1}' \
  http://localhost/zabbix/api_jsonrpc.php
```

### Автоматизация
- **Ansible**: автоматическое развертывание агентов
- **Terraform**: инфраструктура как код
- **Docker**: контейнеризация компонентов мониторинга
- **Kubernetes**: оркестрация в кластере

---

## 📚 Дополнительные ресурсы

### Документация
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Zabbix Documentation](https://www.zabbix.com/documentation/6.4/ru)

### Полезные ссылки
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Gallery](https://grafana.com/grafana/dashboards/)
- [Zabbix Templates](https://www.zabbix.com/integrations)

### Сообщество
- [RTTI LMS Support](mailto:support@rtti.tj)
- [Prometheus Community](https://prometheus.io/community/)
- [Zabbix Forums](https://www.zabbix.com/forum/)

---

## 🏷️ Теги версий

- **v2.0** - Поддержка Moodle 5.0.2 + Drupal 11
- **v1.5** - Prometheus Stack + Zabbix опции
- **v1.0** - Базовый мониторинг

---

**📧 Поддержка**: [monitoring@rtti.tj](mailto:monitoring@rtti.tj)  
**🌐 Веб-сайт**: [https://lms.rtti.tj](https://lms.rtti.tj)  
**📖 Документация**: [https://docs.rtti.tj/monitoring](https://docs.rtti.tj/monitoring)
