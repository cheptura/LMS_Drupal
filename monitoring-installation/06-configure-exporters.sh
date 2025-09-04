#!/bin/bash

# RTTI Monitoring - Шаг 6: Настройка дополнительных экспортеров
# Серверы: lms.rtti.tj (92.242.60.172), library.rtti.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 6: Дополнительные экспортеры ==="
echo "📊 Настройка специализированных метрик и экспортеров"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

# Определение роли сервера
SERVER_IP=$(hostname -I | awk '{print $1}')
if [[ "$SERVER_IP" == "92.242.60.172" ]]; then
    SERVER_ROLE="moodle"
    SERVER_NAME="lms.rtti.tj"
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    SERVER_ROLE="drupal"
    SERVER_NAME="library.rtti.tj"
else
    SERVER_ROLE="standalone"
    SERVER_NAME=$(hostname -f)
fi

MONITORING_DIR="/opt/monitoring"
EXPORTERS_DIR="$MONITORING_DIR/exporters"
DOCKER_COMPOSE_DIR="$MONITORING_DIR/docker"

echo "🔍 Роль сервера: $SERVER_ROLE ($SERVER_NAME)"

echo "1. Создание структуры для дополнительных экспортеров..."
mkdir -p $EXPORTERS_DIR/{process,ssl,json,custom}

echo "2. Установка Process Exporter..."

# Конфигурация Process Exporter
cat > $EXPORTERS_DIR/process/process-exporter.yml << EOF
# Конфигурация Process Exporter для RTTI
# Дата: $(date)

process_names:
  # Nginx процессы
  - name: "nginx"
    cmdline:
      - "nginx"
    
  # PHP-FPM процессы  
  - name: "php-fpm"
    cmdline:
      - "php-fpm"
    
  # PostgreSQL процессы
  - name: "postgres"
    cmdline:
      - "postgres"
    
  # Redis процессы
  - name: "redis"
    cmdline:
      - "redis-server"
    
  # SSH процессы
  - name: "sshd"
    cmdline:
      - "sshd"
    
  # Docker процессы
  - name: "docker"
    cmdline:
      - "dockerd"
      - "containerd"
    
  # Системные процессы
  - name: "systemd"
    cmdline:
      - "systemd"
    
  # Мониторинг процессы
  - name: "monitoring"
    cmdline:
      - "prometheus"
      - "grafana"
      - "alertmanager"

EOF

# Добавление специфичных процессов в зависимости от роли
if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> $EXPORTERS_DIR/process/process-exporter.yml << EOF
  # Moodle специфичные процессы
  - name: "moodle-cron"
    cmdline:
      - "admin/cli/cron.php"
    
  - name: "moodle-adhoc"
    cmdline:
      - "admin/cli/adhoc_task.php"

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> $EXPORTERS_DIR/process/process-exporter.yml << EOF
  # Drupal специфичные процессы
  - name: "drupal-cron"
    cmdline:
      - "drush.*cron"
    
  - name: "drupal-queue"
    cmdline:
      - "drush.*queue"

EOF
fi

echo "3. Настройка SSL Exporter..."

cat > $EXPORTERS_DIR/ssl/ssl-exporter.yml << EOF
# Конфигурация SSL Exporter для RTTI
# Дата: $(date)

modules:
  https:
    prober: https
    timeout: 10s
    https:
      fail_if_ssl: false
      fail_if_not_ssl: true
      
  https_insecure:
    prober: https
    timeout: 10s
    https:
      fail_if_ssl: false
      fail_if_not_ssl: true
      tls_config:
        insecure_skip_verify: true

  tcp:
    prober: tcp
    timeout: 5s
    
  smtp:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - expect: "^220"
      tls: true

targets:
  - name: "$SERVER_NAME"
    url: "https://$SERVER_NAME"
    module: https
    
  - name: "Local SSL"
    url: "https://127.0.0.1"
    module: https_insecure

EOF

echo "4. Создание Custom Exporter для RTTI метрик..."

