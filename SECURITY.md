# 🛡️ Безопасность серверов RTTI

## Обзор мер безопасности в установках Moodle и Drupal

### 📊 Сравнение защиты систем:

| Мера безопасности | Moodle LMS | Drupal Library | Описание |
|-------------------|------------|---------------|----------|
| **UFW Firewall** | ✅ | ✅ | Базовая защита портов (22, 80, 443) |
| **Автообновления** | ✅ | ✅ | Автоматические патчи безопасности |
| **Fail2Ban** | ✅ | ✅ | Защита от brute force атак |
| **Rate Limiting** | ✅ | ✅ | Защита от DDoS/перегрузки |
| **CSP Headers** | ✅ | ✅ | Content Security Policy |
| **HSTS** | ✅ | ✅ | Принудительное HTTPS |
| **PHP Hardening** | ✅ | ✅ | Безопасная конфигурация PHP |
| **Мониторинг** | ✅ | ✅ | Отслеживание активности |
| **Логирование** | ✅ | ✅ | Детальные логи безопасности |

---

## 🔥 Базовая защита (автоматически в обеих системах)

### 1. UFW Firewall
```bash
# Разрешенные порты:
22/tcp   - SSH (административный доступ)
80/tcp   - HTTP (перенаправление на HTTPS)
443/tcp  - HTTPS (основной веб-трафик)

# Все остальные порты заблокированы
```

### 2. Автоматические обновления безопасности
```bash
# Ежедневная проверка и установка:
- Обновления безопасности Ubuntu
- Патчи для всех установленных пакетов
- Автоматическая очистка кэша пакетов
```

---

## 🛡️ Углубленная защита (Fail2Ban + Rate Limiting)

### Защита от атак перебора (Fail2Ban)

#### Moodle:
- **Вход в систему**: блокировка после 5 неудачных попыток за 10 минут
- **Админ-панель**: блокировка при попытках доступа к /admin/
- **SSH**: блокировка после 3 неудачных попыток
- **Боты**: автоблокировка известных bad-bot'ов

#### Drupal:
- **Вход в систему**: блокировка после 5 неудачных попыток за 10 минут  
- **Админ-панель**: блокировка при попытках доступа к /admin/
- **SSH**: блокировка после 3 неудачных попыток
- **Боты**: автоблокировка известных bad-bot'ов

### Защита от DDoS (Rate Limiting)

#### Лимиты для Moodle:
```nginx
/login/index.php:  5 запросов/минуту
/admin/*:         30 запросов/минуту  
/repository/*:    10 запросов/минуту (загрузки)
Общий трафик:    200 запросов/минуту
Соединения:       25 одновременно на IP
```

#### Лимиты для Drupal:
```nginx
/user/login:       5 запросов/минуту
/admin/*:         30 запросов/минуту
API запросы:      30 запросов/минуту
Общий трафик:    100 запросов/минуту
Соединения:       20 одновременно на IP
```

---

## 🌐 Веб-безопасность (HTTP Headers)

### Заголовки безопасности (одинаковые для обеих систем):
```http
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

### Content Security Policy:

#### Moodle (поддержка YUI framework):
```http
Content-Security-Policy: 
  default-src 'self'; 
  script-src 'self' 'unsafe-eval' 'unsafe-inline' *.googleapis.com; 
  style-src 'self' 'unsafe-inline' *.googleapis.com; 
  img-src 'self' data: https:; 
  font-src 'self' data:;
```

#### Drupal:
```http
Content-Security-Policy: 
  default-src 'self'; 
  script-src 'self' 'unsafe-inline' 'unsafe-eval' *.googleapis.com; 
  style-src 'self' 'unsafe-inline' *.googleapis.com; 
  img-src 'self' data: *.gravatar.com;
