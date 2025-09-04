# Руководство по устранению неполадок LMS RTTI
## Moodle 5.0.2 + Drupal 11 + NAS интеграция

### 🚨 Критические проблемы

#### Сайт полностью недоступен

**Симптомы:**
- HTTP 500/502/503 ошибки
- Timeout при подключении
- DNS не резолвится

**Диагностика:**
```bash
# Проверка статуса сервисов
sudo systemctl status nginx php8.2-fpm php8.3-fpm postgresql redis-server

# Проверка логов
sudo tail -f /var/log/nginx/error.log
sudo journalctl -f -u nginx

# Проверка портов
sudo netstat -tlnp | grep -E ':80|:443'

# Проверка DNS
nslookup lms.rtti.tj
nslookup library.rtti.tj
```

**Решения:**
1. **Перезапуск сервисов:**
   ```bash
   sudo systemctl restart nginx
   sudo systemctl restart php8.2-fpm php8.3-fpm
   sudo systemctl restart postgresql
   ```

2. **Проверка конфигурации Nginx:**
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. **Проверка места на диске:**
   ```bash
   df -h
   # Если диск полный - очистить логи и временные файлы
   sudo journalctl --vacuum-time=7d
   sudo find /tmp -type f -mtime +7 -delete
   ```

#### База данных недоступна

**Симптомы:**
- "Database connection failed"
- Медленная загрузка страниц
- Ошибки при входе в систему

**Диагностика:**
```bash
# Проверка PostgreSQL
sudo systemctl status postgresql
sudo -u postgres psql -l

# Проверка подключений
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# Проверка места в базе
sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('moodle'));"
sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('drupal_library'));"
```

**Решения:**
1. **Перезапуск PostgreSQL:**
   ```bash
   sudo systemctl restart postgresql
   ```

2. **Оптимизация базы данных:**
   ```bash
   # Для Moodle
   sudo -u postgres psql moodle -c "VACUUM ANALYZE;"
   
   # Для Drupal
   sudo -u postgres psql drupal_library -c "VACUUM ANALYZE;"
   ```

3. **Проверка блокировок:**
   ```bash
   sudo -u postgres psql -c "SELECT * FROM pg_locks WHERE NOT granted;"
   ```

### ⚠️ Проблемы производительности

#### Медленная загрузка Moodle

**Диагностика:**
```bash
# Проверка использования ресурсов
htop
iotop
nethogs

# Проверка PHP процессов
sudo systemctl status php8.2-fpm
sudo tail -f /var/log/php8.2-fpm.log

# Проверка OPcache
php -i | grep opcache
```

**Решения:**
1. **Оптимизация PHP:**
   ```bash
   # Увеличение лимитов в /etc/php/8.2/fpm/php.ini
   memory_limit = 512M
   max_execution_time = 300
   
   # Перезапуск PHP-FPM
   sudo systemctl restart php8.2-fpm
   ```

2. **Очистка кэша Moodle:**
   ```bash
   cd /var/www/moodle
   sudo -u www-data php admin/cli/purge_caches.php
   ```

3. **Проверка Redis:**
   ```bash
   redis-cli ping
   redis-cli info memory
   redis-cli flushall  # ОСТОРОЖНО: очищает весь кэш
   ```

#### Медленная загрузка Drupal

**Диагностика:**
```bash
# Проверка статуса Drupal
cd /var/www/drupal
sudo -u www-data drush status

# Проверка кэша
sudo -u www-data drush cr
```

**Решения:**
1. **Очистка кэша Drupal:**
   ```bash
   sudo -u www-data drush cr
   sudo -u www-data drush cc all
   ```

2. **Оптимизация базы данных:**
   ```bash
   sudo -u www-data drush sql:query "OPTIMIZE TABLE cache_data;"
   ```

### 🔗 Проблемы с NAS интеграцией

#### NAS недоступен

