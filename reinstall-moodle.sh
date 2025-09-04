#!/bin/bash
# Скрипт полной переустановки Moodle 5.0+

echo "🔄 ПОЛНАЯ ПЕРЕУСТАНОВКА MOODLE 5.0+"
echo "=================================="
echo ""
echo "⚠️  ВНИМАНИЕ: Это удалит ВСЕ данные Moodle!"
echo "   - База данных будет полностью удалена"
echo "   - Все файлы Moodle будут удалены"
echo "   - Конфигурации будут сброшены"
echo ""
read -p "Продолжить полную переустановку? (y/N): " -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Переустановка отменена"
    exit 0
fi

echo ""
echo "📥 Скачиваем последний скрипт установки..."
wget -q "https://raw.githubusercontent.com/cheptura/LMS_Drupal/main/cloud-deployment/install-moodle-cloud.sh" -O install-moodle-cloud.sh
chmod +x install-moodle-cloud.sh

echo ""
echo "🧹 Очищаем предыдущую установку..."
./install-moodle-cloud.sh cleanup

echo ""
echo "🚀 Начинаем новую установку..."
./install-moodle-cloud.sh install

echo ""
echo "✅ Переустановка завершена!"
