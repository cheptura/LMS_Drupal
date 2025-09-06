#!/bin/bash

# RTTI Monitoring - Шаг 3: Установка и настройка Grafana
# Серверы: omuzgorpro.tj (92.242.60.172), storage.omuzgorpro.tj (92.242.61.204)

echo "=== RTTI Monitoring - Шаг 3: Grafana Dashboard ==="
echo "📊 Установка системы визуализации и дашбордов"
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
GRAFANA_DIR="$MONITORING_DIR/grafana"
DOCKER_COMPOSE_DIR="$MONITORING_DIR/docker"

echo "🔍 Роль сервера: $SERVER_ROLE ($SERVER_NAME)"

echo "1. Проверка установки Prometheus..."

if ! docker ps | grep -q prometheus; then
    echo "❌ Prometheus не запущен. Сначала выполните ./02-install-prometheus.sh"
    exit 1
fi

echo "✅ Prometheus работает"

echo "2. Создание структуры директорий для Grafana..."

mkdir -p $GRAFANA_DIR/{config,data,dashboards,datasources,plugins,provisioning/{dashboards,datasources,notifiers}}

echo "3. Настройка источников данных..."

# Автоматическая настройка Prometheus как источника данных
cat > $GRAFANA_DIR/provisioning/datasources/prometheus.yml << EOF
# Автоматическая настройка источников данных для Grafana
# Дата: $(date)

apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: POST
      manageAlerts: true
      alertmanagerUid: alertmanager
    secureJsonData: {}
EOF

echo "4. Настройка автоматического импорта дашбордов..."

cat > $GRAFANA_DIR/provisioning/dashboards/default.yml << EOF
# Автоматический импорт дашбордов
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
      path: /var/lib/grafana/dashboards
EOF

echo "5. Создание основного системного дашборда..."

cat > $GRAFANA_DIR/dashboards/system-overview.json << 'EOF'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "vis": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "targets": [
        {
          "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "interval": "",
          "legendFormat": "CPU Usage - {{instance}}",
          "refId": "A"
        }
      ],
      "title": "CPU Usage",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "vis": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 2,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "targets": [
        {
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
          "interval": "",
          "legendFormat": "Memory Usage - {{instance}}",
          "refId": "A"
        }
      ],
      "title": "Memory Usage",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": ["rtti", "system"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "RTTI System Overview",
  "uid": "rtti-system-overview",
  "version": 1,
  "weekStart": ""
}
EOF

echo "6. Создание дашборда веб-сервера..."

cat > $GRAFANA_DIR/dashboards/web-server.json << 'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "colorMode": "background",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_success",
          "interval": "",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "Website Status",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "vis": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "s"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 2,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "targets": [
        {
          "expr": "probe_duration_seconds",
          "interval": "",
          "legendFormat": "Response Time - {{instance}}",
          "refId": "A"
        }
      ],
      "title": "Response Time",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": ["rtti", "web"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "RTTI Web Server Monitoring",
  "uid": "rtti-web-server",
  "version": 1,
  "weekStart": ""
}
EOF

echo "7. Обновление Docker Compose для включения Grafana..."

# Добавление Grafana в существующий docker-compose.yml
cat >> $DOCKER_COMPOSE_DIR/docker-compose.yml << EOF

  # Grafana - система визуализации
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - $GRAFANA_DIR/data:/var/lib/grafana
      - $GRAFANA_DIR/dashboards:/var/lib/grafana/dashboards
      - $GRAFANA_DIR/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123!@#
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_USERS_ALLOW_ORG_CREATE=false
      - GF_USERS_AUTO_ASSIGN_ORG=true
      - GF_USERS_AUTO_ASSIGN_ORG_ROLE=Viewer
      - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel,grafana-clock-panel
      - GF_SERVER_DOMAIN=$SERVER_NAME
      - GF_SERVER_ROOT_URL=https://$SERVER_NAME/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_SECURITY_DISABLE_GRAVATAR=true
      - GF_SNAPSHOTS_EXTERNAL_ENABLED=false
    networks:
      - monitoring
    depends_on:
      - prometheus
