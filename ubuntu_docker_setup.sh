#!/bin/bash
# ============================================================
# ubuntu_docker_setup.sh
# Installs Docker, Docker Compose plugin, Portainer, Neofetch,
# and sets up a user-centric Docker workspace.
# Works on Ubuntu 20.04+, 22.04+, 24.04+.
#
# Usage:
#   sudo bash ubuntu_docker_setup.sh
# ============================================================

set -e
set -o pipefail

log() {
    echo -e "\n[INFO] $1"
}

# ------------------------------
# Ensure root
# ------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Please run this script as root or using sudo."
    exit 1
fi

TARGET_USER=${SUDO_USER:-$(whoami)}
USER_HOME=$(eval echo "~$TARGET_USER")
DOCKER_HOME="$USER_HOME/docker"
PORTAINER_HOME="$DOCKER_HOME/portainer"

# ------------------------------
# Update packages
# ------------------------------
log "Updating system packages..."
apt update && apt upgrade -y

# ------------------------------
# Install prerequisites
# ------------------------------
log "Installing prerequisites..."
apt install -y ca-certificates curl gnupg lsb-release neofetch

# ------------------------------
# Docker repository setup
# ------------------------------
log "Adding Docker’s official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
RELEASE=$(lsb_release -cs)

# Check if Docker supports this release
if ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/$RELEASE/" >/dev/null 2>&1; then
    log "Codename $RELEASE not supported by Docker repo, falling back to jammy"
    RELEASE=jammy
fi

log "Setting up Docker repository for $RELEASE..."
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $RELEASE stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update

# ------------------------------
# Install Docker
# ------------------------------
log "Installing Docker Engine, CLI, containerd, and Docker Compose plugin..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ------------------------------
# Enable Docker service
# ------------------------------
log "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

# ------------------------------
# Add user to Docker group
# ------------------------------
log "Adding user '$TARGET_USER' to Docker group..."
usermod -aG docker $TARGET_USER

# ------------------------------
# Setup Docker workspace
# ------------------------------
log "Creating Docker workspace in $DOCKER_HOME..."
mkdir -p "$PORTAINER_HOME"

# ------------------------------
# Create Portainer docker-compose.yml
# ------------------------------
log "Creating Portainer docker-compose.yml..."
cat <<EOF > "$PORTAINER_HOME/docker-compose.yml"
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

volumes:
  portainer_data:
EOF

log "Portainer setup complete."
echo "To manage Portainer, run the following commands in $PORTAINER_HOME:"
echo "  docker compose up -d      # Start Portainer"
echo "  docker compose down        # Stop Portainer"

# ------------------------------
# Configure Neofetch
# ------------------------------
log "Configuring Neofetch..."

NEOFETCH_CONFIG_DIR="$USER_HOME/.config/neofetch"
NEOFETCH_CONFIG_FILE="$NEOFETCH_CONFIG_DIR/config.conf"
mkdir -p "$NEOFETCH_CONFIG_DIR"

# Copy default config if it doesn't exist
if [ ! -f "$NEOFETCH_CONFIG_FILE" ]; then
    cp /etc/neofetch/config.conf "$NEOFETCH_CONFIG_FILE" 2>/dev/null || touch "$NEOFETCH_CONFIG_FILE"
fi

# Add IP display if not already present
if ! grep -q "ip_address" "$NEOFETCH_CONFIG_FILE"; then
    echo -e "\n# Show IP address\ninfo 'IP Address' info ip_address" >> "$NEOFETCH_CONFIG_FILE"
fi

# Add Neofetch to user's bash profile
BASH_PROFILE="$USER_HOME/.bashrc"
if ! grep -q "neofetch" "$BASH_PROFILE"; then
    echo -e "\n# Run Neofetch at login\nneofetch" >> "$BASH_PROFILE"
fi

# Run Neofetch once
log "Running Neofetch..."
sudo -u "$TARGET_USER" neofetch

# ------------------------------
# Display final message
# ------------------------------
IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
PORTAINER_URL="http://$IP:9000"

log "✅ Docker workspace, Portainer, and Neofetch setup complete!"
echo "🌐 Access Portainer here: $PORTAINER_URL"
echo "Docker projects should be placed in $DOCKER_HOME for easy management."
echo "Use 'docker compose up -d' and 'docker compose down' in each project folder."
echo "Neofetch will run at login for user '$TARGET_USER'."
echo "Log out and back in for Docker group changes to take effect."
