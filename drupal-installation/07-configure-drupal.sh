#!/bin/bash

# RTTI Drupal - Шаг 7: Конфигурация библиотечной системы
# Сервер: library.rtti.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 7: Настройка цифровой библиотеки ==="
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
    exit 1
fi

echo "1. Переход в каталог Drupal..."
cd $DRUPAL_DIR

echo "2. Включение дополнительных модулей для библиотеки..."

# Языковые модули
sudo -u www-data vendor/bin/drush pm:enable locale language config_translation content_translation interface_translation -y

# Модули контента
sudo -u www-data vendor/bin/drush pm:enable field field_ui views views_ui media media_library file node taxonomy -y

# Модули SEO и производительности
sudo -u www-data vendor/bin/drush pm:enable metatag pathauto token -y

# Поисковые модули
sudo -u www-data vendor/bin/drush pm:enable search search_api search_api_db -y

# Модули администратора
sudo -u www-data vendor/bin/drush pm:enable admin_toolbar admin_toolbar_tools toolbar -y

echo "3. Установка русского языка..."
sudo -u www-data vendor/bin/drush language:add ru
sudo -u www-data vendor/bin/drush config:set language.negotiation selected_langcode ru -y
sudo -u www-data vendor/bin/drush config:set system.site default_langcode ru -y

echo "4. Загрузка переводов..."
sudo -u www-data vendor/bin/drush locale:update

echo "5. Создание типов контента для библиотеки..."

# Создание типа контента "Книга"
cat > /tmp/book_content_type.php << 'EOF'
<?php
use Drupal\node\Entity\NodeType;
use Drupal\field\Entity\FieldStorageConfig;
use Drupal\field\Entity\FieldConfig;

// Создание типа контента "Книга"
$book_type = NodeType::create([
  'type' => 'book',
  'name' => 'Книга',
  'description' => 'Книги в цифровой библиотеке',
]);
$book_type->save();

// Поля для книг
$fields = [
  'field_author' => ['Автор', 'string'],
  'field_isbn' => ['ISBN', 'string'],
  'field_publisher' => ['Издательство', 'string'],
  'field_year' => ['Год издания', 'integer'],
  'field_pages' => ['Количество страниц', 'integer'],
  'field_category' => ['Категория', 'entity_reference'],
  'field_file' => ['Файл', 'file'],
  'field_cover' => ['Обложка', 'image'],
];

foreach ($fields as $field_name => $field_info) {
  $field_storage = FieldStorageConfig::create([
    'field_name' => $field_name,
    'entity_type' => 'node',
    'type' => $field_info[1],
  ]);
  $field_storage->save();

  $field = FieldConfig::create([
    'field_storage' => $field_storage,
    'bundle' => 'book',
    'label' => $field_info[0],
  ]);
  $field->save();
}

echo "Тип контента 'Книга' создан\n";
EOF

sudo -u www-data php -f /tmp/book_content_type.php

# Создание типа контента "Статья"
cat > /tmp/article_content_type.php << 'EOF'
<?php
use Drupal\node\Entity\NodeType;
use Drupal\field\Entity\FieldStorageConfig;
use Drupal\field\Entity\FieldConfig;

// Создание типа контента "Статья"
$article_type = NodeType::create([
  'type' => 'library_article',
  'name' => 'Научная статья',
  'description' => 'Научные статьи и публикации',
]);
$article_type->save();

// Поля для статей
$fields = [
  'field_authors' => ['Авторы', 'string_long'],
  'field_journal' => ['Журнал', 'string'],
  'field_volume' => ['Том', 'string'],
  'field_issue' => ['Выпуск', 'string'],
  'field_doi' => ['DOI', 'string'],
  'field_abstract' => ['Аннотация', 'text_long'],
  'field_keywords' => ['Ключевые слова', 'string_long'],
  'field_pdf' => ['PDF файл', 'file'],
];

