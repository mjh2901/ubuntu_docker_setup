#!/bin/bash

set -euo pipefail

# ----------------------------
# Ubuntu Server Provisioning Script
# ----------------------------

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

echo "=========================="
echo "Updating system packages..."
apt update && apt upgrade -y

# ----------------------------
# Install Git
# ----------------------------
echo "Installing Git..."
apt install -y git
git --version

# ----------------------------
# Install Neofetch and configure
# ----------------------------
echo "Installing Neofetch..."
apt install -y neofetch

NEOFETCH_USER="${SUDO_USER:-root}"
NEOFETCH_HOME=$(getent passwd "$NEOFETCH_USER" | cut -d: -f6)
if [[ -z "$NEOFETCH_HOME" || ! -d "$NEOFETCH_HOME" ]]; then
  echo "Could not determine a valid home directory for Neofetch user '$NEOFETCH_USER'. Exiting."
  exit 1
fi

echo "Configuring Neofetch for user '$NEOFETCH_USER'..."
touch "$NEOFETCH_HOME/.bashrc"
if ! grep -qx "neofetch" "$NEOFETCH_HOME/.bashrc"; then
  echo "neofetch" >> "$NEOFETCH_HOME/.bashrc"
fi

mkdir -p "$NEOFETCH_HOME/.config/neofetch"
cat << 'EOF' > "$NEOFETCH_HOME/.config/neofetch/config.conf"
print_info() {
    info title
    info underline

    info "OS" distro
    info "Kernel" kernel
    info "Uptime" uptime
    info "IP" "$(hostname -I | awk '{print $1}')"
    info "Shell" shell
    info "Terminal" term
    info "CPU" cpu
    info "Memory" memory
}
EOF

chown -R "$NEOFETCH_USER:$NEOFETCH_USER" "$NEOFETCH_HOME/.config/neofetch"
chown "$NEOFETCH_USER:$NEOFETCH_USER" "$NEOFETCH_HOME/.bashrc"

# ----------------------------
# Enable root SSH login with password
# ----------------------------
echo "Configuring SSH for root login..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo "✅ SSH root login enabled."

# ----------------------------
# Install Docker
# ----------------------------
echo "Installing Docker..."
apt install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
RELEASE=$(lsb_release -cs)
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $RELEASE stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker

# Prompt for the user who should manage Docker workloads.
DEFAULT_DOCKER_USER="${SUDO_USER:-}"
if [[ -n "$DEFAULT_DOCKER_USER" ]]; then
  read -rp "Enter the username to configure as Docker admin [$DEFAULT_DOCKER_USER]: " TARGET_USER
  TARGET_USER="${TARGET_USER:-$DEFAULT_DOCKER_USER}"
else
  read -rp "Enter the username to configure as Docker admin: " TARGET_USER
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "User '$TARGET_USER' does not exist. Exiting."
  exit 1
fi

usermod -aG docker "$TARGET_USER"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
  echo "Could not determine a valid home directory for '$TARGET_USER'. Exiting."
  exit 1
fi
echo "✅ Added '$TARGET_USER' to the docker group."

# ----------------------------
# Install Portainer
# ----------------------------
echo "Setting up Portainer..."
mkdir -p "$TARGET_HOME/docker/portainer"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/docker"
cd "$TARGET_HOME/docker/portainer"

# Create admin password file (mac0file)
echo 'mac0file' > admin-password
chmod 600 admin-password

cat <<EOF > compose.yml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9443:9443"
    environment:
      - TZ=America/Los_Angeles
      - ADMIN_PASSWORD_FILE=/run/secrets/admin_password
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
      - ./admin-password:/run/secrets/admin_password:ro

volumes:
  portainer_data:
EOF

chown "$TARGET_USER:$TARGET_USER" admin-password compose.yml
su - "$TARGET_USER" -c "cd '$TARGET_HOME/docker/portainer' && docker compose up -d"
echo "✅ Portainer is running on https://$(hostname -I | awk '{print $1}'):9443"

# ----------------------------
# Install Tugtainer
# ----------------------------
echo "Setting up Tugtainer..."
mkdir -p "$TARGET_HOME/docker/tugtainer"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/docker/tugtainer"

cat <<'EOF' > "$TARGET_HOME/docker/tugtainer/compose.yml"
services:
  tugtainer:
    image: ghcr.io/quenary/tugtainer:latest
    container_name: tugtainer
    volumes:
      - ./tugtainer_data:/tugtainer # Store database and config next to this compose file
      - /var/run/docker.sock:/var/run/docker.sock:ro # Direct Docker socket access
    restart: unless-stopped
    environment:
      # The list of available variables is in env.example on the GitHub repo
      DOCKER_HOST: unix:///var/run/docker.sock # Connects directly to local Docker socket
      # Set a secret for enhanced security, used for backend-agent requests signature
      AGENT_SECRET: your_secure_secret_here
    ports:
      - '9412:80' # Exposes the web UI on port 9412
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/docker/tugtainer/compose.yml"
su - "$TARGET_USER" -c "cd '$TARGET_HOME/docker/tugtainer' && docker compose up -d"
echo "✅ Tugtainer is running on http://$(hostname -I | awk '{print $1}'):9412"

# Show system summary at the end of provisioning.
neofetch
echo "=========================="
echo "All done! Git, Docker, Portainer, Tugtainer, SSH, and Neofetch are installed and configured."
echo "Log out and back in as '$TARGET_USER' before running Docker commands directly as that user."
