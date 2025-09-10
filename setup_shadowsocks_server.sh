#!/bin/bash
set -e

# Переменные — настрой здесь
PASSWORD="superstrongpassword"
PORT=8388
METHOD="aes-256-gcm"

echo "Обновляем систему..."
sudo apt update && sudo apt upgrade -y

echo "Устанавливаем python3 и pip3..."
sudo apt install -y python3 python3-pip

echo "Устанавливаем shadowsocks..."
sudo pip3 install https://github.com/shadowsocks/shadowsocks/archive/master.zip

echo "Создаём конфиг /etc/shadowsocks.json..."
sudo tee /etc/shadowsocks.json > /dev/null << EOF
{
    "server":"0.0.0.0",
    "server_port":$PORT,
    "local_address": "127.0.0.1",
    "local_port":1080,
    "password":"$PASSWORD",
    "timeout":300,
    "method":"$METHOD"
}
EOF

echo "Создаём systemd сервис shadowsocks..."
sudo tee /etc/systemd/system/shadowsocks.service > /dev/null << EOF
[Unit]
Description=Shadowsocks
After=network.target

[Service]
ExecStart=$(which ssserver) -c /etc/shadowsocks.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "Разрешаем порт $PORT в ufw (если ufw активен)..."
sudo ufw allow $PORT/tcp || true

echo "Запускаем и активируем shadowsocks сервис..."
sudo systemctl daemon-reload
sudo systemctl enable shadowsocks
sudo systemctl restart shadowsocks

echo "Готово! Shadowsocks сервер запущен на порту $PORT с паролем '$PASSWORD'"