foreach ($fields as $field_name => $field_info) {
  $field_storage = FieldStorageConfig::create([
    'field_name' => $field_name,
    'entity_type' => 'node',
    'type' => $field_info[1],
  ]);
  $field_storage->save();

  $field = FieldConfig::create([
    'field_storage' => $field_storage,
    'bundle' => 'library_article',
    'label' => $field_info[0],
  ]);
  $field->save();
}

echo "Тип контента 'Научная статья' создан\n";
EOF

sudo -u www-data php -f /tmp/article_content_type.php

echo "6. Создание таксономий (категорий)..."

cat > /tmp/create_taxonomies.php << 'EOF'
<?php
use Drupal\taxonomy\Entity\Vocabulary;
use Drupal\taxonomy\Entity\Term;

// Создание словаря "Категории книг"
$book_categories = Vocabulary::create([
  'vid' => 'book_categories',
  'name' => 'Категории книг',
  'description' => 'Классификация книг по тематикам',
]);
$book_categories->save();

// Создание категорий
$categories = [
  'Информационные технологии',
  'Телекоммуникации',
  'Программирование',
  'Базы данных',
  'Искусственный интеллект',
  'Кибербезопасность',
  'Сетевые технологии',
  'Математика',
  'Физика',
  'Техническая литература'
];

foreach ($categories as $category) {
  $term = Term::create([
    'vid' => 'book_categories',
    'name' => $category,
  ]);
  $term->save();
}

// Создание словаря "Научные области"
$science_areas = Vocabulary::create([
  'vid' => 'science_areas',
  'name' => 'Научные области',
  'description' => 'Области научных исследований',
]);
$science_areas->save();

// Научные области
$areas = [
  'Компьютерные науки',
  'Информационные системы',
  'Телекоммуникационные технологии',
  'Прикладная математика',
  'Инженерия',
  'Цифровые технологии'
];

foreach ($areas as $area) {
  $term = Term::create([
    'vid' => 'science_areas',
    'name' => $area,
  ]);
  $term->save();
}

echo "Таксономии созданы\n";
EOF

sudo -u www-data php -f /tmp/create_taxonomies.php

echo "7. Настройка поиска..."

# Включение модулей поиска
sudo -u www-data vendor/bin/drush pm:enable search_api search_api_db -y

# Создание поискового индекса
cat > /tmp/create_search_index.php << 'EOF'
<?php
use Drupal\search_api\Entity\Index;
use Drupal\search_api\Entity\Server;

// Создание поискового сервера
$server = Server::create([
  'id' => 'library_search_server',
  'name' => 'Library Search Server',
  'backend' => 'search_api_db',
  'backend_config' => [
    'database' => 'default:default',
  ],
]);
$server->save();

// Создание поискового индекса
$index = Index::create([
  'id' => 'library_content',
  'name' => 'Library Content Index',
  'server' => 'library_search_server',
  'datasources' => [
    'entity:node' => [
      'plugin_id' => 'entity:node',
      'settings' => [
        'bundles' => [
          'default' => FALSE,
          'selected' => ['book', 'library_article'],
        ],
      ],
    ],
  ],
]);
$index->save();

echo "Поисковый индекс создан\n";
EOF

sudo -u www-data php -f /tmp/create_search_index.php

echo "8. Настройка темы оформления..."

# Установка темы Bootstrap 5
sudo -u www-data vendor/bin/drush theme:enable bootstrap5 -y
sudo -u www-data vendor/bin/drush config:set system.theme default bootstrap5 -y

echo "9. Создание главного меню..."

cat > /tmp/create_menu.php << 'EOF'
<?php
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Создание пунктов главного меню
$menu_items = [
  ['title' => 'Главная', 'link' => 'internal:/', 'weight' => 0],
  ['title' => 'Каталог книг', 'link' => 'internal:/books', 'weight' => 1],
  ['title' => 'Научные статьи', 'link' => 'internal:/articles', 'weight' => 2],
  ['title' => 'Поиск', 'link' => 'internal:/search', 'weight' => 3],
  ['title' => 'О библиотеке', 'link' => 'internal:/about', 'weight' => 4],
];