**Симптомы:**
- Файлы не загружаются
- Ошибки при сохранении контента
- "Mount point not available"

**Диагностика:**
```bash
# Проверка монтирования
mountpoint /mnt/nas
df -h | grep nas

# Проверка сетевого подключения к NAS
ping NAS_IP
telnet NAS_IP 445

# Проверка CIFS соединения
sudo mount -t cifs //NAS_IP/share /mnt/test -o username=user
```

**Решения:**
1. **Перемонтирование NAS:**
   ```bash
   sudo umount /mnt/nas
   sudo mount -a
   ```

2. **Проверка учетных данных:**
   ```bash
   # Обновление /etc/samba/nas-credentials
   sudo nano /etc/samba/nas-credentials
   sudo chmod 600 /etc/samba/nas-credentials
   ```

3. **Диагностика сети:**
   ```bash
   # Проверка маршрутизации
   traceroute NAS_IP
   
   # Проверка портов
   nmap -p 445,139 NAS_IP
   ```

#### Проблемы с правами доступа к NAS

**Симптомы:**
- "Permission denied" при записи файлов
- Файлы создаются с неправильными правами

**Решения:**
```bash
# Проверка текущих прав
ls -la /mnt/nas/

# Исправление прав доступа
sudo chown -R www-data:www-data /mnt/nas/moodledata
sudo chown -R www-data:www-data /mnt/nas/drupal-files
sudo chmod -R 775 /mnt/nas/

# Обновление fstab с правильными параметрами
sudo nano /etc/fstab
# Добавить: uid=www-data,gid=www-data,file_mode=0664,dir_mode=0775
```

### 🔐 Проблемы с SSL и безопасностью

#### SSL сертификат истек

**Симптомы:**
- Браузер показывает предупреждение о безопасности
- "SSL certificate expired"

**Решения:**
```bash
# Проверка статуса сертификатов
sudo certbot certificates

# Обновление сертификатов
sudo certbot renew --dry-run
sudo certbot renew

# Перезагрузка Nginx
sudo systemctl reload nginx
```

#### Fail2Ban блокирует легитимных пользователей

**Диагностика:**
```bash
# Проверка статуса Fail2Ban
sudo fail2ban-client status

# Проверка заблокированных IP
sudo fail2ban-client status nginx-http-auth
sudo fail2ban-client status sshd
```

**Решения:**
```bash
# Разблокировка IP адреса
sudo fail2ban-client set nginx-http-auth unbanip IP_ADDRESS
sudo fail2ban-client set sshd unbanip IP_ADDRESS

# Добавление IP в whitelist
sudo nano /etc/fail2ban/jail.local
# Добавить: ignoreip = 127.0.0.1/8 YOUR_IP
sudo systemctl restart fail2ban
```

### 📁 Проблемы с файлами и загрузками

#### Большие файлы не загружаются

**Симптомы:**
- Загрузка прерывается на больших файлах
- Timeout при загрузке видео

**Решения:**
1. **Увеличение лимитов PHP:**
   ```bash
   sudo nano /etc/php/8.2/fpm/php.ini
   # Установить:
   upload_max_filesize = 2048M
   post_max_size = 2048M
   max_execution_time = 300
   max_input_time = 300
   
   sudo systemctl restart php8.2-fpm
   ```

2. **Увеличение лимитов Nginx:**
   ```bash
   sudo nano /etc/nginx/nginx.conf
   # Добавить в http блок:
   client_max_body_size 2048M;
   
   sudo systemctl reload nginx
   ```

#### Проблемы с правами на файлы

**Решения:**
```bash
# Исправление прав Moodle
sudo chown -R www-data:www-data /var/www/moodle
sudo chown -R www-data:www-data /var/moodledata
sudo chmod -R 755 /var/www/moodle
sudo chmod -R 770 /var/moodledata

# Исправление прав Drupal
sudo chown -R www-data:www-data /var/www/drupal
sudo chmod -R 755 /var/www/drupal
sudo chmod 777 /var/www/drupal/web/sites/default/files
```

