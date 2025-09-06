# Статус локализации LMS системы

## Дата обновления: 6 сентября 2025

---

## 🌍 Общие настройки локализации

### Системный уровень
- **Локаль**: `ru_RU.UTF-8` (установлена как основная)
- **Часовой пояс**: `Asia/Dushanbe`
- **Кодировка**: UTF-8
- **Страна**: Таджикистан (TJ)

---

## 📚 Moodle LMS

### База данных PostgreSQL
- **Кодировка**: UTF-8
- **Коллация**: ru_RU.UTF-8
- **Тип символов**: ru_RU.UTF-8
- **Часовой пояс БД**: Asia/Dushanbe ✅

### Настройки приложения
- **Язык по умолчанию**: Русский (ru)
- **Часовой пояс**: Asia/Dushanbe
- **Страна**: Таджикистан (TJ)
- **Локализация**: Полная русификация интерфейса

### Файл конфигурации
```php
$CFG->lang = 'ru';
$CFG->timezone = 'Asia/Dushanbe';
$CFG->country = 'TJ';
```

---

## 📖 Drupal Digital Library

### База данных PostgreSQL
- **Кодировка**: UTF-8
- **Коллация**: ru_RU.UTF-8
- **Тип символов**: ru_RU.UTF-8
- **Часовой пояс БД**: Asia/Dushanbe ✅

### Настройки приложения
- **Язык по умолчанию**: Русский (ru)
- **Часовой пояс**: Asia/Dushanbe
- **Язык интерфейса**: Русский
- **Переводы**: Автоматическая загрузка русских переводов

### Drush команды локализации
```bash
drush language:add ru
drush config:set language.negotiation selected_langcode ru
drush config:set system.site default_langcode ru
drush config:set system.date timezone.default 'Asia/Dushanbe'
```

### Установленные модули локализации
- ✅ language (Языки)
- ✅ locale (Интерфейс перевода)
- ✅ config_translation (Перевод конфигурации)
- ✅ content_translation (Перевод контента)

---

## 📊 Система мониторинга

### Grafana
- **Часовой пояс**: Asia/Dushanbe ✅
- **Переменные окружения**:
  - `GF_DATE_FORMATS_DEFAULT_TIMEZONE=Asia/Dushanbe`
  - `TZ=Asia/Dushanbe`

### Дашборды
- **Часовой пояс всех дашбордов**: Asia/Dushanbe ✅
- **Форматы времени**: Локальные для Таджикистана

### Prometheus
- **Часовой пояс**: Системный (Asia/Dushanbe)
- **Метки времени**: UTC с локальным отображением

---

## 🔧 Технические детали

### Файлы конфигурации
| Компонент | Файл | Параметр локализации |
|-----------|------|---------------------|
| System | `/etc/locale.gen` | ru_RU.UTF-8 UTF-8 |
| Moodle DB | PostgreSQL | LC_COLLATE=ru_RU.UTF-8 |
| Drupal DB | PostgreSQL | LC_COLLATE=ru_RU.UTF-8 |
| Moodle App | `config.php` | $CFG->lang='ru' |
| Drupal App | Drush | language:add ru |
| Grafana | Docker env | GF_DATE_FORMATS_DEFAULT_TIMEZONE |

### Процедуры установки
1. **01-prepare-system.sh**: Генерация ru_RU.UTF-8 локали
2. **03-install-database.sh**: Создание БД с русской коллацией
3. **07-configure-*.sh**: Настройка приложений на русский язык

---

## ✅ Статус проверки

- [x] Системная локаль ru_RU.UTF-8
- [x] Часовой пояс Asia/Dushanbe на всех уровнях
- [x] База данных Moodle с русской коллацией
- [x] База данных Drupal с русской коллацией
- [x] Русский интерфейс Moodle
- [x] Русский интерфейс Drupal
- [x] Русские переводы загружены
- [x] Мониторинг настроен на локальное время
- [x] Все дашборды используют Asia/Dushanbe

---

## 🚀 Результат

**✅ ПОЛНАЯ ЛОКАЛИЗАЦИЯ ЗАВЕРШЕНА**

Все компоненты LMS системы настроены для работы на русском языке с правильным часовым поясом Таджикистана (Asia/Dushanbe).

### Проверка после установки
```bash
# Проверка системной локали
locale

# Проверка часового пояса
timedatectl

# Проверка базы данных Moodle
PGPASSWORD='пароль' psql -h localhost -U moodleuser -d moodle -c "SHOW timezone;"

# Проверка базы данных Drupal
PGPASSWORD='пароль' psql -h localhost -U drupaluser -d drupal_library -c "SHOW timezone;"
```

---

*Документ создан автоматически системой установки LMS*
