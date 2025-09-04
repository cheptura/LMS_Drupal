# Технические требования для LMS серверов (обновлено для Moodle 5.0.2 и Drupal 11)

## Минимальные системные требования

### Сервер Moodle 5.0.2 LMS
- **CPU**: 4-8 cores (2.4GHz+)
- **RAM**: 16GB (рекомендуется 32GB для продакшн)
- **Storage**: 200GB SSD (для начала, расширяемо)
- **Network**: 1Gbps
- **OS**: Ubuntu Server 24.04 LTS

### Сервер Drupal 11 Repository
- **CPU**: 4 cores (2.4GHz+)
- **RAM**: 8GB (рекомендуется 16GB)
- **Storage**: 500GB SSD (для хранения книг)
- **Network**: 1Gbps
- **OS**: Ubuntu Server 24.04 LTS

## Программное обеспечение

### Web Server Stack
```bash
# Nginx
nginx/1.24+

# PHP для Moodle 5.0.2
PHP 8.2+ с расширениями:
- php8.2-fpm
- php8.2-mysql/php8.2-pgsql
- php8.2-xml
- php8.2-gd
- php8.2-zip
- php8.2-mbstring
- php8.2-curl
- php8.2-intl
- php8.2-ldap
- php8.2-soap
- php8.2-xmlrpc
- php8.2-opcache
- php8.2-redis

# PHP для Drupal 11
PHP 8.3+ с расширениями:
# PHP для Drupal 11
PHP 8.3+ с расширениями:
- php8.3-fpm
- php8.3-mysql/php8.3-pgsql
- php8.3-xml
- php8.3-gd
- php8.3-zip
- php8.3-mbstring
- php8.3-curl
- php8.3-intl
- php8.3-bcmath
- php8.3-opcache
- php8.3-apcu

# Database
PostgreSQL 16+ или MySQL 8.4+

# Additional tools
Redis 7+
Node.js 20+ (для Drupal сборки)
Composer 2.7+
```

### Moodle 5.0.2 специфичные требования
```bash
# Версия
Moodle 5.0.2 (Latest stable)

# Обязательные плагины
- mod_scorm (для SCORM пакетов)
- auth_ldap (для интеграции)
- local_mobile (мобильное приложение)
- theme_boost (базовая тема)

# Новые функции в Moodle 5.0
- Улучшенная поддержка AI инструментов
- Расширенная аналитика
- Новый редактор TinyMCE 7
- Улучшенная производительность

# Рекомендуемые плагины
- plagiarism_turnitin (антиплагиат)
- mod_certificate (сертификаты)
- block_progress (прогресс курса)
- mod_hvp (интерактивный контент)
- local_ai (AI интеграция)
```

### Drupal 11 специфичные требования
```bash
# Версия
Drupal 11.x (LTS до 2029)

# Основные модули (входят в ядро)
- Views
- Taxonomy  
- File
- Media
- Layout Builder
- Content Moderation

# Дополнительные модули
- Search API (расширенный поиск)
- Facets (фасетированный поиск)  
- Paragraphs (гибкая структура контента)
- Admin Toolbar (улучшенная админка)
- Pathauto (автогенерация URL)
- Metatag (SEO оптимизация)
- Token (системные токены)
- Webform (формы)
- CKEditor 5 (редактор)

# Новые возможности Drupal 11
- Основан на Symfony 7
- Улучшенная производительность
- Новый автозагрузчик Composer
- Поддержка PHP 8.3
- Улучшенная система кэширования
```

## Конфигурация безопасности

### Системный уровень
```bash
# Firewall rules
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw deny incoming
ufw allow outgoing

# Fail2ban configuration
# /etc/fail2ban/jail.local
[sshd]
enabled = true
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
maxretry = 5
bantime = 1800
```

### Nginx конфигурация
```nginx
# /etc/nginx/sites-available/moodle
server {
    listen 443 ssl http2;
    server_name moodle.rtti.tj;
    
    ssl_certificate /etc/ssl/certs/moodle.rtti.tj.crt;
    ssl_certificate_key /etc/ssl/private/moodle.rtti.tj.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    root /var/www/moodle;
    index index.php;
    
    client_max_body_size 1024M;
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
        fastcgi_read_timeout 600;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
```

## Схема резервного копирования

### Еженедельное копирование ВМ
```bash
#!/bin/bash
# /opt/backup/vm-backup.sh

BACKUP_DIR="/mnt/nas/vm-backups"
DATE=$(date +%Y%m%d)
VM_NAME="moodle-lms"

# Создание снапшота
virsh snapshot-create-as $VM_NAME snapshot-$DATE

# Копирование на NAS
rsync -avz /var/lib/libvirt/images/$VM_NAME.qcow2 $BACKUP_DIR/$VM_NAME-$DATE.qcow2

# Ротация старых копий (хранить 4 недели)
find $BACKUP_DIR -name "$VM_NAME-*.qcow2" -mtime +28 -delete
```

### Ежедневное копирование БД
```bash
#!/bin/bash
# /opt/backup/db-backup.sh

DB_HOST="localhost"
DB_NAME="moodle"
DB_USER="backup_user"
BACKUP_DIR="/mnt/nas/db-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Полное копирование (воскресенье)
if [ $(date +%u) -eq 7 ]; then
    pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME | gzip > $BACKUP_DIR/full_$DB_NAME_$DATE.sql.gz
fi

# Инкрементное копирование (будни)
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME --schema-only | gzip > $BACKUP_DIR/schema_$DB_NAME_$DATE.sql.gz

# Ротация (хранить 30 дней)
find $BACKUP_DIR -name "*_$DB_NAME_*.sql.gz" -mtime +30 -delete
```

## Мониторинг и логирование

### Системные метрики
- CPU usage > 80%
- Memory usage > 90%
- Disk space > 85%
- Network errors
- Load average > cores count

### Application метрики
- Response time > 5s
- Error rate > 1%
- Database connections > 80% pool
- PHP-FPM queue length

### Логи для мониторинга
```bash
# Nginx access/error logs
/var/log/nginx/moodle_access.log
/var/log/nginx/moodle_error.log

# PHP logs
/var/log/php8.1-fpm.log

# Application logs
/var/www/moodle/data/error.log
/var/www/drupal/sites/default/files/logs/error.log

# System logs
/var/log/syslog
/var/log/auth.log
```

## Производительность и оптимизация

### PHP-FPM настройки
```ini
; /etc/php/8.1/fpm/pool.d/www.conf
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 1000

; Memory limits
memory_limit = 512M
upload_max_filesize = 1024M
post_max_size = 1024M
max_execution_time = 300
```

### Database оптимизация
```sql
-- PostgreSQL оптимизация для Moodle
-- postgresql.conf
shared_buffers = 2GB
effective_cache_size = 6GB
work_mem = 64MB
maintenance_work_mem = 512MB
checkpoint_completion_target = 0.9
wal_buffers = 64MB
default_statistics_target = 100
```

### Кэширование
```php
// Moodle config.php кэширование
$CFG->cachejs = true;
$CFG->cachecss = true;
$CFG->langstringcache = true;

// Redis сессии
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = '127.0.0.1';
$CFG->session_redis_port = 6379;
```