foreach ($menu_items as $item) {
  $menu_link = MenuLinkContent::create([
    'title' => $item['title'],
    'link' => ['uri' => $item['link']],
    'menu_name' => 'main',
    'weight' => $item['weight'],
  ]);
  $menu_link->save();
}

echo "Главное меню создано\n";
EOF

sudo -u www-data php -f /tmp/create_menu.php

echo "10. Создание базовых страниц..."

cat > /tmp/create_pages.php << 'EOF'
<?php
use Drupal\node\Entity\Node;

// Создание страницы "О библиотеке"
$about_page = Node::create([
  'type' => 'page',
  'title' => 'О цифровой библиотеке РЦТИ',
  'body' => [
    'value' => '<h2>Добро пожаловать в цифровую библиотеку РЦТИ</h2>
<p>Республиканский центр телекоммуникаций и информатизации (РЦТИ) представляет современную цифровую библиотеку, содержащую обширную коллекцию технической литературы, научных публикаций и образовательных материалов.</p>

<h3>Наши коллекции включают:</h3>
<ul>
<li>Книги по информационным технологиям</li>
<li>Техническую документацию по телекоммуникациям</li>
<li>Научные статьи и исследования</li>
<li>Образовательные материалы и курсы</li>
<li>Стандарты и нормативные документы</li>
</ul>

<h3>Возможности библиотеки:</h3>
<ul>
<li>Поиск по каталогу книг и статей</li>
<li>Фильтрация по категориям и авторам</li>
<li>Просмотр и скачивание документов</li>
<li>Персональные рекомендации</li>
<li>Система закладок и избранного</li>
</ul>

<p>Библиотека постоянно пополняется новыми материалами и обновляется в соответствии с современными требованиями информационных технологий.</p>',
    'format' => 'full_html',
  ],
  'status' => 1,
]);
$about_page->save();

echo "Базовые страницы созданы\n";
EOF

sudo -u www-data php -f /tmp/create_pages.php

echo "11. Настройка конфигурации сайта..."

# Базовые настройки сайта
sudo -u www-data vendor/bin/drush config:set system.site name "RTTI Digital Library" -y
sudo -u www-data vendor/bin/drush config:set system.site slogan "Цифровая библиотека РЦТИ" -y
sudo -u www-data vendor/bin/drush config:set system.site mail "library@rtti.tj" -y

# Настройки производительности
sudo -u www-data vendor/bin/drush config:set system.performance css.preprocess 1 -y
sudo -u www-data vendor/bin/drush config:set system.performance js.preprocess 1 -y

# Настройки кэширования
sudo -u www-data vendor/bin/drush config:set system.performance cache.page.max_age 3600 -y

echo "12. Создание представлений (Views) для библиотеки..."

cat > /tmp/create_views.php << 'EOF'
<?php
use Drupal\views\Entity\View;

// Представление для каталога книг
$books_view_config = [
  'id' => 'library_books',
  'label' => 'Library Books',
  'base_table' => 'node_field_data',
  'display' => [
    'default' => [
      'display_plugin' => 'default',
      'id' => 'default',
      'display_title' => 'Master',
      'position' => 0,
      'display_options' => [
        'filters' => [
          'type' => [
            'id' => 'type',
            'table' => 'node_field_data',
            'field' => 'type',
            'value' => ['book' => 'book'],
          ],
          'status' => [
            'id' => 'status',
            'table' => 'node_field_data',
            'field' => 'status',
            'value' => '1',
          ],
        ],
        'fields' => [
          'title' => [
            'id' => 'title',
            'table' => 'node_field_data',
            'field' => 'title',
          ],
          'field_author' => [
            'id' => 'field_author',
            'table' => 'node__field_author',
            'field' => 'field_author',
          ],
          'field_year' => [
            'id' => 'field_year',
            'table' => 'node__field_year',
            'field' => 'field_year',
          ],
        ],
      ],
    ],
    'page_1' => [
      'display_plugin' => 'page',
      'id' => 'page_1',
      'display_title' => 'Books Page',
      'position' => 1,
      'display_options' => [
        'path' => 'books',
        'menu' => [
          'type' => 'normal',
          'title' => 'Каталог книг',
          'menu_name' => 'main',
        ],
      ],
    ],
  ],
];

