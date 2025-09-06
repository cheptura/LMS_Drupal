#!/bin/bash

# RTTI Moodle - Шаг 1: Подготовка системы
# Сервер: omuzgorpro.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 1: Подготовка системы ==="
echo "🎓 Сервер: omuzgorpro.tj"
echo "📅 Дата: $(date)"
echo "🖥️  IP: $(hostname -I | awk '{print $1}')"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./01-prepare-system.sh"
    exit 1
fi

echo "1. Обновление списка пакетов..."
apt update

echo "2. Обновление установленных пакетов..."
apt upgrade -y

echo "3. Установка базовых утилит..."
apt install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    nano \
    vim \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    cron

echo "4. Настройка временной зоны..."
timedatectl set-timezone Asia/Dushanbe

echo "5. Настройка локали..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

echo "6. Очистка кэша пакетов..."
apt autoremove -y
apt autoclean

echo "7. Создание директорий..."
mkdir -p /var/log/rtti-installation
mkdir -p /root/rtti-backup

echo "8. Настройка базового firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

echo "9. Настройка автоматических обновлений безопасности..."
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
Unattended-Upgrade::Mail "admin@omuzgorpro.tj";
EOF

# Включение автоматических обновлений
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

echo
echo "✅ Шаг 1 завершен успешно!"
echo "📌 Система подготовлена для установки Moodle"
echo "📌 Следующий шаг: ./02-install-webserver.sh"
echo