```

---

## 🔧 PHP Безопасность

### Отключенные опасные функции:
```php
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
```

### Безопасные настройки:
```php
expose_php = Off              // Скрытие версии PHP
display_errors = Off          // Скрытие ошибок от пользователей  
allow_url_fopen = Off         // Блокировка удаленных включений
allow_url_include = Off       // Блокировка удаленных включений
max_execution_time = 300      // Лимит времени выполнения
memory_limit = 512M           // Лимит памяти
upload_max_filesize = 512M    // Лимит загрузки файлов
```

---

## 📊 Мониторинг и логирование

### Автоматический мониторинг (каждые 15 минут):
1. **Активные соединения** - предупреждение при >100 (Moodle) / >80 (Drupal)
2. **Попытки входа** - предупреждение при >50 попыток за час
3. **Дисковое пространство** - предупреждение при заполнении >85%
4. **Процессы PHP-FPM** - предупреждение при <3 процессов

### Файлы логов:

#### Moodle:
```bash
/var/log/moodle-security.log     # Общие события безопасности
/var/log/nginx/security.log      # Детальные веб-логи
/var/log/fail2ban.log           # События блокировки
/var/log/auth.log               # SSH попытки входа
```

#### Drupal:
```bash
/var/log/drupal-security.log     # Общие события безопасности  
/var/log/nginx/security.log      # Детальные веб-логи
/var/log/fail2ban.log           # События блокировки
/var/log/auth.log               # SSH попытки входа
```

---

## 🚨 Управление безопасностью

### Основные команды администратора:

#### Проверка статуса защиты:
```bash
# Статус файрвола
sudo ufw status verbose

# Статус Fail2Ban
sudo fail2ban-client status

# Активные блокировки
sudo fail2ban-client status moodle-auth    # для Moodle
sudo fail2ban-client status drupal-auth    # для Drupal

# Логи безопасности
sudo tail -f /var/log/moodle-security.log  # для Moodle
sudo tail -f /var/log/drupal-security.log  # для Drupal
```

#### Разблокировка IP:
```bash
# Если ваш IP заблокирован по ошибке
sudo fail2ban-client set moodle-auth unbanip ВАШ_IP    # Moodle
sudo fail2ban-client set drupal-auth unbanip ВАШ_IP    # Drupal
sudo fail2ban-client set ssh unbanip ВАШ_IP            # SSH
```

#### Добавление доверенного IP:
```bash
# Редактирование локальных правил Fail2Ban
sudo nano /etc/fail2ban/jail.local

# Добавить:
[DEFAULT]
ignoreip = 127.0.0.1/8 ВАШ_ДОВЕРЕННЫЙ_IP

# Перезапуск
sudo systemctl restart fail2ban
```

---

## 📈 Рекомендации по дополнительной защите

### 1. Изменение SSH порта (опционально):
```bash
# Изменить порт SSH с 22 на другой
sudo nano /etc/ssh/sshd_config
# Port 2222

sudo systemctl restart ssh
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp
```

### 2. Двухфакторная аутентификация:
- Настроить 2FA для административных аккаунтов в Moodle/Drupal
- Использовать ключи SSH вместо паролей

### 3. Backup стратегия:
```bash
# Автоматические бэкапы запускаются установочными скриптами
sudo ./backup-moodle.sh     # для Moodle
sudo ./backup-drupal.sh     # для Drupal
```

### 4. Регулярное обновление:
```bash
# Проверка доступных обновлений
sudo apt list --upgradable | grep security

# Обновление системы
sudo ./update-moodle.sh     # для Moodle  
sudo ./update-drupal.sh     # для Drupal
```

---

## ⚠️ Предупреждения безопасности

### Что НЕ делать:
❌ **Не отключайте Fail2Ban** - это основная защита от атак  
❌ **Не увеличивайте rate limits** без необходимости  
❌ **Не открывайте дополнительные порты** в файрволе  
❌ **Не используйте простые пароли** для админ-аккаунтов  
❌ **Не игнорируйте предупреждения** в логах безопасности  

### Что регулярно проверять:
✅ **Логи безопасности** - еженедельно  
✅ **Обновления системы** - автоматически установлены  
✅ **Активные соединения** - мониторятся автоматически  
✅ **Свободное место на диске** - мониторится автоматически  
✅ **Резервные копии** - создаются автоматически  

---

## 📞 Поддержка

При проблемах с безопасностью:

1. **Проверьте логи** `/var/log/*security.log`
2. **Запустите диагностику** `sudo ./diagnose-moodle.sh` или `sudo ./diagnose-drupal.sh`  
3. **Обратитесь к документации** в соответствующем README.md
4. **Создайте issue** в GitHub репозитории

**GitHub:** https://github.com/cheptura/LMS_Drupal  
**Автор:** cheptura  
**Проект:** RTTI LMS Infrastructure
