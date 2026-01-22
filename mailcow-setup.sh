#!/bin/bash
# ==========================================
# Fully Automated Mailcow Setup for Ubuntu LTS
# Non-interactive, ready for GitHub deployment
# Includes summary at the end
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

# --- Logging arrays ---
SUCCESS=()
SKIPPED=()
FAILED=()

log_success() { SUCCESS+=("$1"); }
log_skip() { SKIPPED+=("$1"); }
log_fail() { FAILED+=("$1"); }

echo "✔ START Mailcow setup: HOSTNAME=$HOSTNAME, IP=$STATIC_IP, TZ=$TIMEZONE"

# --- 1️⃣ Hostname ---
CURRENT_HOST=$(hostname)
if [ "$CURRENT_HOST" != "$HOSTNAME" ]; then
  if sudo hostnamectl set-hostname $HOSTNAME; then
    echo "✔ Hostname aangepast: $CURRENT_HOST -> $HOSTNAME"
    log_success "Hostname ingesteld"
  else
    log_fail "Hostname aanpassen mislukt"
  fi
else
  echo "✔ Hostname correct: $HOSTNAME"
  log_skip "Hostname al correct"
fi

# --- 2️⃣ /etc/hosts ---
HOSTS_LINE="$STATIC_IP $HOSTNAME $(echo $HOSTNAME | cut -d'.' -f1)"
if ! grep -q "$HOSTNAME" /etc/hosts; then
  if sudo sed -i "/127.0.0.1/ a $HOSTS_LINE" /etc/hosts; then
    echo "✔ /etc/hosts bijgewerkt"
    log_success "/etc/hosts toegevoegd"
  else
    log_fail "/etc/hosts bijwerken mislukt"
  fi
else
  echo "✔ /etc/hosts al correct"
  log_skip "/etc/hosts al aanwezig"
fi

# --- 3️⃣ Timezone ---
CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ "$CURRENT_TZ" != "$TIMEZONE" ]; then
  if sudo timedatectl set-timezone $TIMEZONE; then
    echo "✔ Timezone ingesteld: $TIMEZONE"
    log_success "Timezone ingesteld"
  else
    log_fail "Timezone instellen mislukt"
  fi
else
  echo "✔ Timezone correct: $TIMEZONE"
  log_skip "Timezone al correct"
fi

# --- 4️⃣ Update system ---
echo "✔ Systeem updaten..."
if sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y; then
  log_success "Systeem geüpdatet"
else
  log_fail "Systeem update mislukt"
fi

# --- 5️⃣ Install base tools ---
echo "✔ Basis-tools installeren..."
if sudo apt install -y ca-certificates curl gnupg lsb-release git nano ufw; then
  log_success "Basis-tools geïnstalleerd"
else
  log_fail "Basis-tools installatie mislukt"
fi

# --- 6️⃣ Docker installeren ---
echo "✔ Docker installeren..."
if curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker $USER_NAME; then
  newgrp docker
  docker run hello-world && log_success "Docker geïnstalleerd"
else
  log_fail "Docker installatie mislukt"
fi

# --- 7️⃣ Docker Compose plugin ---
if sudo apt install docker-compose-plugin -y; then
  docker compose version && log_success "Docker Compose plugin geïnstalleerd"
else
  log_fail "Docker Compose plugin installatie mislukt"
fi

# --- 8️⃣ Firewall ---
echo "✔ Firewall configureren..."
if sudo ufw default deny incoming && sudo ufw default allow outgoing && \
   sudo ufw allow ssh && sudo ufw allow 25 && sudo ufw allow 587 && \
   sudo ufw allow 993 && sudo ufw allow 80 && sudo ufw allow 443 && \
   sudo ufw --force enable; then
  sudo ufw status
  log_success "Firewall ingesteld"
else
  log_fail "Firewall instellen mislukt"
fi

# --- 9️⃣ Clone Mailcow ---
if [ ! -d "$MAILCOW_DIR" ]; then
  if sudo git clone https://github.com/mailcow/mailcow-dockerized $MAILCOW_DIR; then
    log_success "Mailcow gedownload"
  else
    log_fail "Mailcow download mislukt"
  fi
else
  echo "✔ Mailcow folder al aanwezig"
  log_skip "Mailcow folder al aanwezig"
fi
cd $MAILCOW_DIR

# --- 10️⃣ Generate config ---
echo "✔ Mailcow config genereren..."
if sudo ./generate_config.sh <<EOF
$HOSTNAME
$TIMEZONE
EOF
then
  log_success "Mailcow config gegenereerd"
else
  log_fail "Mailcow config genereren mislukt"
fi

# --- 11️⃣ Pull Docker images ---
echo "✔ Mailcow Docker images pullen..."
if docker compose pull; then
  log_success "Docker images gedownload"
else
  log_fail "Docker images pullen mislukt"
fi

# --- 12️⃣ Start Mailcow ---
echo "✔ Mailcow starten..."
if docker compose up -d; then
  log_success "Mailcow containers gestart"
else
  log_fail "Mailcow containers starten mislukt"
fi

# --- 13️⃣ Check containers ---
docker compose ps

# --- 14️⃣ Mailboxes aanmaken ---
echo "✔ Mailboxes aanmaken..."
if docker compose exec -T mailcow-mailcow /bin/bash -c "
mailcow-mailbox add $MAILBOX1 $MAILBOX_QUOTA
mailcow-mailbox add $MAILBOX2 $MAILBOX_QUOTA
"; then
  log_success "Mailboxes aangemaakt"
else
  log_fail "Mailboxes aanmaken mislukt"
fi

# --- 15️⃣ Samenvatting ---
echo "======================================="
echo "✔ Mailcow Setup Samenvatting:"
echo "✅ Succesvol:"
for i in "${SUCCESS[@]}"; do echo "   - $i"; done
echo "⚠ Overgeslagen / al correct:"
for i in "${SKIPPED[@]}"; do echo "   - $i"; done
if [ ${#FAILED[@]} -ne 0 ]; then
  echo "❌ Mislukt:"
  for i in "${FAILED[@]}"; do echo "   - $i"; done
else
  echo "✔ Geen fouten gedetecteerd"
fi
echo "======================================="
echo "Webinterface: https://$HOSTNAME"
echo "Mailboxen: $MAILBOX1, $MAILBOX2 ($MAILBOX_QUOTA MB elk)"
echo "======================================="