### 🔄 Проблемы с резервным копированием

#### Backup скрипт не работает

**Диагностика:**
```bash
# Проверка cron заданий
sudo crontab -l
sudo systemctl status cron

# Проверка логов backup
sudo tail -f /var/log/lms-backup.log
sudo tail -f /var/log/nas-backup.log
```

**Решения:**
1. **Ручной запуск backup:**
   ```bash
   sudo /opt/nas-backup.sh daily
   ```

2. **Проверка прав на скрипт:**
   ```bash
   sudo chmod +x /opt/nas-backup.sh
   sudo chown root:root /opt/nas-backup.sh
   ```

3. **Проверка места для backup:**
   ```bash
   df -h /mnt/nas
   ```

### 🔧 Проблемы с интеграцией

#### SSO не работает между Moodle и Drupal

**Диагностика:**
```bash
# Проверка модулей интеграции
cd /var/www/moodle
sudo -u www-data php admin/cli/plugin_check.php

cd /var/www/drupal
sudo -u www-data drush pm:list | grep auth
```

**Решения:**
1. **Проверка конфигурации SSO:**
   ```bash
   # Проверка настроек в Moodle
   grep -r "external_auth" /var/www/moodle/config.php
   
   # Проверка настроек в Drupal
   sudo -u www-data drush config:get simplesamlphp_auth.settings
   ```

2. **Синхронизация пользователей:**
   ```bash
   # В Moodle
   cd /var/www/moodle
   sudo -u www-data php admin/cli/sync_users.php
   
   # В Drupal
   cd /var/www/drupal
   sudo -u www-data drush user:sync
   ```

### 📊 Мониторинг и диагностика

#### Полезные команды для диагностики

**Системная информация:**
```bash
# Общая информация о системе
uname -a
lsb_release -a
free -h
df -h

# Сетевая информация
ip addr show
ss -tulpn

# Процессы и нагрузка
top
ps aux | grep -E 'nginx|php|postgres'
```

**Логи для анализа:**
```bash
# Системные логи
sudo journalctl -f

# Web-сервер логи
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# PHP логи
sudo tail -f /var/log/php8.2-fpm.log
sudo tail -f /var/log/php8.3-fpm.log

# База данных логи
sudo tail -f /var/log/postgresql/postgresql-16-main.log

# Приложения логи
sudo tail -f /var/www/moodle/config.php  # Проверка настроек
cd /var/www/drupal && sudo -u www-data drush watchdog:show
```

### 📞 Контакты для экстренной поддержки

**Уровень 1 (Базовая поддержка):**
- Email: support@rtti.tj
- Телефон: +992 XX XXX XXXX
- Время работы: 9:00-18:00 (UTC+5)

**Уровень 2 (Техническая поддержка):**
- Email: tech@rtti.tj
- Telegram: @rtti_tech_support
- Время работы: 24/7 (критические проблемы)

**Уровень 3 (Экспертная поддержка):**
- Email: admin@rtti.tj
- Экстренная линия: +992 XX XXX XXXX
- Время работы: По вызову

### 📝 Чек-лист для решения проблем

1. **Первичная диагностика:**
   - [ ] Проверить статус всех сервисов
   - [ ] Проверить место на диске
   - [ ] Проверить сетевое подключение
   - [ ] Проверить логи ошибок

2. **Глубокая диагностика:**
   - [ ] Проанализировать логи за последние 24 часа
   - [ ] Проверить производительность системы
   - [ ] Проверить целостность данных
   - [ ] Проверить резервные копии

3. **Документирование:**
   - [ ] Записать симптомы проблемы
   - [ ] Сохранить релевантные логи
   - [ ] Задокументировать примененные решения
   - [ ] Обновить базу знаний

---

*Данное руководство обновляется по мере выявления новых проблем и их решений. Для получения последней версии посетите документацию проекта.*
