<?php
/**
 * Интеграция Moodle с Drupal для RTTI LMS
 * Модуль для синхронизации пользователей и контента
 */

// Настройки подключения к Drupal
define('DRUPAL_DB_HOST', 'localhost');
define('DRUPAL_DB_NAME', 'drupal_library');
define('DRUPAL_DB_USER', 'integration_user');
define('DRUPAL_DB_PASS', 'secure_integration_password_2023');
define('DRUPAL_BASE_URL', 'https://library.rtti.tj');

// Настройки API ключей
define('DRUPAL_API_KEY', 'rtti_lms_integration_key_2023');
define('MOODLE_API_KEY', 'moodle_api_key_2023');

class MoodleDrupalIntegration {
    
    private $drupal_db;
    private $moodle_db;
    
    public function __construct() {
        global $DB;
        $this->moodle_db = $DB;
        $this->connect_drupal_db();
    }
    
    /**
     * Подключение к базе данных Drupal
     */
    private function connect_drupal_db() {
        try {
            $this->drupal_db = new PDO(
                "pgsql:host=" . DRUPAL_DB_HOST . ";dbname=" . DRUPAL_DB_NAME,
                DRUPAL_DB_USER,
                DRUPAL_DB_PASS,
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
            );
        } catch (PDOException $e) {
            debugging('Ошибка подключения к Drupal DB: ' . $e->getMessage(), DEBUG_DEVELOPER);
        }
    }
    
