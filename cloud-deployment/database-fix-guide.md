# Решение проблем с базами данных - Moodle + Drupal

## Проблемы
При повторной установке возникают ошибки:
```
ERROR: database "moodle" already exists
ERROR: database "drupal" already exists
```

## Решения для Moodle

### 1. Автоматическое решение (рекомендуется)
Запустите установочный скрипт с параметром `cleanup`:

```bash
./install-moodle-cloud.sh cleanup
```

### 2. Полная переустановка Moodle
Используйте специальный скрипт для полной переустановки:

```bash
# Загрузите скрипт переустановки
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/reinstall-moodle.sh
chmod +x reinstall-moodle.sh

# Запустите полную переустановку
sudo ./reinstall-moodle.sh
```

### 3. Ручная очистка Moodle
Если нужно выполнить очистку вручную:

```bash
# Остановить Nginx
sudo systemctl stop nginx

# Удалить базу данных Moodle
sudo -u postgres psql -c "DROP DATABASE IF EXISTS moodle;"
sudo -u postgres psql -c "DROP USER IF EXISTS moodleuser;"

# Удалить файлы Moodle
sudo rm -rf /var/www/html/moodle
sudo rm -rf /var/moodledata
sudo rm -f /root/moodle-credentials.txt

# Удалить конфигурацию Nginx
sudo rm -f /etc/nginx/sites-available/moodle
sudo rm -f /etc/nginx/sites-enabled/moodle

# Запустить Nginx
sudo systemctl start nginx

# Запустить обычную установку
./install-moodle-cloud.sh
```

## Решения для Drupal

### 1. Автоматическое решение (рекомендуется)
Запустите установочный скрипт с параметром `cleanup`:

```bash
./install-drupal-cloud.sh cleanup
```

### 2. Полная переустановка Drupal
Используйте специальный скрипт для полной переустановки:

```bash
# Загрузите скрипт переустановки
wget https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/reinstall-drupal.sh
chmod +x reinstall-drupal.sh

# Запустите полную переустановку
sudo ./reinstall-drupal.sh
```

### 3. Ручная очистка Drupal
Если нужно выполнить очистку вручную:

```bash
# Остановить Nginx
sudo systemctl stop nginx

# Удалить базу данных Drupal
sudo -u postgres psql -c "DROP DATABASE IF EXISTS drupal;"
sudo -u postgres psql -c "DROP USER IF EXISTS drupaluser;"

# Удалить файлы Drupal
sudo rm -rf /var/www/html/drupal
sudo rm -f /root/drupal-credentials.txt

# Удалить конфигурацию Nginx
sudo rm -f /etc/nginx/sites-available/drupal
sudo rm -f /etc/nginx/sites-enabled/drupal

# Запустить Nginx
sudo systemctl start nginx

# Запустить обычную установку
./install-drupal-cloud.sh
```

## Полная очистка обеих систем

Если нужно полностью переустановить и Moodle, и Drupal:

```bash
# Очистка Moodle
./reinstall-moodle.sh

# Очистка Drupal  
./reinstall-drupal.sh
```

## Причины проблем
- Предыдущая неудачная установка
- Остатки от предыдущей версии
- Прерванная установка
- Конфликты при тестировании

## Профилактика
- Всегда используйте `cleanup` параметр при переустановке
- Регулярно делайте резервные копии перед обновлениями
- Тестируйте установку на staging среде
- Используйте скрипты переустановки для полной очистки

## Поддержка
Если проблема не решается:
1. Проверьте логи PostgreSQL: `/var/log/postgresql/postgresql-16-main.log`
2. Убедитесь в правах доступа: `sudo -u postgres psql -l`
3. Проверьте статус служб: `systemctl status nginx postgresql`
4. Обратитесь в поддержку: [GitHub Issues](https://github.com/cheptura/LMS_Drupal/issues)
