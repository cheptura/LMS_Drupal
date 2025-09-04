#!/bin/bash

# RTTI Moodle - Шаг 1: Подготовка системы
# Сервер: lms.rtti.tj (92.242.60.172)

echo "=== RTTI Moodle - Шаг 1: Подготовка системы ==="
echo "🎓 Сервер: lms.rtti.tj"
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

echo
echo "✅ Шаг 1 завершен успешно!"
echo "📌 Система подготовлена для установки Moodle"
echo "📌 Следующий шаг: ./02-install-webserver.sh"
echo