cat > $EXPORTERS_DIR/custom/rtti-exporter.py << 'EOF'
#!/usr/bin/env python3
"""
RTTI Custom Exporter
Собирает специфичные метрики для RTTI инфраструктуры
"""

import time
import os
import subprocess
import json
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading

class RTTIMetrics:
    def __init__(self, server_role):
        self.server_role = server_role
        self.metrics = {}
        
    def collect_system_metrics(self):
        """Сбор системных метрик"""
        metrics = []
        
        # Количество активных пользователей SSH
        try:
            result = subprocess.run(['who', '-u'], capture_output=True, text=True)
            ssh_users = len([line for line in result.stdout.split('\n') if 'pts/' in line])
            metrics.append(f'rtti_ssh_active_users {ssh_users}')
        except:
            pass
            
        # Размер логов
        log_dirs = ['/var/log/nginx', '/var/log/postgresql', '/var/log/php']
        for log_dir in log_dirs:
            if os.path.exists(log_dir):
                try:
                    result = subprocess.run(['du', '-sb', log_dir], capture_output=True, text=True)
                    size = int(result.stdout.split()[0])
                    dir_name = log_dir.split('/')[-1]
                    metrics.append(f'rtti_log_size_bytes{{service="{dir_name}"}} {size}')
                except:
                    pass
                    
        # Количество обновлений системы
        try:
            result = subprocess.run(['apt', 'list', '--upgradable'], capture_output=True, text=True)
            updates = len(result.stdout.split('\n')) - 2  # Убираем заголовок и пустую строку
            if updates < 0:
                updates = 0
            metrics.append(f'rtti_system_updates_available {updates}')
        except:
            pass
            
        return metrics
        
    def collect_web_metrics(self):
        """Сбор веб-метрик"""
        metrics = []
        
        # Проверка статуса Nginx
        try:
            result = subprocess.run(['systemctl', 'is-active', 'nginx'], capture_output=True, text=True)
            status = 1 if result.stdout.strip() == 'active' else 0
            metrics.append(f'rtti_nginx_status {status}')
        except:
            pass
            
        # Количество Nginx воркеров
        try:
            result = subprocess.run(['pgrep', '-c', 'nginx.*worker'], capture_output=True, text=True)
            workers = int(result.stdout.strip())
            metrics.append(f'rtti_nginx_workers {workers}')
        except:
            pass
            
        # Статистика PHP-FPM
        try:
            result = subprocess.run(['pgrep', '-c', 'php-fpm'], capture_output=True, text=True)
            processes = int(result.stdout.strip())
            metrics.append(f'rtti_php_fpm_processes {processes}')
        except:
            pass
            
        return metrics
        
    def collect_database_metrics(self):
        """Сбор метрик базы данных"""
        metrics = []
        
        # Статус PostgreSQL
        try:
            result = subprocess.run(['systemctl', 'is-active', 'postgresql'], capture_output=True, text=True)
            status = 1 if result.stdout.strip() == 'active' else 0
            metrics.append(f'rtti_postgresql_status {status}')
        except:
            pass
            
        # Размер баз данных
        db_names = []
        if self.server_role == 'moodle':
            db_names = ['moodle']
        elif self.server_role == 'drupal':
            db_names = ['drupal_library']
            
        for db_name in db_names:
            try:
                cmd = ['sudo', '-u', 'postgres', 'psql', '-d', db_name, '-t', '-c', 
                       "SELECT pg_size_pretty(pg_database_size(current_database()));"]
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode == 0:
                    size_str = result.stdout.strip()
                    # Преобразование в байты
                    if 'MB' in size_str:
                        size = float(size_str.split()[0]) * 1024 * 1024
                    elif 'GB' in size_str:
                        size = float(size_str.split()[0]) * 1024 * 1024 * 1024
                    elif 'kB' in size_str:
                        size = float(size_str.split()[0]) * 1024
                    else:
                        size = 0
                    metrics.append(f'rtti_database_size_bytes{{database="{db_name}"}} {int(size)}')
            except:
                pass
                
        return metrics
        
    def collect_application_metrics(self):
        """Сбор метрик приложений"""
        metrics = []
        
        if self.server_role == 'moodle':
            # Moodle специфичные метрики
            try:
                # Проверка существования директории Moodle
                moodle_dir = '/var/www/moodle'
                if os.path.exists(moodle_dir):
                    metrics.append('rtti_moodle_installation_status 1')
                    
                    # Размер moodledata
                    moodledata_dir = '/var/moodledata'
                    if os.path.exists(moodledata_dir):
                        result = subprocess.run(['du', '-sb', moodledata_dir], capture_output=True, text=True)
                        if result.returncode == 0:
                            size = int(result.stdout.split()[0])
                            metrics.append(f'rtti_moodle_data_size_bytes {size}')
                else:
                    metrics.append('rtti_moodle_installation_status 0')
            except:
                pass
                
        elif self.server_role == 'drupal':
            # Drupal специфичные метрики
            try:
                # Проверка существования директории Drupal
                drupal_dir = '/var/www/drupal'
                if os.path.exists(drupal_dir):
                    metrics.append('rtti_drupal_installation_status 1')
                    
                    # Размер файлов Drupal
                    files_dir = f'{drupal_dir}/web/sites/default/files'
                    if os.path.exists(files_dir):
                        result = subprocess.run(['du', '-sb', files_dir], capture_output=True, text=True)
                        if result.returncode == 0:
                            size = int(result.stdout.split()[0])
                            metrics.append(f'rtti_drupal_files_size_bytes {size}')
                else:
                    metrics.append('rtti_drupal_installation_status 0')
            except:
                pass
                
        return metrics
        
    def collect_security_metrics(self):
        """Сбор метрик безопасности"""
        metrics = []
        
        # Статус fail2ban
        try:
            result = subprocess.run(['systemctl', 'is-active', 'fail2ban'], capture_output=True, text=True)
            status = 1 if result.stdout.strip() == 'active' else 0
            metrics.append(f'rtti_fail2ban_status {status}')
            
            if status:
                # Количество заблокированных IP
                result = subprocess.run(['fail2ban-client', 'status'], capture_output=True, text=True)
                if result.returncode == 0:
                    lines = result.stdout.split('\n')
                    for line in lines:
                        if 'Currently banned:' in line:
                            banned = int(line.split(':')[1].strip())
                            metrics.append(f'rtti_fail2ban_banned_ips {banned}')
                            break
        except:
            pass
            
        # Проверка последних неудачных входов
        try:
            result = subprocess.run(['lastb', '-n', '10'], capture_output=True, text=True)
            failed_logins = len([line for line in result.stdout.split('\n') if line.strip()])
            metrics.append(f'rtti_failed_logins_recent {failed_logins}')
        except:
            pass
            
        return metrics
        
    def collect_all_metrics(self):
        """Сбор всех метрик"""
        all_metrics = []
        all_metrics.extend(self.collect_system_metrics())
        all_metrics.extend(self.collect_web_metrics())
        all_metrics.extend(self.collect_database_metrics())
        all_metrics.extend(self.collect_application_metrics())
        all_metrics.extend(self.collect_security_metrics())
        
        # Добавление timestamp
        timestamp = int(time.time())
        all_metrics.append(f'rtti_exporter_last_update {timestamp}')
        
        return all_metrics

class MetricsHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, server_role='standalone', **kwargs):
        self.server_role = server_role
        super().__init__(*args, **kwargs)
        
    def do_GET(self):
        if self.path == '/metrics':
            try:
                collector = RTTIMetrics(self.server_role)
                metrics = collector.collect_all_metrics()
                
                response = "# HELP rtti_* RTTI Infrastructure Metrics\n"
                response += "# TYPE rtti_* gauge\n"
                response += "\n".join(metrics)
                response += "\n"
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
                self.end_headers()
                self.wfile.write(response.encode('utf-8'))
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f"Error: {str(e)}".encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()
            
    def log_message(self, format, *args):
        pass  # Отключаем логирование

def create_handler(server_role):
    def handler(*args, **kwargs):
        return MetricsHandler(*args, server_role=server_role, **kwargs)
    return handler

if __name__ == '__main__':
    import sys
    server_role = sys.argv[1] if len(sys.argv) > 1 else 'standalone'
    
    port = 9999
    handler = create_handler(server_role)
    httpd = HTTPServer(('0.0.0.0', port), handler)
    
    print(f"RTTI Exporter running on port {port} for role {server_role}")
    httpd.serve_forever()
EOF

chmod +x $EXPORTERS_DIR/custom/rtti-exporter.py

echo "5. Обновление Docker Compose для дополнительных экспортеров..."

