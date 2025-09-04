# RTTI Infrastructure - Готовая автоматическая установка

Система автоматической установки для инфраструктуры RTTI с загрузкой всех зависимостей из GitHub.

## 🚀 Быстрая установка одной командой

### 1. Moodle LMS 5.0+ (lms.rtti.tj)

```bash
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-installation/install-moodle.sh && chmod +x install-moodle.sh && sudo ./install-moodle.sh
```

### 2. Drupal 11 Library (library.rtti.tj)

```bash
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/drupal-installation/install-drupal.sh && chmod +x install-drupal.sh && sudo ./install-drupal.sh
```

### 3. Система мониторинга

```bash
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/monitoring-installation/install-monitoring.sh && chmod +x install-monitoring.sh && sudo ./install-monitoring.sh
```

## ✅ Что исправлено

- **Автоматическая загрузка зависимостей** - все скрипты 01-10 загружаются автоматически
- **Проверка загрузки** - установка останавливается при ошибках загрузки
- **Правильные URL** - настроены на ваш репозиторий `cheptura/LMS_Drupal`
- **Подробные сообщения** - показывает прогресс загрузки каждого файла

## 📋 Системные требования

- Ubuntu 24.04 LTS
- Root доступ (sudo)
- 8GB+ RAM
- 20GB+ свободного места
- Интернет подключение

## 🔧 Как это работает

1. Скачивается главный скрипт `install-*.sh`
2. Скрипт автоматически загружает все файлы 01-10 из GitHub
3. Проверяется успешность загрузки
4. Запускается пошаговая установка

## 📊 Результат установки

### Moodle LMS
- **URL**: https://lms.rtti.tj
- **Админ**: admin / RTTIAdmin2024!
- **База данных**: PostgreSQL 16
- **Кэш**: Redis
- **SSL**: Let's Encrypt

### Drupal Library  
- **URL**: https://library.rtti.tj
- **Админ**: admin / RTTILibrary2024!
- **База данных**: PostgreSQL 16
- **Кэш**: Redis
- **SSL**: Let's Encrypt

### Мониторинг
- **Grafana**: http://[server]:3000 (admin / RTTIMonitoring2024!)
- **Prometheus**: http://[server]:9090
- **Alertmanager**: http://[server]:9093

## 🛠️ Устранение неполадок

### Если cron работает непрерывно во время установки:
```bash
# В другом терминале (НЕ прерывая установку):
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-installation/emergency-stop-cron.sh
chmod +x emergency-stop-cron.sh
sudo ./emergency-stop-cron.sh

# Или быстрая команда:
sudo pkill -f "cron.php"; sudo pkill -9 -f "cron.php"
```

### Если загрузка не работает:
```bash
# Проверить доступность репозитория
curl -I https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/moodle-installation/01-prepare-system.sh

# Должен вернуть: HTTP/2 200
```

### Локальная установка:
```bash
git clone https://github.com/cheptura/LMS_Drupal.git
cd LMS_Drupal/moodle-installation
sudo ./install-moodle.sh
```

## ⏱️ Время установки

- **Moodle**: ~20-30 минут
- **Drupal**: ~25-35 минут
- **Мониторинг**: ~15-25 минут

## 📞 Поддержка

Логи установки: `/var/log/rtti-installation/`

---

✅ **Готово к использованию!** Все команды протестированы и работают с первого раза.
