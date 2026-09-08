#!/bin/bash
set -e

# Подготовка папки ghazi
mkdir -p /ghazi
usermod -d /ghazi ghazi 2>/dev/null || true

# Папка для постоянного хранения ключей хоста
mkdir -p /ghazi/.ssh_host_keys

# Создание .bash_profile, если его нет
echo "cd /ghazi" >> /root/.bashrc
source ~/.bashrc

if [ ! -f /ghazi/.bash_profile ]; then
    cat << 'EOF' > /ghazi/.bash_profile
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
alias ll="ls -lah"
EOF
fi

# Настройка prompt
if ! grep -q "ghaziverse" /ghazi/.bashrc 2>/dev/null; then
    echo 'export PS1="\[\e[32m\][ghaziverse] \[\e[36m\]\u@\h:\w\$ \[\e[m\]"' >> /ghazi/.bashrc
fi

# Настройка ключей SSH для root
mkdir -p /root/.ssh
if [ -n "$AUTHORIZED_KEYS" ]; then
    echo "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys
fi
chown -R root:root /root
chmod 700 /root
chmod 700 /root/.ssh
if [ -f /root/.ssh/authorized_keys ]; then
    chmod 600 /root/.ssh/authorized_keys
fi

# Настройка ключей SSH и прав для ghazi
mkdir -p /ghazi/.ssh
if [ -n "$AUTHORIZED_KEYS" ]; then
    echo "$AUTHORIZED_KEYS" > /ghazi/.ssh/authorized_keys
fi
chown -R ghazi:ghazi /ghazi
chmod -R 775 /ghazi
chmod 700 /ghazi/.ssh
if [ -f /ghazi/.ssh/authorized_keys ]; then
    chmod 600 /ghazi/.ssh/authorized_keys
fi

# Генерация постоянных хост-ключей, если их ещё нет на томе
if [ ! -f /ghazi/.ssh_host_keys/ssh_host_ed25519_key ]; then
    echo "Generating new SSH host keys..."
    ssh-keygen -A >/dev/null
    cp /etc/ssh/ssh_host_* /ghazi/.ssh_host_keys/
fi

# Копирование хост-ключей в системную директорию с правами 0600
cp -f /ghazi/.ssh_host_keys/ssh_host_* /etc/ssh/
chown root:root /etc/ssh/ssh_host_*
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

# Уведомление в Telegram (отправляется ДО запуска sshd)
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
HOSTNAME_URL="https://${FLY_APP_NAME}.fly.dev"

if [ "$TELEGRAM_BOT_TOKEN" != "YOUR_BOT_TOKEN" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=🚀 Server di Fly.io aktif! Hostname: ${HOSTNAME_URL}" \
        -d "parse_mode=Markdown" || true
fi

# Запуск SSH сервера
echo "Starting SSH server on port 2222..."
exec /usr/sbin/sshd -D -o "ListenAddress 0.0.0.0:2222" -e