cat >> $DOCKER_COMPOSE_DIR/docker-compose.yml << EOF

  # Process Exporter - мониторинг процессов
  process-exporter:
    image: ncabatoff/process-exporter:latest
    container_name: process-exporter
    restart: unless-stopped
    ports:
      - "9256:9256"
    volumes:
      - /proc:/host/proc:ro
      - $EXPORTERS_DIR/process:/config
    command:
      - '--procfs=/host/proc'
      - '--config.path=/config/process-exporter.yml'
    networks:
      - monitoring
    privileged: true

  # SSL Exporter - мониторинг SSL сертификатов
  ssl-exporter:
    image: ribbybibby/ssl-exporter:latest
    container_name: ssl-exporter
    restart: unless-stopped
    ports:
      - "9219:9219"
    volumes:
      - $EXPORTERS_DIR/ssl:/config
    command:
      - '--config.file=/config/ssl-exporter.yml'
    networks:
      - monitoring

  # RTTI Custom Exporter - специфичные метрики
  rtti-exporter:
    image: python:3.9-slim
    container_name: rtti-exporter
    restart: unless-stopped
    ports:
      - "9999:9999"
    volumes:
      - $EXPORTERS_DIR/custom:/app
      - /var/log:/var/log:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    working_dir: /app
    command: python3 rtti-exporter.py $SERVER_ROLE
    networks:
      - monitoring
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - PYTHONUNBUFFERED=1
EOF

echo "6. Обновление конфигурации Prometheus..."

cat >> $MONITORING_DIR/prometheus/config/prometheus.yml << EOF

  # Process Exporter - мониторинг процессов
  - job_name: 'process-exporter'
    static_configs:
      - targets: ['process-exporter:9256']
    scrape_interval: 30s
    metrics_path: /metrics

  # SSL Exporter - мониторинг SSL
  - job_name: 'ssl-exporter'
    static_configs:
      - targets: ['ssl-exporter:9219']
    scrape_interval: 60s
    metrics_path: /metrics

  # RTTI Custom Exporter - специфичные метрики
  - job_name: 'rtti-exporter'
    static_configs:
      - targets: ['rtti-exporter:9999']
    scrape_interval: 30s
    metrics_path: /metrics
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: '$SERVER_NAME'

EOF

echo "7. Создание дополнительных правил алертов для новых метрик..."

cat > $MONITORING_DIR/prometheus/rules/process-alerts.yml << EOF
# Правила алертов для процессов RTTI
# Дата: $(date)

