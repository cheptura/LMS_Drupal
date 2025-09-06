# SSL Certificates для omuzgorpro.tj (Moodle)

## Описание
Эта директория содержит SSL сертификаты Let's Encrypt для домена `omuzgorpro.tj` (Moodle LMS).

## Структура файлов
```
moodle-ssl-certificates/
├── README.md              # Этот файл
├── omuzgorpro.tj/         # Сертификаты для Moodle домена
│   ├── cert.pem          # Основной сертификат
│   ├── chain.pem         # Цепочка сертификатов
│   ├── fullchain.pem     # Полная цепочка
│   ├── privkey.pem       # Приватный ключ
│   └── cert-info.txt     # Информация о сертификате
├── backup-moodle-ssl.sh  # Скрипт создания резервной копии
└── restore-moodle-ssl.sh # Скрипт восстановления
```

## Использование

### Автоматическое управление
Скрипт `05-configure-ssl.sh` в директории moodle-installation автоматически:
1. Проверяет наличие сертификатов в репозитории
2. Если найдены - устанавливает их
3. Если нет - выпускает новые через Let's Encrypt
4. Сохраняет новые сертификаты в репозиторий

### Ручное управление

#### Создание резервной копии текущих сертификатов
```bash
cd /path/to/LMS_Drupal
./moodle-ssl-certificates/backup-moodle-ssl.sh
```

#### Восстановление сертификатов из репозитория
```bash
cd /path/to/LMS_Drupal
sudo ./moodle-ssl-certificates/restore-moodle-ssl.sh
```

## Безопасность

⚠️ **ВАЖНО**: Приватные ключи (`privkey.pem`) содержат конфиденциальную информацию.
- В production НЕ храните приватные ключи в публичном репозитории
- Используйте приватный репозиторий или зашифрованное хранилище
- Регулярно обновляйте сертификаты (каждые 60-80 дней)

## Информация о сертификате

- **Домен**: omuzgorpro.tj
- **Провайдер**: Let's Encrypt
- **Срок действия**: 90 дней
- **Автообновление**: Настроено через cron

## Статус сертификата

```bash
# Проверка срока действия
openssl x509 -in /etc/letsencrypt/live/omuzgorpro.tj/cert.pem -noout -dates

# Проверка через браузер
curl -I https://omuzgorpro.tj

# Онлайн проверка
https://www.ssllabs.com/ssltest/analyze.html?d=omuzgorpro.tj
```

## Интеграция с Moodle

Сертификаты автоматически интегрируются с:
- Nginx конфигурацией для Moodle
- Настройками безопасности Moodle
- Системой автообновления

---
**Обновлено**: $(date)
