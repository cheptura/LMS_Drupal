#!/bin/bash

# RTTI Drupal - Шаг 1: Подготовка системы
# Сервер: library.rtti.tj (92.242.61.204)

echo "=== RTTI Drupal - Шаг 1: Подготовка системы ==="
echo "🛠️  Обновление Ubuntu и установка базовых пакетов"
echo "📅 Дата: $(date)"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    exit 1
fi

echo "1. Обновление списка пакетов..."
apt update

echo "2. Обновление системы..."
apt upgrade -y

echo "3. Установка базовых пакетов..."
apt install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    tree \
    nano \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

echo "4. Настройка часового пояса..."
timedatectl set-timezone Asia/Dushanbe
echo "✅ Часовой пояс установлен: $(timedatectl | grep "Time zone")"

echo "5. Настройка локализации..."
locale-gen ru_RU.UTF-8
locale-gen en_US.UTF-8
update-locale LANG=ru_RU.UTF-8

echo "6. Установка файрвола UFW..."
apt install -y ufw

echo "7. Базовая настройка файрвола..."
# Сброс к значениям по умолчанию
ufw --force reset

# Правила по умолчанию
ufw default deny incoming
ufw default allow outgoing

# SSH доступ
ufw allow 22/tcp comment "SSH"

# HTTP и HTTPS
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# Включение файрвола
ufw --force enable

echo "8. Настройка автоматических обновлений безопасности..."
apt install -y unattended-upgrades

# Конфигурация автоматических обновлений
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Включение автоматических обновлений
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

echo "9. Оптимизация системы..."
# Увеличение лимитов файлов
cat >> /etc/security/limits.conf << 'EOF'
# Drupal optimizations
www-data soft nofile 65536
www-data hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

# Оптимизация sysctl
cat > /etc/sysctl.d/99-drupal.conf << 'EOF'
# Drupal system optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
EOF

sysctl -p /etc/sysctl.d/99-drupal.conf

echo "10. Создание пользователя для Drupal (если не существует)..."
if ! id "drupal" &>/dev/null; then
    useradd -r -s /bin/false drupal
    echo "✅ Пользователь drupal создан"
else
    echo "ℹ️  Пользователь drupal уже существует"
fi

echo "11. Установка дополнительных утилит для мониторинга..."
apt install -y \
    iotop \
    iftop \
    nethogs \
    ncdu \
    fail2ban

echo "12. Настройка fail2ban для защиты SSH..."
systemctl enable fail2ban
systemctl start fail2ban

# Базовая конфигурация fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl restart fail2ban

echo "13. Проверка статуса сервисов..."
echo "UFW статус:"
ufw status

echo -e "\nFail2ban статус:"
systemctl status fail2ban --no-pager -l | head -5

echo "14. Создание информационного файла..."
cat > /root/drupal-system-info.txt << EOF
# Информация о системе для Drupal RTTI Library
# Дата подготовки: $(date)
# Сервер: library.rtti.tj ($(hostname -I | awk '{print $1}'))

=== СИСТЕМНАЯ ИНФОРМАЦИЯ ===
ОС: $(lsb_release -d | cut -f2)
Ядро: $(uname -r)
Архитектура: $(uname -m)
Часовой пояс: $(timedatectl | grep "Time zone" | awk '{print $3}')
Память: $(free -h | grep "Mem:" | awk '{print $2}')
Диск: $(df -h / | tail -1 | awk '{print $2}' | tr -d '\n') всего, $(df -h / | tail -1 | awk '{print $4}') свободно

=== УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ ===
✅ Базовые пакеты (curl, wget, git, etc.)
✅ UFW файрвол
✅ Автоматические обновления безопасности
✅ Fail2ban защита
✅ Системные оптимизации

=== СЕТЕВАЯ БЕЗОПАСНОСТЬ ===
UFW статус: $(ufw status | head -1 | awk '{print $2}')
Открытые порты: 22 (SSH), 80 (HTTP), 443 (HTTPS)
Fail2ban: Активен

=== СЛЕДУЮЩИЕ ШАГИ ===
1. Запустите: ./02-install-webserver.sh
2. Проверьте логи: /var/log/fail2ban.log
3. Мониторинг: htop, iotop, nethogs

=== ВАЖНЫЕ КОМАНДЫ ===
Статус UFW: ufw status
Логи fail2ban: tail -f /var/log/fail2ban.log
Проверка обновлений: apt list --upgradable
Системные логи: journalctl -f
EOF

echo "15. Финальная проверка..."
echo "Проверка UFW:"
ufw status numbered

echo -e "\nПроверка fail2ban:"
fail2ban-client status

echo -e "\nДисковое пространство:"
df -h | grep -E "(Filesystem|/dev)"

echo -e "\nОперативная память:"
free -h

echo
echo "✅ Шаг 1 завершен успешно!"
echo "📌 Система Ubuntu подготовлена для Drupal"
echo "📌 Базовая безопасность настроена"
echo "📌 Файрвол активирован"
echo "📌 Автоматические обновления включены"
echo "📌 Информация о системе: /root/drupal-system-info.txt"
echo "📌 Следующий шаг: ./02-install-webserver.sh"
echo