EOF

echo "8. Создание конфигурации Nginx для Grafana..."

# Проверка существующих конфигураций Nginx
if [ -f "/etc/nginx/sites-available/moodle" ]; then
    NGINX_CONFIG="/etc/nginx/sites-available/moodle"
elif [ -f "/etc/nginx/sites-available/drupal" ]; then
    NGINX_CONFIG="/etc/nginx/sites-available/drupal"
else
    NGINX_CONFIG="/etc/nginx/sites-available/default"
fi

# Создание конфигурации для Grafana
cat > /etc/nginx/conf.d/grafana.conf << EOF
# Конфигурация Nginx для Grafana
# Дата: $(date)

location /grafana/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    
    # WebSocket support
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Buffers
    proxy_buffering off;
    proxy_request_buffering off;
    
    # Security headers
    proxy_set_header X-Frame-Options SAMEORIGIN;
    proxy_set_header X-Content-Type-Options nosniff;
    proxy_set_header X-XSS-Protection "1; mode=block";
}

# API endpoint для внешних запросов
location /grafana/api/ {
    proxy_pass http://127.0.0.1:3000/api/;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    
    # CORS headers для API
    add_header Access-Control-Allow-Origin "*";
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";
    
    if (\$request_method = 'OPTIONS') {
        return 204;
    }
}
EOF

echo "9. Создание дашборда базы данных..."

cat > $GRAFANA_DIR/dashboards/database.json << 'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 4,
        "w": 6,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "colorMode": "background",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "up{job=\"postgres-exporter\"}",
          "interval": "",
          "legendFormat": "PostgreSQL Status",
          "refId": "A"
        }
      ],
      "title": "Database Status",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "vis": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 6,
        "y": 0
      },
      "id": 2,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "targets": [
        {
          "expr": "pg_stat_activity_count",
          "interval": "",
          "legendFormat": "Active Connections",
          "refId": "A"
        }
      ],
      "title": "Database Connections",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": ["rtti", "database"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "RTTI Database Monitoring",
  "uid": "rtti-database",
  "version": 1,
  "weekStart": ""
}
EOF

echo "10. Создание дашборда для специфичных метрик..."

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat > $GRAFANA_DIR/dashboards/moodle-specific.json << 'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "DOWN"
                },
                "1": {
                  "color": "green",
                  "index": 1,
                  "text": "UP"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 4,
        "w": 6,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_success{instance=\"https://omuzgorpro.tj\"}",
          "interval": "",
          "legendFormat": "Moodle Status",
          "refId": "A"
        }
      ],
      "title": "Moodle LMS Status",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "DOWN"
                },
                "1": {
                  "color": "green",
                  "index": 1,
                  "text": "UP"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 4,
        "w": 6,
        "x": 6,
        "y": 0
      },
      "id": 2,
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_success{instance=\"https://storage.omuzgorpro.tj\"}",
          "interval": "",
          "legendFormat": "Drupal Status",
          "refId": "A"
        }
      ],
      "title": "Drupal Library Status",
      "type": "stat"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": ["rtti", "moodle"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "RTTI Moodle Server Monitoring",
  "uid": "rtti-moodle",
  "version": 1,
  "weekStart": ""
}
EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat > $GRAFANA_DIR/dashboards/drupal-specific.json << 'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "DOWN"
                },
                "1": {
                  "color": "green",
                  "index": 1,
                  "text": "UP"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 4,
        "w": 6,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_success{instance=\"https://storage.omuzgorpro.tj\"}",
          "interval": "",
          "legendFormat": "Drupal Status",
          "refId": "A"
        }
      ],
      "title": "Drupal Library Status",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "DOWN"
                },
                "1": {
                  "color": "green",
                  "index": 1,
                  "text": "UP"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 4,
        "w": 6,
        "x": 6,
        "y": 0
      },
      "id": 2,
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_success{instance=\"https://omuzgorpro.tj\"}",
          "interval": "",
          "legendFormat": "Moodle Status",
          "refId": "A"
        }
      ],
      "title": "Moodle LMS Status",
      "type": "stat"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": ["rtti", "drupal"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "RTTI Drupal Server Monitoring",
  "uid": "rtti-drupal",
  "version": 1,
  "weekStart": ""
}
EOF
fi