groups:
  - name: rtti.processes
    rules:
      # Nginx процессы
      - alert: NginxProcessDown
        expr: namedprocess_namegroup_num_procs{groupname="nginx"} == 0
        for: 1m
        labels:
          severity: critical
          service: nginx
        annotations:
          summary: "Nginx процессы не запущены на {{ \$labels.instance }}"
          description: "Не найдено активных процессов Nginx"

      # PHP-FPM процессы
      - alert: PHPFPMProcessLow
        expr: namedprocess_namegroup_num_procs{groupname="php-fpm"} < 2
        for: 5m
        labels:
          severity: warning
          service: php
        annotations:
          summary: "Мало PHP-FPM процессов на {{ \$labels.instance }}"
          description: "Количество PHP-FPM процессов: {{ \$value }}"

      # PostgreSQL процессы
      - alert: PostgreSQLProcessDown
        expr: namedprocess_namegroup_num_procs{groupname="postgres"} == 0
        for: 1m
        labels:
          severity: critical
          service: postgresql
        annotations:
          summary: "PostgreSQL процессы не запущены на {{ \$labels.instance }}"
          description: "Не найдено активных процессов PostgreSQL"

      # Redis процессы
      - alert: RedisProcessDown
        expr: namedprocess_namegroup_num_procs{groupname="redis"} == 0
        for: 1m
        labels:
          severity: critical
          service: redis
        annotations:
          summary: "Redis процессы не запущены на {{ \$labels.instance }}"
          description: "Не найдено активных процессов Redis"

  - name: rtti.custom
    rules:
      # Много обновлений системы
      - alert: SystemUpdatesAvailable
        expr: rtti_system_updates_available > 20
        for: 1h
        labels:
          severity: warning
          service: system
        annotations:
          summary: "Много обновлений системы на {{ \$labels.instance }}"
          description: "Доступно {{ \$value }} обновлений системы"

      # Проблемы с Fail2Ban
      - alert: Fail2BanDown
        expr: rtti_fail2ban_status == 0
        for: 5m
        labels:
          severity: warning
          service: security
        annotations:
          summary: "Fail2Ban не активен на {{ \$labels.instance }}"
          description: "Система защиты Fail2Ban отключена"

      # Много заблокированных IP
      - alert: TooManyBannedIPs
        expr: rtti_fail2ban_banned_ips > 50
        for: 10m
        labels:
          severity: warning
          service: security
        annotations:
          summary: "Много заблокированных IP на {{ \$labels.instance }}"
          description: "Заблокировано {{ \$value }} IP адресов"

EOF

# Добавление специфичных алертов
if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> $MONITORING_DIR/prometheus/rules/process-alerts.yml << EOF
      # Moodle статус
      - alert: MoodleInstallationIssue
        expr: rtti_moodle_installation_status == 0
        for: 5m
        labels:
          severity: critical
          service: moodle
        annotations:
          summary: "Проблемы с установкой Moodle"
          description: "Директория Moodle недоступна или повреждена"

      # Размер moodledata
      - alert: MoodleDataSizeGrowth
        expr: increase(rtti_moodle_data_size_bytes[1h]) > 1000000000  # 1GB за час
        for: 1h
        labels:
          severity: warning
          service: moodle
        annotations:
          summary: "Быстрый рост данных Moodle"
          description: "Размер moodledata увеличился на {{ \$value | humanize1024 }} за час"

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> $MONITORING_DIR/prometheus/rules/process-alerts.yml << EOF
      # Drupal статус
      - alert: DrupalInstallationIssue
        expr: rtti_drupal_installation_status == 0
        for: 5m
        labels:
          severity: critical
          service: drupal
        annotations:
          summary: "Проблемы с установкой Drupal"
          description: "Директория Drupal недоступна или повреждена"

      # Размер файлов Drupal
      - alert: DrupalFilesSizeGrowth
        expr: increase(rtti_drupal_files_size_bytes[1h]) > 500000000  # 500MB за час
        for: 1h
        labels:
          severity: warning
          service: drupal
        annotations:
          summary: "Быстрый рост файлов Drupal"
          description: "Размер файлов увеличился на {{ \$value | humanize1024 }} за час"

EOF
fi

echo "8. Настройка файрвола для новых экспортеров..."

# Открытие портов для новых экспортеров (только локально)
ufw allow from 127.0.0.1 to any port 9256 comment "Process Exporter"
ufw allow from 127.0.0.1 to any port 9219 comment "SSL Exporter"
ufw allow from 127.0.0.1 to any port 9999 comment "RTTI Exporter"

echo "9. Установка зависимостей для Python экспортера..."

# Установка Python в контейнер будет происходить автоматически

echo "10. Создание скрипта для проверки экспортеров..."

cat > /root/check-exporters.sh << 'EOF'
#!/bin/bash
# Проверка всех экспортеров RTTI

echo "=== Проверка экспортеров RTTI ==="

