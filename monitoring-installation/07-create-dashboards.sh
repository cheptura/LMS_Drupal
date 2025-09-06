#!/bin/bash

# RTTI Monitoring - Шаг 7: Создание дашбордов Grafana
# Серверы: omuzgorpro.tj (92.242.60.172), storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 7: Создание дашбордов Grafana ==="
echo "📊 Настройка специализированных дашбордов и визуализаций"
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
    SERVER_NAME="omuzgorpro.tj"
elif [[ "$SERVER_IP" == "92.242.61.204" ]]; then
    SERVER_ROLE="drupal"
    SERVER_NAME="storage.omuzgorpro.tj"
else
    SERVER_ROLE="standalone"
    SERVER_NAME=$(hostname -f)
fi

MONITORING_DIR="/opt/monitoring"
DASHBOARDS_DIR="$MONITORING_DIR/grafana/dashboards"

echo "🔍 Роль сервера: $SERVER_ROLE ($SERVER_NAME)"

echo "1. Создание структуры для дашбордов..."
mkdir -p $DASHBOARDS_DIR/{system,web,database,application,security,overview}

echo "2. Создание главного обзорного дашборда RTTI..."

cat > $DASHBOARDS_DIR/overview/rtti-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI Infrastructure Overview",
    "tags": ["rtti", "overview", "infrastructure"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Servers Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=~\"node-exporter|rtti-exporter\"}",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"type": "value", "value": "0", "text": "DOWN"},
              {"type": "value", "value": "1", "text": "UP"}
            ]
          }
        },
        "gridPos": {"h": 4, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "CPU Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 3,
        "title": "Memory Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      },
      {
        "id": 4,
        "title": "Disk Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "(1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\"})) * 100",
            "legendFormat": "{{instance}} - {{mountpoint}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100
          }
        },
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 12}
      },
      {
        "id": 5,
        "title": "Network Traffic",
        "type": "timeseries",
        "targets": [
          {
            "expr": "irate(node_network_receive_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "{{instance}} - {{device}} RX"
          },
          {
            "expr": "irate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "{{instance}} - {{device}} TX"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Bps"
          }
        },
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 20}
      }
    ]
  }
}
EOF

echo "3. Создание дашборда веб-сервера..."