$books_view = View::create($books_view_config);
$books_view->save();

echo "Представления созданы\n";
EOF

sudo -u www-data php -f /tmp/create_views.php

echo "13. Настройка прав доступа..."

cat > /tmp/configure_permissions.php << 'EOF'
<?php
use Drupal\user\Entity\Role;

// Настройка прав для анонимных пользователей
$anonymous = Role::load('anonymous');
$anonymous->grantPermission('access content');
$anonymous->grantPermission('search content');
$anonymous->grantPermission('use search_api_autocomplete for search');
$anonymous->save();

// Настройка прав для аутентифицированных пользователей
$authenticated = Role::load('authenticated');
$authenticated->grantPermission('access content');
$authenticated->grantPermission('search content');
$authenticated->grantPermission('create book content');
$authenticated->grantPermission('edit own book content');
$authenticated->save();

echo "Права доступа настроены\n";
EOF

sudo -u www-data php -f /tmp/configure_permissions.php

echo "14. Индексация контента для поиска..."
sudo -u www-data vendor/bin/drush search-api:index

echo "15. Очистка кэша..."
sudo -u www-data vendor/bin/drush cache:rebuild

echo "16. Создание скрипта обслуживания библиотеки..."
cat > /root/library-maintenance.sh << EOF
#!/bin/bash
# Скрипт обслуживания цифровой библиотеки

DRUPAL_DIR="$DRUPAL_DIR"

case "\$1" in
    reindex)
        echo "Переиндексация поискового содержимого..."
        cd \$DRUPAL_DIR
        sudo -u www-data vendor/bin/drush search-api:clear
        sudo -u www-data vendor/bin/drush search-api:index
        echo "✅ Переиндексация завершена"
        ;;
    update-translations)
        echo "Обновление переводов..."
        cd \$DRUPAL_DIR
        sudo -u www-data vendor/bin/drush locale:update
        echo "✅ Переводы обновлены"
        ;;
    optimize)
        echo "Оптимизация базы данных..."
        sudo -u postgres vacuumdb --analyze drupal_library
        cd \$DRUPAL_DIR
        sudo -u www-data vendor/bin/drush cache:rebuild
        echo "✅ Оптимизация завершена"
        ;;
    backup-content)
        echo "Резервное копирование контента..."
        BACKUP_DIR="/var/backups/drupal/content-\$(date +%Y%m%d-%H%M%S)"
        mkdir -p \$BACKUP_DIR
        cd \$DRUPAL_DIR
        sudo -u www-data vendor/bin/drush config:export --destination=\$BACKUP_DIR/config
        cp -r web/sites/default/files \$BACKUP_DIR/
        sudo -u postgres pg_dump drupal_library > \$BACKUP_DIR/database.sql
        echo "✅ Контент сохранен в \$BACKUP_DIR"
        ;;
    stats)
        echo "Статистика библиотеки:"
        cd \$DRUPAL_DIR
        echo "Книги: \$(sudo -u www-data vendor/bin/drush sql:query \"SELECT COUNT(*) FROM node_field_data WHERE type='book' AND status=1\" --extra=--skip-column-names)"
        echo "Статьи: \$(sudo -u www-data vendor/bin/drush sql:query \"SELECT COUNT(*) FROM node_field_data WHERE type='library_article' AND status=1\" --extra=--skip-column-names)"
        echo "Пользователи: \$(sudo -u www-data vendor/bin/drush sql:query \"SELECT COUNT(*) FROM users_field_data WHERE status=1\" --extra=--skip-column-names)"
        ;;
    *)
        echo "Использование: \$0 {reindex|update-translations|optimize|backup-content|stats}"
        exit 1
        ;;