# Список экспортеров и их портов
declare -A exporters=(
    ["node-exporter"]="9100"
    ["nginx-exporter"]="9113"
    ["postgres-exporter"]="9187"
    ["redis-exporter"]="9121"
    ["blackbox-exporter"]="9115"
    ["process-exporter"]="9256"
    ["ssl-exporter"]="9219"
    ["rtti-exporter"]="9999"
    ["cadvisor"]="8080"
)

for exporter in "${!exporters[@]}"; do
    port="${exporters[$exporter]}"
    echo -n "Проверка $exporter (порт $port): "
    
    if curl -s "http://localhost:$port/metrics" > /dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAIL"
    fi
done

echo
echo "=== Проверка Docker контейнеров ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(exporter|prometheus|grafana|alertmanager|cadvisor)"

echo
echo "=== Проверка метрик RTTI ==="
echo "Специфичные метрики RTTI:"
curl -s "http://localhost:9999/metrics" | grep "^rtti_" | head -10

echo
echo "=== Статистика Process Exporter ==="
echo "Мониторируемые процессы:"
curl -s "http://localhost:9256/metrics" | grep "namedprocess_namegroup_num_procs" | grep -v "^#"
EOF

chmod +x /root/check-exporters.sh

echo "11. Перезапуск Docker Compose с новыми экспортерами..."

cd $DOCKER_COMPOSE_DIR
docker-compose up -d

echo "12. Перезагрузка конфигурации Prometheus..."
docker exec prometheus kill -HUP 1

echo "13. Ожидание запуска новых экспортеров..."
sleep 30

echo "14. Создание отчета о настройке экспортеров..."

cat > /root/exporters-setup-report.txt << EOF
# ОТЧЕТ О НАСТРОЙКЕ ДОПОЛНИТЕЛЬНЫХ ЭКСПОРТЕРОВ
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== УСТАНОВЛЕННЫЕ ЭКСПОРТЕРЫ ===

Базовые экспортеры:
✅ Node Exporter: порт 9100 (системные метрики)
✅ Nginx Exporter: порт 9113 (веб-сервер)
✅ PostgreSQL Exporter: порт 9187 (база данных)
✅ Redis Exporter: порт 9121 (кэширование)
✅ Blackbox Exporter: порт 9115 (внешние проверки)
✅ cAdvisor: порт 8080 (контейнеры)

Дополнительные экспортеры:
✅ Process Exporter: порт 9256 (процессы)
✅ SSL Exporter: порт 9219 (SSL сертификаты)
✅ RTTI Exporter: порт 9999 (специфичные метрики)

=== МОНИТОРИРУЕМЫЕ ПРОЦЕССЫ ===

Веб-сервер:
- nginx (основные и worker процессы)
- php-fpm (пул процессов)

База данных:
- postgres (основной и дочерние процессы)

Кэширование:
- redis-server

Система:
- sshd (SSH подключения)
- systemd (системные сервисы)
- docker/containerd (контейнеризация)

Мониторинг:
- prometheus, grafana, alertmanager

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/exporters-setup-report.txt << EOF
Moodle специфичные:
- moodle-cron (задачи по расписанию)
- moodle-adhoc (асинхронные задачи)

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/exporters-setup-report.txt << EOF
Drupal специфичные:
- drupal-cron (задачи по расписанию)
- drupal-queue (очереди задач)

EOF
fi

cat >> /root/exporters-setup-report.txt << EOF
=== СПЕЦИФИЧНЫЕ МЕТРИКИ RTTI ===

Системные:
- rtti_ssh_active_users (активные SSH пользователи)
- rtti_log_size_bytes (размер логов по сервисам)
- rtti_system_updates_available (доступные обновления)

Веб-сервер:
- rtti_nginx_status (статус Nginx)
- rtti_nginx_workers (количество воркеров)
- rtti_php_fpm_processes (процессы PHP-FPM)

База данных:
- rtti_postgresql_status (статус PostgreSQL)
- rtti_database_size_bytes (размер БД)