    /**
     * Синхронизация пользователя с Drupal
     */
    public function sync_user_to_drupal($moodle_user) {
        if (!$this->drupal_db) {
            return false;
        }
        
        try {
            // Проверяем, существует ли пользователь в Drupal
            $stmt = $this->drupal_db->prepare("
                SELECT uid FROM users_field_data 
                WHERE mail = :email OR name = :username
            ");
            $stmt->execute([
                ':email' => $moodle_user->email,
                ':username' => $moodle_user->username
            ]);
            
            $drupal_user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($drupal_user) {
                // Обновляем существующего пользователя
                $this->update_drupal_user($drupal_user['uid'], $moodle_user);
            } else {
                // Создаем нового пользователя
                $this->create_drupal_user($moodle_user);
            }
            
            return true;
            
        } catch (PDOException $e) {
            debugging('Ошибка синхронизации пользователя: ' . $e->getMessage(), DEBUG_DEVELOPER);
            return false;
        }
    }
    
    /**
     * Создание пользователя в Drupal
     */
    private function create_drupal_user($moodle_user) {
        $stmt = $this->drupal_db->prepare("
            INSERT INTO users_field_data (
                uid, uuid, langcode, preferred_langcode, preferred_admin_langcode,
                name, mail, timezone, status, created, changed, access, login, init
            ) VALUES (
                nextval('users_uid_seq'), :uuid, 'en', 'en', 'en',
                :username, :email, :timezone, 1, :created, :changed, 0, 0, :email
            )
        ");
        
        $uuid = $this->generate_uuid();
        $timestamp = time();
        
        $stmt->execute([
            ':uuid' => $uuid,
            ':username' => $moodle_user->username,
            ':email' => $moodle_user->email,
            ':timezone' => $moodle_user->timezone ?? 'Asia/Dushanbe',
            ':created' => $timestamp,
            ':changed' => $timestamp
        ]);
        
        // Добавляем пароль
        $uid = $this->drupal_db->lastInsertId();
        $this->set_drupal_user_password($uid, $moodle_user->password ?? '');
    }
    
    /**
     * Обновление пользователя в Drupal
     */
    private function update_drupal_user($uid, $moodle_user) {
        $stmt = $this->drupal_db->prepare("
            UPDATE users_field_data SET
                name = :username,
                mail = :email,
                changed = :changed
            WHERE uid = :uid
        ");
        
        $stmt->execute([
            ':username' => $moodle_user->username,
            ':email' => $moodle_user->email,
            ':changed' => time(),
            ':uid' => $uid
        ]);
    }
    
    /**
     * Установка пароля пользователя в Drupal
     */
    private function set_drupal_user_password($uid, $password) {
        if (empty($password)) {
            $password = $this->generate_random_password();
        }
        
        // Используем алгоритм хеширования Drupal
        $hash = password_hash($password, PASSWORD_DEFAULT);
        
        $stmt = $this->drupal_db->prepare("
            UPDATE users_field_data SET pass = :password WHERE uid = :uid
        ");
        
        $stmt->execute([
            ':password' => $hash,
            ':uid' => $uid
        ]);
    }
    
    /**
     * Получение списка книг из Drupal для курса
     */
    public function get_books_for_course($course_id, $subject = null) {
        if (!$this->drupal_db) {
            return [];
        }
        
        try {
            $sql = "
                SELECT n.nid, n.title, f.uri as file_uri, 
                       t.name as category, s.name as subject
                FROM node_field_data n
                LEFT JOIN node__field_book_file bf ON n.nid = bf.entity_id
                LEFT JOIN file_managed f ON bf.field_book_file_target_id = f.fid
                LEFT JOIN node__field_book_category bc ON n.nid = bc.entity_id
                LEFT JOIN taxonomy_term_field_data t ON bc.field_book_category_target_id = t.tid
                LEFT JOIN node__field_book_subject bs ON n.nid = bs.entity_id
                LEFT JOIN taxonomy_term_field_data s ON bs.field_book_subject_target_id = s.tid
                WHERE n.type = 'digital_book' AND n.status = 1
            ";
            
            if ($subject) {
                $sql .= " AND s.name ILIKE :subject";
                $params = [':subject' => "%$subject%"];
            } else {
                $params = [];
            }
            
            $stmt = $this->drupal_db->prepare($sql);
            $stmt->execute($params);
            
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
            
        } catch (PDOException $e) {
            debugging('Ошибка получения книг: ' . $e->getMessage(), DEBUG_DEVELOPER);
            return [];
        }
    }
    
    /**
     * Добавление ссылки на книгу в курс Moodle
     */
    public function add_book_to_course($course_id, $book_data) {
        global $CFG;
        require_once($CFG->dirroot . '/course/lib.php');
        require_once($CFG->dirroot . '/mod/url/lib.php');
        
        try {
            $course = $this->moodle_db->get_record('course', ['id' => $course_id]);
            if (!$course) {
                return false;
            }
            
            // Создаем модуль URL для ссылки на книгу
            $moduleinfo = new stdClass();
            $moduleinfo->course = $course_id;
            $moduleinfo->module = $this->moodle_db->get_field('modules', 'id', ['name' => 'url']);
            $moduleinfo->modulename = 'url';
            $moduleinfo->name = $book_data['title'];
            $moduleinfo->intro = 'Электронная книга из библиотеки RTTI';
            $moduleinfo->introformat = FORMAT_HTML;
            $moduleinfo->externalurl = DRUPAL_BASE_URL . '/node/' . $book_data['nid'];
            $moduleinfo->display = RESOURCELIB_DISPLAY_AUTO;
            $moduleinfo->visible = 1;
            $moduleinfo->section = 1; // Добавляем в первую секцию
            
            $cm = add_coursemodule($moduleinfo);
            
            return $cm->id;
            
        } catch (Exception $e) {
            debugging('Ошибка добавления книги в курс: ' . $e->getMessage(), DEBUG_DEVELOPER);
            return false;
        }
    }
    
    /**
     * Синхронизация прогресса пользователя
     */
    public function sync_user_progress($user_id, $course_id, $progress_data) {
        // Отправляем данные о прогрессе в Drupal через API
        $api_url = DRUPAL_BASE_URL . '/api/user-progress';
        
        $data = [
            'user_id' => $user_id,
            'course_id' => $course_id,
            'progress' => $progress_data,
            'timestamp' => time(),
            'api_key' => DRUPAL_API_KEY
        ];
        
        $options = [
            'http' => [
                'header' => "Content-type: application/json\r\n",
                'method' => 'POST',
                'content' => json_encode($data)
            ]
        ];
        
        $context = stream_context_create($options);
        $result = file_get_contents($api_url, false, $context);
        
        return $result !== false;
    }
    
    /**
     * Создание Single Sign-On токена
     */
    public function create_sso_token($user_id) {
        $user = $this->moodle_db->get_record('user', ['id' => $user_id]);
        if (!$user) {
            return false;
        }
        
        $token_data = [
            'user_id' => $user_id,
            'username' => $user->username,
            'email' => $user->email,
            'timestamp' => time(),
            'expires' => time() + 3600 // 1 час
        ];
        
        $token = base64_encode(json_encode($token_data));
        $signature = hash_hmac('sha256', $token, MOODLE_API_KEY);
        
        return $token . '.' . $signature;
    }
    
    /**
     * Проверка SSO токена
     */
    public function verify_sso_token($token) {
        $parts = explode('.', $token);
        if (count($parts) !== 2) {
            return false;
        }
        
        list($data, $signature) = $parts;
        
        // Проверяем подпись
        $expected_signature = hash_hmac('sha256', $data, MOODLE_API_KEY);
        if (!hash_equals($expected_signature, $signature)) {
            return false;
        }
        
        // Декодируем данные
        $token_data = json_decode(base64_decode($data), true);
        if (!$token_data) {
            return false;
        }
        
        // Проверяем срок действия
        if ($token_data['expires'] < time()) {
            return false;
        }
        
        return $token_data;
    }
    
    /**
     * Получение статистики использования библиотеки
     */
    public function get_library_stats() {
        if (!$this->drupal_db) {
            return [];
        }
        
        try {
            $stats = [];
            
            // Общее количество книг
            $stmt = $this->drupal_db->query("
                SELECT COUNT(*) as total_books 
                FROM node_field_data 
                WHERE type = 'digital_book' AND status = 1
            ");
            $stats['total_books'] = $stmt->fetchColumn();
            
            // Количество книг по категориям
            $stmt = $this->drupal_db->query("
                SELECT t.name as category, COUNT(n.nid) as count
                FROM node_field_data n
                LEFT JOIN node__field_book_category bc ON n.nid = bc.entity_id
                LEFT JOIN taxonomy_term_field_data t ON bc.field_book_category_target_id = t.tid
                WHERE n.type = 'digital_book' AND n.status = 1
                GROUP BY t.name
                ORDER BY count DESC
            ");
            $stats['books_by_category'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Популярные книги (по просмотрам)
            $stmt = $this->drupal_db->query("
                SELECT n.title, nc.totalcount as views
                FROM node_field_data n
                LEFT JOIN node_counter nc ON n.nid = nc.nid
                WHERE n.type = 'digital_book' AND n.status = 1
                ORDER BY nc.totalcount DESC
                LIMIT 10
            ");
            $stats['popular_books'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            return $stats;
            
        } catch (PDOException $e) {
            debugging('Ошибка получения статистики: ' . $e->getMessage(), DEBUG_DEVELOPER);
            return [];
        }
    }
    
    /**
     * Вспомогательные функции
     */
    private function generate_uuid() {
        return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }
    
    private function generate_random_password($length = 12) {
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
        return substr(str_shuffle($chars), 0, $length);
    }
}

/**
 * Хуки для событий Moodle
 */

// Хук для создания пользователя
function local_drupal_integration_user_created($user) {
    $integration = new MoodleDrupalIntegration();
    $integration->sync_user_to_drupal($user);
}

// Хук для обновления пользователя
function local_drupal_integration_user_updated($user) {
    $integration = new MoodleDrupalIntegration();
    $integration->sync_user_to_drupal($user);
}

// Хук для завершения курса
function local_drupal_integration_course_completed($data) {
    $integration = new MoodleDrupalIntegration();
    $integration->sync_user_progress(
        $data['userid'], 
        $data['courseid'], 
        ['status' => 'completed', 'completion_date' => time()]
    );
}

/**
 * API функции для внешнего доступа
 */

// Получение списка книг
function local_drupal_integration_get_books($course_id, $subject = null) {
    $integration = new MoodleDrupalIntegration();
    return $integration->get_books_for_course($course_id, $subject);
}

// Добавление книги в курс
function local_drupal_integration_add_book($course_id, $book_id) {
    $integration = new MoodleDrupalIntegration();
    
    // Получаем данные о книге из Drupal
    $books = $integration->get_books_for_course($course_id);
    $book_data = null;
    
    foreach ($books as $book) {
        if ($book['nid'] == $book_id) {
            $book_data = $book;
            break;
        }
    }
    
    if ($book_data) {
        return $integration->add_book_to_course($course_id, $book_data);
    }
    
    return false;
}

// Создание SSO ссылки для перехода в библиотеку
function local_drupal_integration_create_library_link($user_id) {
    $integration = new MoodleDrupalIntegration();
    $token = $integration->create_sso_token($user_id);
    
    if ($token) {
        return DRUPAL_BASE_URL . '/sso/login?token=' . urlencode($token);
    }
    
    return DRUPAL_BASE_URL;
}

// Получение статистики библиотеки
function local_drupal_integration_get_stats() {
    $integration = new MoodleDrupalIntegration();
    return $integration->get_library_stats();
}