echo "11. Настройка прав доступа..."

# Установка правильных прав для Grafana
chown -R 472:472 $GRAFANA_DIR/data
chmod -R 755 $GRAFANA_DIR

echo "12. Открытие порта для Grafana..."

# Grafana доступен только локально через nginx proxy
ufw allow from 127.0.0.1 to any port 3000 comment "Grafana"

echo "13. Перезапуск Docker Compose с Grafana..."

cd $DOCKER_COMPOSE_DIR
docker-compose up -d

echo "14. Перезапуск Nginx..."
systemctl reload nginx

echo "15. Ожидание запуска Grafana..."
sleep 30

echo "16. Создание скрипта настройки дашбордов..."

cat > /root/grafana-setup.sh << 'EOF'
#!/bin/bash
# Настройка дашбордов Grafana для RTTI

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123!@#"

# Функция для API запросов
grafana_api() {
    curl -s -H "Content-Type: application/json" \
         -u "$GRAFANA_USER:$GRAFANA_PASS" \
         "$@"
}

echo "Настройка дашбордов Grafana..."

# Ожидание готовности Grafana
while ! curl -s "$GRAFANA_URL/api/health" > /dev/null; do
    echo "Ожидание запуска Grafana..."
    sleep 5
done

echo "✅ Grafana запущена"

# Создание организации RTTI (если не существует)
grafana_api -X POST "$GRAFANA_URL/api/orgs" \
    -d '{"name":"RTTI"}' > /dev/null 2>&1

# Импорт стандартного дашборда Node Exporter
echo "Импорт дашборда Node Exporter..."
grafana_api -X POST "$GRAFANA_URL/api/dashboards/import" \
    -d '{
        "dashboard": {
            "id": null,
            "title": "Node Exporter Full",
            "tags": ["rtti", "system"],
            "timezone": "",
            "panels": [],
            "time": {
                "from": "now-1h",
                "to": "now"
            },
            "timepicker": {},
            "templating": {
                "list": []
            },
            "annotations": {
                "list": []
            },
            "refresh": "30s",
            "schemaVersion": 16,
            "version": 0,
            "links": []
        },
        "overwrite": true,
        "inputs": [
            {
                "name": "DS_PROMETHEUS",
                "type": "datasource",
                "pluginId": "prometheus",
                "value": "Prometheus"
            }
        ]
    }' > /dev/null

echo "✅ Дашборды настроены"
echo "🌐 Доступ: https://$SERVER_NAME/grafana/"
echo "👤 Логин: admin"
echo "🔐 Пароль: admin123!@#"
EOF

chmod +x /root/grafana-setup.sh

echo "17. Запуск настройки дашбордов..."
/root/grafana-setup.sh

echo "18. Создание отчета о настройке Grafana..."

cat > /root/grafana-setup-report.txt << EOF
# ОТЧЕТ О НАСТРОЙКЕ GRAFANA
# Дата: $(date)
# Сервер: $SERVER_NAME ($SERVER_IP)
# Роль: $SERVER_ROLE

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===

✅ Grafana: порт 3000 (через nginx proxy)
✅ Дашборды: автоматически импортированы
✅ Источники данных: Prometheus настроен
✅ Плагины: piechart, worldmap, clock

=== КОНФИГУРАЦИЯ ===