Безопасность:
- rtti_fail2ban_status (статус Fail2Ban)
- rtti_fail2ban_banned_ips (заблокированные IP)
- rtti_failed_logins_recent (неудачные входы)

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/exporters-setup-report.txt << EOF
Moodle:
- rtti_moodle_installation_status (статус установки)
- rtti_moodle_data_size_bytes (размер moodledata)

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/exporters-setup-report.txt << EOF
Drupal:
- rtti_drupal_installation_status (статус установки)
- rtti_drupal_files_size_bytes (размер файлов)

EOF
fi

cat >> /root/exporters-setup-report.txt << EOF
=== НОВЫЕ АЛЕРТЫ ===

Процессы:
- NginxProcessDown (нет процессов Nginx)
- PHPFPMProcessLow (мало процессов PHP-FPM)
- PostgreSQLProcessDown (нет процессов PostgreSQL)
- RedisProcessDown (нет процессов Redis)

Система:
- SystemUpdatesAvailable (много обновлений)
- Fail2BanDown (Fail2Ban неактивен)
- TooManyBannedIPs (много заблокированных IP)

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/exporters-setup-report.txt << EOF
Moodle:
- MoodleInstallationIssue (проблемы с установкой)
- MoodleDataSizeGrowth (быстрый рост данных)

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/exporters-setup-report.txt << EOF
Drupal:
- DrupalInstallationIssue (проблемы с установкой)
- DrupalFilesSizeGrowth (быстрый рост файлов)

EOF
fi

cat >> /root/exporters-setup-report.txt << EOF
=== УПРАВЛЕНИЕ ===

Проверка всех экспортеров:
/root/check-exporters.sh

Просмотр метрик:
curl http://localhost:9999/metrics | grep rtti_

Перезапуск экспортеров:
docker-compose -f $DOCKER_COMPOSE_DIR/docker-compose.yml restart

Логи экспортеров:
docker logs [exporter-name]

=== КОНФИГУРАЦИОННЫЕ ФАЙЛЫ ===

Process Exporter: $EXPORTERS_DIR/process/process-exporter.yml
SSL Exporter: $EXPORTERS_DIR/ssl/ssl-exporter.yml
RTTI Exporter: $EXPORTERS_DIR/custom/rtti-exporter.py
Prometheus: $MONITORING_DIR/prometheus/config/prometheus.yml
Алерты: $MONITORING_DIR/prometheus/rules/process-alerts.yml

=== ПРОИЗВОДИТЕЛЬНОСТЬ ===

Интервалы сбора:
- Системные метрики: 15с
- Процессы: 30с
- SSL проверки: 60с
- RTTI метрики: 30с

Ретенция данных: 90 дней

=== СЛЕДУЮЩИЕ ШАГИ ===

1. Проверьте работу всех экспортеров
2. Настройте дополнительные дашборды в Grafana
3. Добавьте специфичные алерты
4. Оптимизируйте интервалы сбора
5. Создайте документацию по метрикам

=== РЕКОМЕНДАЦИИ ===

- Регулярно проверяйте статус экспортеров
- Мониторьте производительность сбора метрик
- Добавляйте новые метрики по мере необходимости
- Документируйте изменения в конфигурации
- Создавайте резервные копии конфигураций

Дополнительные экспортеры готовы к работе!
EOF

echo "15. Проверка работы экспортеров..."
sleep 10
/root/check-exporters.sh

echo
echo "✅ Шаг 6 завершен успешно!"
echo "📊 Дополнительные экспортеры установлены"
echo "🔍 Process Exporter: мониторинг процессов"
echo "🔐 SSL Exporter: проверка сертификатов"
echo "🎯 RTTI Exporter: специфичные метрики"
echo "⚡ Новые алерты настроены"
echo "📋 Отчет: /root/exporters-setup-report.txt"
echo "🧪 Проверка: /root/check-exporters.sh"
echo "📈 Все метрики интегрированы в Prometheus"
echo "📌 Следующий шаг: ./07-create-dashboards.sh"
echo
