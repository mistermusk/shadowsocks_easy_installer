#!/bin/bash
set -e

echo "Отключаем ss-local и redsocks..."

# Останавливаем и удаляем запущенные процессы
pkill ss-local || true
sudo pkill redsocks || true

echo "Удаляем правила iptables..."
# Очищаем цепочку REDSOCKS и удаляем её
sudo iptables -t nat -F REDSOCKS || true
sudo iptables -t nat -D OUTPUT -p tcp -j REDSOCKS || true
sudo iptables -t nat -X REDSOCKS || true

# Сохраняем изменения в iptables
sudo netfilter-persistent save

echo "Удаляем конфигурационные файлы..."

# Удаляем конфиг для shadowsocks
rm -f ~/ss-client.json

# Удаляем конфиг для redsocks
sudo rm -f /etc/redsocks.conf

echo "Удаляем пакеты shadowsocks-libev и redsocks..."
sudo apt remove --purge -y shadowsocks-libev redsocks

echo "Удаляем systemd-сервис shadowsocks (если был установлен)..."
sudo systemctl disable shadowsocks || true
sudo systemctl stop shadowsocks || true
sudo rm -f /etc/systemd/system/shadowsocks.service || true
sudo systemctl daemon-reload

echo "Удаляем файлы и пакеты Shadowsocks..."
sudo rm -f /etc/shadowsocks.json
sudo pip3 uninstall -y shadowsocks

echo "Все изменения откатаны! Ваш клиент снова в исходном состоянии."
