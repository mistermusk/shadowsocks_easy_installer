#!/bin/bash
set -e

# Переменные — настрой здесь
SERVER_IP="IP_твоего_сервера"
SERVER_PORT=8388
PASSWORD="superstrongpassword"
METHOD="aes-256-gcm"

echo "Обновляем систему..."
sudo apt update && sudo apt upgrade -y

echo "Устанавливаем shadowsocks-libev и redsocks..."
sudo apt install -y shadowsocks-libev redsocks iptables-persistent

echo "Создаём конфиг клиента shadowsocks-libev..."
tee ~/ss-client.json > /dev/null << EOF
{
    "server":"$SERVER_IP",
    "server_port":$SERVER_PORT,
    "local_address": "127.0.0.1",
    "local_port":1080,
    "password":"$PASSWORD",
    "timeout":300,
    "method":"$METHOD"
}
EOF

echo "Создаём конфиг для redsocks..."
sudo tee /etc/redsocks.conf > /dev/null << EOF
base {
    log_debug = off;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 12345;

    ip = 127.0.0.1;
    port = 1080;

    type = socks5;
    login = "";
    password = "";
}
EOF

echo "Запускаем shadowsocks локальный клиент в фоне..."
pkill ss-local || true
nohup ss-local -c ~/ss-client.json > ~/ss-local.log 2>&1 &

echo "Запускаем redsocks..."
sudo pkill redsocks || true
sudo redsocks -c /etc/redsocks.conf &

echo "Настраиваем iptables для перенаправления трафика через redsocks..."

sudo iptables -t nat -N REDSOCKS || true

# Очищаем старые правила из цепочки REDSOCKS (если есть)
sudo iptables -t nat -F REDSOCKS || true

# Исключения для локальных адресов
sudo iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
sudo iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN

# Исключаем IP сервера shadowsocks (чтобы трафик к серверу не шёл через прокси)
sudo iptables -t nat -A REDSOCKS -d $SERVER_IP -j RETURN

# Перенаправляем весь TCP трафик на redsocks
sudo iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345

# Применяем цепочку к исходящему трафику
sudo iptables -t nat -A OUTPUT -p tcp -j REDSOCKS

echo "Сохраняем правила iptables..."
sudo netfilter-persistent save

echo "Готово! Клиент Shadowsocks запущен, весь TCP-трафик перенаправляется через Shadowsocks."
echo "Если хочешь остановить ss-local, выполни: pkill ss-local"
echo "Если хочешь остановить redsocks, выполни: sudo pkill redsocks"
