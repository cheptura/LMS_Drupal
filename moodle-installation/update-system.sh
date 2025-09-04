#!/bin/bash

# RTTI System Update Script
# Обновление операционной системы и пакетов

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          System Update Script                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ошибка: Запустите скрипт с правами root"
    echo "   sudo ./update-system.sh"
    exit 1
fi

echo "🔄 Начинаем обновление системы..."
echo "📅 Дата: $(date)"
echo

# Обновление списка пакетов
echo "📋 Обновление списка пакетов..."
apt update

# Показать доступные обновления
echo "📦 Доступные обновления:"
apt list --upgradable

# Подтверждение от пользователя
read -p "🤔 Продолжить обновление? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Обновление отменено"
    exit 0
fi

# Обновление пакетов
echo "⬆️  Обновление пакетов..."
apt upgrade -y

# Обновление безопасности
echo "🛡️  Установка обновлений безопасности..."
unattended-upgrade

# Очистка
echo "🧹 Очистка ненужных пакетов..."
apt autoremove -y
apt autoclean

# Перезапуск сервисов если нужно
echo "🔄 Проверка необходимости перезапуска сервисов..."
if [ -f /var/run/reboot-required ]; then
    echo "⚠️  Требуется перезагрузка системы"
    echo "📋 Выполните: sudo reboot"
else
    echo "✅ Перезагрузка не требуется"
fi

# Проверка сервисов
echo "🔍 Проверка критических сервисов..."
systemctl is-active --quiet nginx && echo "✅ Nginx: OK" || echo "❌ Nginx: Проблема"
systemctl is-active --quiet postgresql && echo "✅ PostgreSQL: OK" || echo "❌ PostgreSQL: Проблема"
systemctl is-active --quiet redis-server && echo "✅ Redis: OK" || echo "❌ Redis: Проблема"

echo "🎉 Обновление системы завершено!"