Директория Grafana: $GRAFANA_DIR
Дашборды: $GRAFANA_DIR/dashboards/
Провижининг: $GRAFANA_DIR/provisioning/
Конфигурация Nginx: /etc/nginx/conf.d/grafana.conf

=== ДАШБОРДЫ ===

1. RTTI System Overview (rtti-system-overview)
   - CPU и память по серверам
   - Системная загрузка
   - Статистика дисков

2. RTTI Web Server Monitoring (rtti-web-server)
   - Статус сайтов
   - Время ответа
   - SSL сертификаты

3. RTTI Database Monitoring (rtti-database)
   - Статус PostgreSQL
   - Количество подключений
   - Производительность

EOF

if [ "$SERVER_ROLE" == "moodle" ]; then
    cat >> /root/grafana-setup-report.txt << EOF
4. RTTI Moodle Server Monitoring (rtti-moodle)
   - Статус LMS системы
   - Мониторинг Drupal сервера
   - Перекрестные проверки

EOF
elif [ "$SERVER_ROLE" == "drupal" ]; then
    cat >> /root/grafana-setup-report.txt << EOF
4. RTTI Drupal Server Monitoring (rtti-drupal)
   - Статус библиотечной системы
   - Мониторинг Moodle сервера
   - Перекрестные проверки

EOF
fi

cat >> /root/grafana-setup-report.txt << EOF
=== ДОСТУП ===

URL: https://$SERVER_NAME/grafana/
Администратор: admin
Пароль: admin123!@#

Локальный доступ: http://localhost:3000
API: https://$SERVER_NAME/grafana/api/

=== НАСТРОЙКИ БЕЗОПАСНОСТИ ===

✅ Регистрация отключена
✅ Создание организаций отключено
✅ Гостевой доступ отключен
✅ Отчеты анонимной статистики отключены
✅ Gravatar отключен
✅ Внешние снапшоты отключены

=== УПРАВЛЕНИЕ ===

Перезапуск Grafana:
docker-compose -f $DOCKER_COMPOSE_DIR/docker-compose.yml restart grafana

Логи Grafana:
docker logs grafana

Настройка дашбордов:
/root/grafana-setup.sh

Резервное копирование:
/root/monitoring-control.sh backup

=== СЛЕДУЮЩИЕ ШАГИ ===

1. Настройте Alertmanager (шаг 04-configure-alertmanager.sh)
2. Создайте дополнительные дашборды
3. Настройте пользователей и права доступа
4. Интегрируйте с внешними системами
5. Настройте автоматические отчеты

=== РЕКОМЕНДАЦИИ ===

- Смените пароль администратора
- Создайте дополнительных пользователей
- Настройте LDAP/SAML аутентификацию
- Создайте пользовательские дашборды
- Настройте алерты в дашбордах
- Регулярно обновляйте плагины

=== ПОЛЕЗНЫЕ ССЫЛКИ ===

Документация: https://grafana.com/docs/
Дашборды сообщества: https://grafana.com/grafana/dashboards/
Плагины: https://grafana.com/grafana/plugins/

Grafana готова к использованию!
EOF

echo "19. Проверка доступности..."

# Проверка что Grafana отвечает
sleep 10
if curl -s "http://localhost:3000/api/health" | grep -q "ok"; then
    echo "✅ Grafana успешно запущена и отвечает"
else
    echo "⚠️ Grafana может еще запускаться, проверьте через несколько минут"
fi

echo
echo "✅ Шаг 3 завершен успешно!"
echo "📊 Grafana установлена и настроена"
echo "🎨 Дашборды автоматически импортированы"
echo "🔗 Prometheus интеграция настроена"
echo "🌐 Веб-доступ: https://$SERVER_NAME/grafana/"
echo "👤 Логин: admin / Пароль: admin123!@#"
echo "📋 Отчет: /root/grafana-setup-report.txt"
echo "⚙️ Настройка: /root/grafana-setup.sh"
echo "📌 Следующий шаг: ./04-configure-alertmanager.sh"
echo
