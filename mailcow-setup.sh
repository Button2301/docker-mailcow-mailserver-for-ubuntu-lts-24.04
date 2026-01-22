#!/bin/bash
# ==========================================
# Ubuntu 22.04 LTS → Mailcow auto-setup
# Corrigeert hostname, hosts-file, timezone
# Installeert Docker, Docker Compose, Mailcow
# Maakt 2 mailboxen van 50 GB
# ==========================================

# --- CONFIGURATIE ---
HOSTNAME="mail.bknoop.nl"
SHORTNAME="mail"
TIMEZONE="Europe/Amsterdam"
STATIC_IP="192.168.1.50"   # Pas aan naar jouw VM IP
MAILCOW_DIR="/opt/mailcow-dockerized"
MAILBOX1="user1@bknoop.nl"
MAILBOX2="user2@bknoop.nl"
MAILBOX_QUOTA="51200"       # in MB
USER_NAME=$(whoami)

# --- 1️⃣ Hostname corrigeren ---
CURRENT_HOST=$(hostname)
if [ "$CURRENT_HOST" != "$HOSTNAME" ]; then
  echo "✔ Hostname aanpassen: $CURRENT_HOST → $HOSTNAME"
  sudo hostnamectl set-hostname $HOSTNAME
else
  echo "✔ Hostname correct: $HOSTNAME"
fi

# --- 2️⃣ /etc/hosts corrigeren ---
HOSTS_LINE="$STATIC_IP $HOSTNAME $SHORTNAME"
if ! grep -q "$HOSTNAME" /etc/hosts; then
  echo "✔ /etc/hosts updaten"
  sudo sed -i "/127.0.0.1/ a $HOSTS_LINE" /etc/hosts
else
  echo "✔ /etc/hosts al correct"
fi

# --- 3️⃣ Timezone corrigeren ---
CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ "$CURRENT_TZ" != "$TIMEZONE" ]; then
  echo "✔ Timezone instellen: $CURRENT_TZ → $TIMEZONE"
  sudo timedatectl set-timezone $TIMEZONE
else
  echo "✔ Timezone correct: $TIMEZONE"
fi

# --- 4️⃣ Systeem updaten ---
echo "✔ Systeem updaten..."
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

# --- 5️⃣ Basis-tools installeren ---
echo "✔ Basis-tools installeren..."
sudo apt install -y ca-certificates curl gnupg lsb-release git nano ufw

# --- 6️⃣ Docker installeren ---
echo "✔ Docker installeren..."
curl -fsSL https://get.docker.com | sudo sh
docker --version

# --- 7️⃣ Docker zonder sudo ---
echo "✔ Docker group toevoegen voor $USER_NAME..."
sudo usermod -aG docker $USER_NAME
newgrp docker
docker run hello-world

# --- 8️⃣ Docker Compose check ---
docker compose version

# --- 9️⃣ Firewall instellen ---
echo "✔ Firewall instellen..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 25
sudo ufw allow 587
sudo ufw allow 993
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable
sudo ufw status

# --- 10️⃣ Mailcow downloaden ---
if [ ! -d "$MAILCOW_DIR" ]; then
  echo "✔ Mailcow downloaden..."
  sudo git clone https://github.com/mailcow/mailcow-dockerized $MAILCOW_DIR
else
  echo "✔ Mailcow folder al aanwezig"
fi
cd $MAILCOW_DIR

# --- 11️⃣ Mailcow configureren ---
echo "✔ Mailcow configureren..."
sudo ./generate_config.sh <<EOF
$HOSTNAME
$TIMEZONE
EOF

# --- 12️⃣ Optionele .env aanpassingen ---
echo "✔ Mailcow .env optimaliseren..."
sudo sed -i 's/^SKIP_SOLR=.*/SKIP_SOLR=y/' .env
sudo sed -i 's/^MAILCOW_BRANCH=.*/MAILCOW_BRANCH=2024-10/' .env

# --- 13️⃣ Mailcow images downloaden ---
echo "✔ Mailcow images downloaden..."
docker compose pull

# --- 14️⃣ Mailcow starten ---
echo "✔ Mailcow starten..."
docker compose up -d

# --- 15️⃣ Status controleren ---
docker compose ps

# --- 16️⃣ Mailboxes aanmaken (via Mailcow CLI) ---
echo "✔ Mailboxes aanmaken..."
# Dit gebruikt de Mailcow CLI; vereist dat je admin wachtwoord invult in de interface
docker compose exec mailcow-mailcow /bin/bash -c "
mailcow-mailbox add $MAILBOX1 $MAILBOX_QUOTA
mailcow-mailbox add $MAILBOX2 $MAILBOX_QUOTA
"

echo "======================================="
echo "✔ Setup voltooid!"
echo "Webinterface: https://$HOSTNAME"
echo "Mailboxen: $MAILBOX1, $MAILBOX2 (50 GB elk)"
echo "======================================="