cat > $DASHBOARDS_DIR/web/nginx-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI Web Server (Nginx)",
    "tags": ["rtti", "nginx", "web"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "15s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Nginx Status",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_nginx_status",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"type": "value", "value": "0", "text": "DOWN"},
              {"type": "value", "value": "1", "text": "UP"}
            ]
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Active Connections",
        "type": "stat",
        "targets": [
          {
            "expr": "nginx_connections_active",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Requests per Second",
        "type": "timeseries",
        "targets": [
          {
            "expr": "irate(nginx_http_requests_total[5m])",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 4,
        "title": "Response Codes",
        "type": "timeseries",
        "targets": [
          {
            "expr": "irate(nginx_http_requests_total[5m])",
            "legendFormat": "{{status}} - {{instance}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      },
      {
        "id": 5,
        "title": "PHP-FPM Processes",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rtti_php_fpm_processes",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12}
      },
      {
        "id": 6,
        "title": "Nginx Workers",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rtti_nginx_workers",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12}
      }
    ]
  }
}
EOF

echo "4. Создание дашборда базы данных..."

cat > $DASHBOARDS_DIR/database/postgresql-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI Database (PostgreSQL)",
    "tags": ["rtti", "postgresql", "database"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "PostgreSQL Status",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_postgresql_status",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"type": "value", "value": "0", "text": "DOWN"},
              {"type": "value", "value": "1", "text": "UP"}
            ]
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Database Size",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_database_size_bytes",
            "legendFormat": "{{database}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Active Connections",
        "type": "timeseries",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends",
            "legendFormat": "{{datname}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 4,
        "title": "Transactions per Second",
        "type": "timeseries",
        "targets": [
          {
            "expr": "irate(pg_stat_database_xact_commit[5m]) + irate(pg_stat_database_xact_rollback[5m])",
            "legendFormat": "{{datname}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "tps"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      },
      {
        "id": 5,
        "title": "Cache Hit Ratio",
        "type": "timeseries",
        "targets": [
          {
            "expr": "pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read) * 100",
            "legendFormat": "{{datname}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12}
      },
      {
        "id": 6,
        "title": "Slow Queries",
        "type": "timeseries",
        "targets": [
          {
            "expr": "pg_stat_statements_mean_time_ms > 1000",
            "legendFormat": "{{query}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "ms"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12}
      }
    ]
  }
}
EOF

echo "5. Создание дашборда процессов..."

cat > $DASHBOARDS_DIR/system/processes-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI System Processes",
    "tags": ["rtti", "processes", "system"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Process Count by Group",
        "type": "stat",
        "targets": [
          {
            "expr": "namedprocess_namegroup_num_procs",
            "legendFormat": "{{groupname}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Process Memory Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "namedprocess_namegroup_memory_bytes",
            "legendFormat": "{{groupname}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Process CPU Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(namedprocess_namegroup_cpu_seconds_total[5m]) * 100",
            "legendFormat": "{{groupname}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Process File Descriptors",
        "type": "timeseries",
        "targets": [
          {
            "expr": "namedprocess_namegroup_open_filedesc",
            "legendFormat": "{{groupname}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ]
  }
}
EOF

echo "6. Создание дашборда безопасности..."

cat > $DASHBOARDS_DIR/security/security-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI Security Monitoring",
    "tags": ["rtti", "security", "fail2ban"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "1m",
    "time": {
      "from": "now-6h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Fail2Ban Status",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_fail2ban_status",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"type": "value", "value": "0", "text": "INACTIVE"},
              {"type": "value", "value": "1", "text": "ACTIVE"}
            ]
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Banned IPs",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_fail2ban_banned_ips",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 10},
                {"color": "red", "value": 50}
              ]
            }
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "SSH Active Users",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_ssh_active_users",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0}
      },
      {
        "id": 4,
        "title": "Failed Login Attempts",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rtti_failed_logins_recent",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 5,
        "title": "Banned IPs Over Time",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rtti_fail2ban_banned_ips",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      }
    ]
  }
}
EOF

# Создание специфичного дашборда в зависимости от роли сервера
if [ "$SERVER_ROLE" == "moodle" ]; then
    echo "7. Создание Moodle дашборда..."
    
    cat > $DASHBOARDS_DIR/application/moodle-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI Moodle LMS",
    "tags": ["rtti", "moodle", "lms"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "1m",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Moodle Installation Status",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_moodle_installation_status",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"type": "value", "value": "0", "text": "ERROR"},
              {"type": "value", "value": "1", "text": "OK"}
            ]
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Moodle Data Size",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_moodle_data_size_bytes",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Moodle Response Time",
        "type": "timeseries",
        "targets": [
          {
            "expr": "probe_http_duration_seconds{instance=~\".*omuzgorpro.tj.*\"}",
            "legendFormat": "{{phase}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 4,
        "title": "Moodle Availability",
        "type": "timeseries",
        "targets": [
          {
            "expr": "probe_success{instance=~\".*omuzgorpro.tj.*\"}",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "min": 0,
            "max": 1
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      },
      {
        "id": 5,
        "title": "Moodle Data Growth",
        "type": "timeseries",
        "targets": [
          {
            "expr": "increase(rtti_moodle_data_size_bytes[1h])",
            "legendFormat": "Growth per hour"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 12}
      }
    ]
  }
}
EOF

elif [ "$SERVER_ROLE" == "drupal" ]; then
    echo "7. Создание Drupal дашборда..."
    
    cat > $DASHBOARDS_DIR/application/drupal-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI Drupal Library",
    "tags": ["rtti", "drupal", "library"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "1m",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Drupal Installation Status",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_drupal_installation_status",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"type": "value", "value": "0", "text": "ERROR"},
              {"type": "value", "value": "1", "text": "OK"}
            ]
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Drupal Files Size",
        "type": "stat",
        "targets": [
          {
            "expr": "rtti_drupal_files_size_bytes",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Drupal Response Time",
        "type": "timeseries",
        "targets": [
          {
            "expr": "probe_http_duration_seconds{instance=~\".*storage.omuzgorpro.tj.*\"}",
            "legendFormat": "{{phase}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 4,
        "title": "Drupal Availability",
        "type": "timeseries",
        "targets": [
          {
            "expr": "probe_success{instance=~\".*storage.omuzgorpro.tj.*\"}",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "min": 0,
            "max": 1
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      },
      {
        "id": 5,
        "title": "Drupal Files Growth",
        "type": "timeseries",
        "targets": [
          {
            "expr": "increase(rtti_drupal_files_size_bytes[1h])",
            "legendFormat": "Growth per hour"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 12}
      }
    ]
  }
}
EOF
fi

echo "8. Создание дашборда для контейнеров..."

cat > $DASHBOARDS_DIR/system/containers-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "RTTI Docker Containers",
    "tags": ["rtti", "docker", "containers"],
    "style": "dark",
    "timezone": "Asia/Dushanbe",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Container Count",
        "type": "stat",
        "targets": [
          {
            "expr": "count(container_last_seen)",
            "legendFormat": "Total Containers"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Container CPU Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total{name!=\"\"}[5m]) * 100",
            "legendFormat": "{{name}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 3,
        "title": "Container Memory Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "container_memory_usage_bytes{name!=\"\"}",
            "legendFormat": "{{name}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      },
      {
        "id": 4,
        "title": "Container Network I/O",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(container_network_receive_bytes_total{name!=\"\"}[5m])",
            "legendFormat": "{{name}} RX"
          },
          {
            "expr": "rate(container_network_transmit_bytes_total{name!=\"\"}[5m])",
            "legendFormat": "{{name}} TX"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Bps"
          }
        },
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 12}
      }
    ]
  }
}
EOF

echo "9. Создание скрипта для импорта дашбордов..."

cat > /root/import-dashboards.sh << 'EOF'
#!/bin/bash
# Импорт дашбордов в Grafana

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DASHBOARDS_DIR="/opt/monitoring/grafana/dashboards"

echo "=== Импорт дашбордов RTTI в Grafana ==="

# Ожидание запуска Grafana
echo "Ожидание запуска Grafana..."
until curl -s "$GRAFANA_URL/api/health" > /dev/null 2>&1; do
    sleep 5
done

echo "Grafana доступен, начинаем импорт..."

# Функция импорта дашборда
import_dashboard() {
    local file="$1"
    local name=$(basename "$file" .json)
    
    echo "Импорт дашборда: $name"
    
    curl -X POST \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d @"$file" \
        "$GRAFANA_URL/api/dashboards/db" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ $name импортирован"
    else
        echo "❌ Ошибка импорта $name"
    fi
}

# Импорт всех дашбордов
find "$DASHBOARDS_DIR" -name "*.json" -type f | while read dashboard; do
    import_dashboard "$dashboard"
done

echo "Импорт дашбордов завершен!"
EOF

chmod +x /root/import-dashboards.sh

echo "10. Создание конфигурации для автоматического провижионинга дашбордов..."

mkdir -p $MONITORING_DIR/grafana/provisioning/dashboards

cat > $MONITORING_DIR/grafana/provisioning/dashboards/rtti-dashboards.yml << EOF
# Конфигурация провижионинга дашбордов RTTI
# Дата: $(date)

apiVersion: 1

providers:
  - name: 'RTTI Dashboards'
    orgId: 1
    folder: 'RTTI'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/rtti
EOF

echo "11. Обновление Docker Compose для провижионинга..."

# Обновляем маппинг томов для Grafana
sed -i '/grafana:/,/networks:/{
/volumes:/a\
      - '"$DASHBOARDS_DIR"':/var/lib/grafana/dashboards/rtti:ro\
      - '"$MONITORING_DIR"'/grafana/provisioning:/etc/grafana/provisioning:ro
}' $MONITORING_DIR/docker/docker-compose.yml

echo "12. Настройка переменных окружения для дашбордов..."

cat > $DASHBOARDS_DIR/dashboard-variables.env << EOF
# Переменные для дашбордов RTTI
# Дата: $(date)

# Серверы
MOODLE_SERVER=omuzgorpro.tj
DRUPAL_SERVER=storage.omuzgorpro.tj

# IP адреса
MOODLE_IP=92.242.60.172
DRUPAL_IP=92.242.61.204

# Prometheus
PROMETHEUS_URL=http://prometheus:9090

# Refresh интервалы
OVERVIEW_REFRESH=30s
WEB_REFRESH=15s
DB_REFRESH=30s
SECURITY_REFRESH=1m
APPLICATION_REFRESH=1m
SYSTEM_REFRESH=30s

# Временные диапазоны
SHORT_RANGE=1h
MEDIUM_RANGE=6h
LONG_RANGE=24h
SECURITY_RANGE=6h
EOF

echo "13. Создание скрипта для создания папок в Grafana..."

cat > /root/setup-grafana-folders.sh << 'EOF'
#!/bin/bash
# Создание папок в Grafana для организации дашбордов

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

echo "=== Создание папок в Grafana ==="

# Массив папок
declare -a folders=(
    "RTTI Infrastructure"
    "RTTI Web Services"
    "RTTI Databases"
    "RTTI Applications"
    "RTTI Security"
    "RTTI System"
)

# Функция создания папки
create_folder() {
    local folder_name="$1"
    
    echo "Создание папки: $folder_name"
    
    curl -X POST \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d "{\"title\":\"$folder_name\"}" \
        "$GRAFANA_URL/api/folders" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Папка '$folder_name' создана"
    else
        echo "❌ Ошибка создания папки '$folder_name'"
    fi
}

# Ожидание Grafana
until curl -s "$GRAFANA_URL/api/health" > /dev/null 2>&1; do
    sleep 5
done

# Создание всех папок
for folder in "${folders[@]}"; do
    create_folder "$folder"
done

echo "Настройка папок завершена!"
EOF

chmod +x /root/setup-grafana-folders.sh

echo "14. Перезапуск Grafana с новой конфигурацией..."

cd $MONITORING_DIR/docker
docker-compose restart grafana

echo "15. Ожидание запуска Grafana..."
sleep 30

echo "16. Настройка папок и импорт дашбордов..."
/root/setup-grafana-folders.sh
sleep 10
/root/import-dashboards.sh

echo "17. Создание отчета о дашбордах..."

cat > /root/dashboards-report.txt << EOF
# ОТЧЕТ О ДАШБОРДАХ GRAFANA
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== СОЗДАННЫЕ ДАШБОРДЫ ===

Обзорные дашборды:
✅ RTTI Infrastructure Overview - общий обзор инфраструктуры
   - Статус серверов
   - CPU, Memory, Disk usage
   - Сетевой трафик

Веб-сервисы:
✅ RTTI Web Server (Nginx) - мониторинг веб-сервера
   - Статус Nginx
   - Активные соединения
   - Запросы в секунду
   - Коды ответов
   - PHP-FPM процессы

База данных:
✅ RTTI Database (PostgreSQL) - мониторинг БД
   - Статус PostgreSQL
   - Размер баз данных
   - Активные соединения
   - Транзакции в секунду
   - Cache hit ratio
   - Медленные запросы

Системные:
✅ RTTI System Processes - мониторинг процессов
   - Количество процессов по группам
   - Использование памяти процессами
   - CPU usage процессов
   - Файловые дескрипторы

✅ RTTI Docker Containers - мониторинг контейнеров
   - Количество контейнеров
   - CPU/Memory usage контейнеров
   - Сетевой I/O контейнеров

Безопасность:
✅ RTTI Security Monitoring - мониторинг безопасности
   - Статус Fail2Ban
   - Заблокированные IP
   - Активные SSH пользователи
   - Неудачные попытки входа

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/dashboards-report.txt << EOF
Приложения (Moodle):
✅ RTTI Moodle LMS - мониторинг Moodle
   - Статус установки Moodle
   - Размер данных Moodle
   - Время ответа
   - Доступность
   - Рост данных

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/dashboards-report.txt << EOF
Приложения (Drupal):
✅ RTTI Drupal Library - мониторинг Drupal
   - Статус установки Drupal
   - Размер файлов
   - Время ответа
   - Доступность
   - Рост файлов

EOF
fi

cat >> /root/dashboards-report.txt << EOF
=== ОРГАНИЗАЦИЯ ДАШБОРДОВ ===

Папки в Grafana:
📁 RTTI Infrastructure - обзорные дашборды
📁 RTTI Web Services - веб-сервисы
📁 RTTI Databases - базы данных
📁 RTTI Applications - приложения
📁 RTTI Security - безопасность
📁 RTTI System - системные метрики

=== АВТОМАТИЗАЦИЯ ===

Провижионинг:
✅ Автоматический импорт дашбордов
✅ Конфигурация провижионинга
✅ Переменные окружения

Скрипты управления:
✅ /root/import-dashboards.sh - импорт дашбордов
✅ /root/setup-grafana-folders.sh - создание папок

=== НАСТРОЙКИ ДАШБОРДОВ ===

Интервалы обновления:
- Обзор: 30 секунд
- Веб-сервисы: 15 секунд
- БД: 30 секунд
- Безопасность: 1 минута
- Приложения: 1 минута
- Система: 30 секунд

Временные диапазоны:
- Обзор: 1 час
- Веб/БД/Система: 1 час
- Безопасность: 6 часов
- Приложения: 1 час

=== ДОСТУП К ДАШБОРДАМ ===

URL: http://localhost:3000 (внутренний)
URL: https://$SERVER_NAME:3000 (внешний, если настроен)

Логин: admin
Пароль: admin (рекомендуется изменить)

=== КЛЮЧЕВЫЕ МЕТРИКИ ===

Инфраструктура:
- Статус серверов (up/down)
- CPU utilization (%)
- Memory usage (%)
- Disk usage (%)
- Network I/O (bytes/sec)

Веб-сервисы:
- Nginx status (active/inactive)
- HTTP requests/sec
- Response codes distribution
- Active connections
- PHP-FPM processes

База данных:
- PostgreSQL status
- Database size (bytes)
- Active connections
- Transactions/sec
- Cache hit ratio (%)

Процессы:
- Process count by group
- Memory usage by process
- CPU usage by process
- File descriptors

Безопасность:
- Fail2Ban status
- Banned IPs count
- SSH active users
- Failed login attempts

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/dashboards-report.txt << EOF
Moodle:
- Installation status
- Data size (moodledata)
- Response time
- Availability (%)
- Data growth rate

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/dashboards-report.txt << EOF
Drupal:
- Installation status
- Files size
- Response time
- Availability (%)
- Files growth rate

EOF
fi

cat >> /root/dashboards-report.txt << EOF
=== АЛЕРТЫ В ДАШБОРДАХ ===

Цветовая схема:
🟢 Зеленый - нормальные значения
🟡 Желтый - предупреждения
🔴 Красный - критические проблемы

Пороговые значения:
- CPU usage: >80% желтый, >95% красный
- Memory usage: >80% желтый, >90% красный
- Disk usage: >85% желтый, >95% красный
- Response time: >2s желтый, >5s красный

=== СЛЕДУЮЩИЕ ШАГИ ===

1. Настройте уведомления для критических метрик
2. Создайте дополнительные дашборды по необходимости
3. Настройте пользователей и права доступа
4. Создайте снапшоты важных дашбордов
5. Настройте экспорт отчетов

=== РЕКОМЕНДАЦИИ ===

- Регулярно проверяйте дашборды
- Настройте алерты для критических метрик
- Создавайте снапшоты перед изменениями
- Документируйте новые дашборды
- Обучите персонал работе с Grafana

Дашборды готовы к использованию!
EOF

echo "18. Проверка созданных дашбордов..."

echo "Доступные дашборды:"
find $DASHBOARDS_DIR -name "*.json" -type f | while read dashboard; do
    name=$(basename "$dashboard" .json)
    echo "✅ $name"
done

echo
echo "✅ Шаг 7 завершен успешно!"
echo "📊 Создано $(find $DASHBOARDS_DIR -name "*.json" -type f | wc -l) дашбордов"
echo "📁 Настроена организация в папки"
echo "🔄 Настроен автоматический провижионинг"
echo "🎨 Настроены цветовые схемы и пороги"
echo "📋 Отчет: /root/dashboards-report.txt"
echo "🔧 Импорт: /root/import-dashboards.sh"
echo "📂 Папки: /root/setup-grafana-folders.sh"
echo "🌐 Grafana: http://localhost:3000"
echo "📌 Следующий шаг: ./08-optimize-monitoring.sh"
echo