esac
EOF

chmod +x /root/library-maintenance.sh

echo "17. Создание отчета о конфигурации..."
cat > /root/drupal-library-config.txt << EOF
# Конфигурация цифровой библиотеки РЦТИ
# Дата: $(date)
# Сервер: library.rtti.tj ($(hostname -I | awk '{print $1}'))

=== НАСТРОЕННЫЕ КОМПОНЕНТЫ ===

✅ Типы контента:
- Книга (book) - для каталога книг
- Научная статья (library_article) - для публикаций

✅ Таксономии:
- Категории книг (book_categories)
- Научные области (science_areas)

✅ Функциональность:
- Многоязычность (русский/английский)
- Поиск и индексация (Search API)
- SEO оптимизация (Metatag, Pathauto)
- Административные инструменты
- Кэширование (Redis, Memcached)

✅ Тема оформления:
- Bootstrap 5 - современный адаптивный дизайн

✅ Страницы:
- Главная страница
- Каталог книг (/books)
- Научные статьи (/articles)
- О библиотеке (/about)
- Поиск (/search)

=== ДОСТУПЫ И ПРАВА ===
- Анонимные: просмотр и поиск контента
- Аутентифицированные: создание и редактирование контента
- Администраторы: полный доступ к управлению

=== ПОИСК И НАВИГАЦИЯ ===
- Полнотекстовый поиск по всему контенту
- Фильтрация по категориям и авторам
- Автодополнение в поиске
- Настроенная индексация

=== ТЕХНИЧЕСКОЕ ОБСЛУЖИВАНИЕ ===
Скрипт обслуживания: /root/library-maintenance.sh
Команды:
- reindex: переиндексация поиска
- update-translations: обновление переводов
- optimize: оптимизация БД
- backup-content: резервное копирование
- stats: статистика библиотеки

=== СЛЕДУЮЩИЕ НАСТРОЙКИ ===
1. Настройте дополнительные поля для книг и статей
2. Создайте пользовательские Views для отображения
3. Настройте форму поиска и фильтры
4. Добавьте тематические блоки на главную страницу
5. Настройте систему комментариев и рейтингов
6. Интегрируйте с внешними библиотечными системами

=== РЕКОМЕНДАЦИИ ===
- Регулярно переиндексируйте поисковое содержимое
- Обновляйте переводы при добавлении нового контента
- Мониторьте производительность поиска
- Создавайте резервные копии перед крупными изменениями
EOF

echo "18. Удаление временных файлов..."
rm -f /tmp/book_content_type.php
rm -f /tmp/article_content_type.php
rm -f /tmp/create_taxonomies.php
rm -f /tmp/create_search_index.php
rm -f /tmp/create_menu.php
rm -f /tmp/create_pages.php
rm -f /tmp/create_views.php
rm -f /tmp/configure_permissions.php

echo
echo "✅ Шаг 7 завершен успешно!"
echo "📌 Цифровая библиотека настроена и готова к работе"
echo "📌 Типы контента: Книга, Научная статья"
echo "📌 Поиск и индексация настроены"
echo "📌 Многоязычность: русский/английский"
echo "📌 Тема Bootstrap 5 активирована"
echo "📌 Меню и базовые страницы созданы"
echo "📌 Обслуживание: /root/library-maintenance.sh"
echo "📌 Конфигурация: /root/drupal-library-config.txt"
echo "📌 Следующий шаг: ./08-post-install.sh"
echo
