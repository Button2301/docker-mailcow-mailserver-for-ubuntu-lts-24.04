#!/bin/bash
# ==========================================
# Fully Automated Mailcow Setup for Ubuntu LTS
# Non-interactive, ready for GitHub deployment
# ==========================================

# --- Configuratie ---
HOSTNAME=${HOSTNAME:-mail.bknoop.nl}
STATIC_IP=${STATIC_IP:-192.168.56.101} # Pas aan naar VM IP
TIMEZONE=${TIMEZONE:-Europe/Amsterdam}
MAILCOW_DIR="/opt/mailcow-dockerized"
MAILBOX1="user1@bknoop.nl"
MAILBOX2="user2@bknoop.nl"
MAILBOX_QUOTA="51200" # in MB
USER_NAME=$(whoami)

echo "✔ START Mailcow setup: HOSTNAME=$HOSTNAME, IP=$STATIC_IP, TZ=$TIMEZONE"

# --- 1️⃣ Hostname ---
CURRENT_HOST=$(hostname)
if [ "$CURRENT_HOST" != "$HOSTNAME" ]; then
  echo "✔ Setting hostname: $CURRENT_HOST -> $HOSTNAME"
  sudo hostnamectl set-hostname $HOSTNAME
else
  echo "✔ Hostname already correct: $HOSTNAME"
fi

# --- 2️⃣ /etc/hosts ---
HOSTS_LINE="$STATIC_IP $HOSTNAME $(echo $HOSTNAME | cut -d'.' -f1)"
if ! grep -q "$HOSTNAME" /etc/hosts; then
  echo "✔ Updating /etc/hosts"
  sudo sed -i "/127.0.0.1/ a $HOSTS_LINE" /etc/hosts
else
  echo "✔ /etc/hosts already contains $HOSTNAME"
fi

# --- 3️⃣ Timezone ---
CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ "$CURRENT_TZ" != "$TIMEZONE" ]; then
  echo "✔ Setting timezone: $CURRENT_TZ -> $TIMEZONE"
  sudo timedatectl set-timezone $TIMEZONE
else
  echo "✔ Timezone already correct: $TIMEZONE"
fi

# --- 4️⃣ Update system ---
echo "✔ Updating system..."
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

# --- 5️⃣ Install base tools ---
echo "✔ Installing base packages..."
sudo apt install -y ca-certificates curl gnupg lsb-release git nano ufw

# --- 6️⃣ Install Docker ---
echo "✔ Installing Docker..."
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER_NAME
newgrp docker
docker run hello-world

# --- 7️⃣ Docker Compose plugin ---
sudo apt install docker-compose-plugin -y
docker compose version

# --- 8️⃣ Firewall ---
echo "✔ Configuring firewall..."
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

# --- 9️⃣ Clone Mailcow ---
if [ ! -d "$MAILCOW_DIR" ]; then
  echo "✔ Cloning Mailcow..."
  sudo git clone https://github.com/mailcow/mailcow-dockerized $MAILCOW_DIR
else
  echo "✔ Mailcow folder already exists"
fi
cd $MAILCOW_DIR

# --- 10️⃣ Generate config ---
echo "✔ Generating Mailcow config..."
sudo ./generate_config.sh <<EOF
$HOSTNAME
$TIMEZONE
EOF

# --- 11️⃣ Pull Docker images ---
echo "✔ Pulling Docker images..."
docker compose pull

# --- 12️⃣ Start Mailcow ---
echo "✔ Starting Mailcow..."
docker compose up -d

# --- 13️⃣ Check containers ---
docker compose ps

# --- 14️⃣ Create mailboxes ---
echo "✔ Creating mailboxes..."
docker compose exec -T mailcow-mailcow /bin/bash -c "
mailcow-mailbox add $MAILBOX1 $MAILBOX_QUOTA
mailcow-mailbox add $MAILBOX2 $MAILBOX_QUOTA
"

echo "======================================="
echo "✔ Setup voltooid!"
echo "Webinterface: https://$HOSTNAME"
echo "Mailboxen: $MAILBOX1, $MAILBOX2 ($MAILBOX_QUOTA MB elk)"
echo "======================================="
