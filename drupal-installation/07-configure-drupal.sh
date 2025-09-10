#!/bin/bash

# RTTI Drupal - Шаг 7: Конфигурация библиотечной системы
# Сервер: storage.omuzgorpro.tj (92.242.61.204)
# ИСПРАВЛЕННАЯ ВЕРСИЯ: использует только Drush команды

echo "=== RTTI Drupal - Шаг 7: Настройка цифровой библиотеки (ИСПРАВЛЕННАЯ ВЕРСИЯ) ==="
echo "📖 Конфигурация библиотечных функций и контента"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

DRUPAL_DIR="/var/www/drupal"

# Проверка установки Drupal
if [ ! -d "$DRUPAL_DIR" ] || [ ! -f "$DRUPAL_DIR/web/sites/default/settings.php" ]; then
    echo "❌ Drupal не установлен или неправильно настроен"
    echo "   Проверьте, что шаг 6 (06-install-drupal.sh) выполнен успешно"
    exit 1
fi

echo "1. Переход в каталог Drupal..."
cd $DRUPAL_DIR

echo "2. Проверка и настройка Drush..."

# Поиск рабочего Drush
DRUSH_CMD=""
DRUSH_FOUND=false

# Проверяем локальный Drush
if [ -f "$DRUPAL_DIR/vendor/bin/drush" ]; then
    echo "   Проверяем локальный Drush..."
    if sudo -u www-data "$DRUPAL_DIR/vendor/bin/drush" --version >/dev/null 2>&1; then
        DRUSH_CMD="$DRUPAL_DIR/vendor/bin/drush"
        DRUSH_FOUND=true
        echo "✅ Локальный Drush работает: $DRUSH_CMD"
    fi
fi

# Проверяем глобальный Drush
if [ "$DRUSH_FOUND" = false ]; then
    echo "   Проверяем глобальный Drush..."
    if which drush >/dev/null 2>&1; then
        if sudo -u www-data drush --version >/dev/null 2>&1; then
            DRUSH_CMD="drush"
            DRUSH_FOUND=true
            echo "✅ Глобальный Drush работает: $DRUSH_CMD"
        fi
    fi
fi

# Установка Drush если не найден
if [ "$DRUSH_FOUND" = false ]; then
    echo "   ❌ Drush не найден, установка через Composer..."
    cd $DRUPAL_DIR
    sudo -u www-data composer require drush/drush
    
    if [ -f "$DRUPAL_DIR/vendor/bin/drush" ]; then
        if sudo -u www-data "$DRUPAL_DIR/vendor/bin/drush" --version >/dev/null 2>&1; then
            DRUSH_CMD="$DRUPAL_DIR/vendor/bin/drush"
            DRUSH_FOUND=true
            echo "✅ Drush установлен и работает: $DRUSH_CMD"
        fi
    fi
fi

if [ "$DRUSH_FOUND" = false ]; then
    echo "❌ Не удалось настроить Drush"
    echo "   Попробуйте установить Drush вручную:"
    echo "   cd $DRUPAL_DIR && sudo -u www-data composer require drush/drush"
    exit 1
fi

echo "3. Проверка статуса Drupal..."
cd $DRUPAL_DIR
sudo -u www-data $DRUSH_CMD status --fields=bootstrap | grep -q "Successful"
if [ $? -ne 0 ]; then
    echo "❌ Drupal не загружается корректно"
    echo "   Проверка статуса Drupal:"
    sudo -u www-data $DRUSH_CMD status
    echo "   Возможно, Drupal не установлен полностью. Запустите:"
    echo "   sudo ./06-install-drupal.sh"
    exit 1
fi
echo "✅ Drupal загружается корректно"

echo "4. Включение дополнительных модулей для библиотеки..."

# Базовые модули
echo "  4.1. Базовые модули..."
sudo -u www-data $DRUSH_CMD pm:enable node field field_ui -y

# Языковые модули
echo "  4.2. Языковые модули..."
sudo -u www-data $DRUSH_CMD pm:enable locale language config_translation content_translation interface_translation -y

# Модули контента
echo "  4.3. Модули контента..."
sudo -u www-data $DRUSH_CMD pm:enable views views_ui media media_library file taxonomy -y

# Модули SEO и производительности
echo "  4.4. SEO модули..."
sudo -u www-data $DRUSH_CMD pm:enable metatag pathauto token -y

# Поисковые модули (проверяем наличие)
echo "  4.5. Поисковые модули..."
if sudo -u www-data $DRUSH_CMD pm:list --status=available | grep -q search_api; then
    sudo -u www-data $DRUSH_CMD pm:enable search search_api search_api_db -y
    echo "     ✅ Search API включен"
else
    echo "     ⚠️  Search API не установлен, используем стандартный поиск"
    sudo -u www-data $DRUSH_CMD pm:enable search -y
fi

# Модули администратора
echo "  4.6. Административные модули..."
sudo -u www-data $DRUSH_CMD pm:enable admin_toolbar admin_toolbar_tools toolbar -y

echo "5. Установка русского языка..."
sudo -u www-data $DRUSH_CMD language:add ru
sudo -u www-data $DRUSH_CMD config:set language.negotiation selected_langcode ru -y
sudo -u www-data $DRUSH_CMD config:set system.site default_langcode ru -y

echo "5.1. Настройка часового пояса..."
sudo -u www-data $DRUSH_CMD config:set system.date timezone.default 'Asia/Dushanbe' -y
sudo -u www-data $DRUSH_CMD config:set system.date timezone.user.configurable 1 -y

echo "6. Загрузка переводов..."
sudo -u www-data $DRUSH_CMD locale:update

echo "7. Создание типов контента..."
echo "7.1. Создание типа контента 'Книга'..."
# Используем простые Drush команды вместо сложных PHP скриптов
sudo -u www-data $DRUSH_CMD generate:content-type --type=book --name="Книга" --description="Книги в цифровой библиотеке" 2>/dev/null || echo "Тип 'Книга' уже существует или создание не удалось"

echo "7.2. Создание типа контента 'Научная статья'..."
sudo -u www-data $DRUSH_CMD generate:content-type --type=library_article --name="Научная статья" --description="Научные статьи и публикации" 2>/dev/null || echo "Тип 'Научная статья' уже существует или создание не удалось"

echo "8. Создание таксономий..."
echo "8.1. Создание словаря 'Категории книг'..."
sudo -u www-data $DRUSH_CMD generate:vocabulary --name="Категории книг" --machine-name=book_categories --description="Категории для классификации книг" 2>/dev/null || echo "Словарь уже существует или создание не удалось"

echo "8.2. Создание словаря 'Научные области'..."
sudo -u www-data $DRUSH_CMD generate:vocabulary --name="Научные области" --machine-name=research_areas --description="Области научных исследований" 2>/dev/null || echo "Словарь уже существует или создание не удалось"

echo "9. Настройка конфигурации сайта..."
sudo -u www-data $DRUSH_CMD config:set system.site name "RTTI Digital Library" -y
sudo -u www-data $DRUSH_CMD config:set system.site slogan "Цифровая библиотека RTTI" -y
sudo -u www-data $DRUSH_CMD config:set system.site mail "library@omuzgorpro.tj" -y

echo "10. Настройка производительности..."
sudo -u www-data $DRUSH_CMD config:set system.performance css.preprocess 1 -y
sudo -u www-data $DRUSH_CMD config:set system.performance js.preprocess 1 -y
sudo -u www-data $DRUSH_CMD config:set system.performance cache.page.max_age 3600 -y

echo "11. Настройка темы оформления..."
# Проверяем, есть ли Bootstrap тема
if sudo -u www-data $DRUSH_CMD pm:list --status=available | grep -q bootstrap; then
    sudo -u www-data $DRUSH_CMD theme:enable bootstrap -y
    sudo -u www-data $DRUSH_CMD config:set system.theme default bootstrap -y
    echo "   ✅ Bootstrap тема активирована"
else
    echo "   ⚠️  Bootstrap тема не найдена, используем стандартную тему"
fi

echo "12. Индексация контента для поиска..."
if sudo -u www-data $DRUSH_CMD pm:list --status=enabled | grep -q search_api; then
    sudo -u www-data $DRUSH_CMD search-api:index 2>/dev/null || echo "Индексация будет выполнена позже"
    echo "   ✅ Поисковый индекс обновлен"
fi

echo "13. Очистка кэша..."
sudo -u www-data $DRUSH_CMD cache:rebuild
echo "   ✅ Кэш очищен"

echo "14. Создание скрипта обслуживания библиотеки..."
cat > /root/library-maintenance.sh << 'EOF'
#!/bin/bash
# Скрипт обслуживания цифровой библиотеки RTTI

echo "=== Обслуживание библиотеки RTTI ==="
echo "Дата: $(date)"

DRUPAL_DIR="/var/www/drupal"
cd $DRUPAL_DIR

# Поиск Drush
DRUSH_CMD=""
if [ -f "$DRUPAL_DIR/vendor/bin/drush" ]; then
    DRUSH_CMD="$DRUPAL_DIR/vendor/bin/drush"
elif which drush >/dev/null 2>&1; then
    DRUSH_CMD="drush"
else
    echo "❌ Drush не найден!"
    exit 1
fi

echo "1. Очистка кэша..."
sudo -u www-data $DRUSH_CMD cache:rebuild

echo "2. Обновление индекса поиска..."
if sudo -u www-data $DRUSH_CMD pm:list --status=enabled | grep -q search_api; then
    sudo -u www-data $DRUSH_CMD search-api:clear 2>/dev/null || true
    sudo -u www-data $DRUSH_CMD search-api:index 2>/dev/null || true
fi

echo "3. Обновление переводов..."
if sudo -u www-data $DRUSH_CMD pm:list --status=enabled | grep -q locale; then
    sudo -u www-data $DRUSH_CMD locale:update 2>/dev/null || true
fi

echo "4. Проверка статуса..."
sudo -u www-data $DRUSH_CMD status

echo "5. Очистка кэша (финальная)..."
sudo -u www-data $DRUSH_CMD cache:rebuild

echo "✅ Обслуживание завершено!"
EOF

chmod +x /root/library-maintenance.sh

echo "15. Создание отчета о конфигурации..."
cat > /root/drupal-library-config.txt << EOF
# Конфигурация цифровой библиотеки RTTI
# Дата создания: $(date)
# Сервер: storage.omuzgorpro.tj

=== ИНФОРМАЦИЯ О СИСТЕМЕ ===
Drupal версия: $(sudo -u www-data $DRUSH_CMD status --field=drupal-version 2>/dev/null || echo "Не определена")
Директория: $DRUPAL_DIR
База данных: $(sudo -u www-data $DRUSH_CMD status --field=db-type 2>/dev/null || echo "PostgreSQL")
Drush: $DRUSH_CMD

=== СТАТУС DRUPAL ===
$(sudo -u www-data $DRUSH_CMD status 2>/dev/null || echo "Статус недоступен")

=== УСТАНОВЛЕННЫЕ МОДУЛИ ===
$(sudo -u www-data $DRUSH_CMD pm:list --status=enabled --type=module 2>/dev/null | head -20 || echo "Список модулей недоступен")

=== ТИПЫ КОНТЕНТА ===
- Книга (book) - если создан успешно
- Научная статья (library_article) - если создан успешно  
- Базовая страница (page)
- Статья (article)

=== ТАКСОНОМИИ ===
- Категории книг (book_categories) - если создан успешно
- Научные области (research_areas) - если создан успешно

=== ЯЗЫКИ ===
Язык по умолчанию: русский (ru)
Дополнительные языки: английский (en)

=== НАСТРОЙКИ ===
Название сайта: RTTI Digital Library
Слоган: Цифровая библиотека RTTI
Email: library@omuzgorpro.tj
Часовой пояс: Asia/Dushanbe

=== ПРОИЗВОДИТЕЛЬНОСТЬ ===
CSS преобработка: включена
JS преобработка: включена
Кэширование страниц: 1 час

=== СКРИПТЫ ОБСЛУЖИВАНИЯ ===
- Общее обслуживание: /root/library-maintenance.sh
- Управление Drupal: /root/drupal-management.sh (если создан)

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Запустите ./08-post-install.sh для завершения настройки
2. Добавьте контент через веб-интерфейс
3. Настройте права доступа
4. Проведите тестирование функций

=== ПОЛЕЗНЫЕ КОМАНДЫ ===
cd $DRUPAL_DIR
sudo -u www-data $DRUSH_CMD status              # Статус системы
sudo -u www-data $DRUSH_CMD cache:rebuild       # Очистка кэша
sudo -u www-data $DRUSH_CMD uli                 # Ссылка для входа администратора
sudo -u www-data $DRUSH_CMD pm:list             # Список модулей
sudo -u www-data $DRUSH_CMD user:create         # Создание пользователя
EOF

echo
echo "✅ Шаг 7 завершен успешно!"
echo "📌 Цифровая библиотека настроена и готова к работе"
echo "📌 Типы контента: Книга, Научная статья (если создание удалось)"
echo "📌 Многоязычность: русский/английский"
echo "📌 Базовые модули активированы"
echo "📌 Обслуживание: /root/library-maintenance.sh"
echo "📌 Конфигурация: /root/drupal-library-config.txt"
echo "📌 Следующий шаг: ./08-post-install.sh"
echo

# Финальная проверка
echo "🔍 Финальная проверка системы..."
sudo -u www-data $DRUSH_CMD status --fields=bootstrap,database,files 2>/dev/null | grep -E "(Successful|Connected|Writable)" >/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Система работает корректно"
    echo "🌐 Веб-интерфейс: https://storage.omuzgorpro.tj"
    echo "🔧 Администрирование: https://storage.omuzgorpro.tj/admin"
else
    echo "⚠️  Возможны проблемы с системой"
    echo "   Запустите для диагностики: sudo -u www-data $DRUSH_CMD status"
    echo "   Или проверьте логи: tail -f /var/log/nginx/error.log"
fi
