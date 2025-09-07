#!/bin/bash

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

echo "Configuring Neofetch for root login..."
touch /root/.bashrc
if ! grep -q "neofetch" /root/.bashrc; then
  echo "neofetch" >> /root/.bashrc
fi

mkdir -p /root/.config/neofetch
cat << 'EOF' > /root/.config/neofetch/config.conf
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

# ----------------------------
# Install Portainer
# ----------------------------
echo "Setting up Portainer..."
mkdir -p /opt/portainer
cd /opt/portainer

# Create admin password file (mac0file)
echo 'mac0file' > admin-password
chmod 600 admin-password

cat <<EOF > docker-compose.yml
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

docker compose up -d
echo "✅ Portainer is running on https://$(hostname -I | awk '{print $1}'):9443"

# ----------------------------
# Install code-server
# ----------------------------
echo "Setting up code-server..."
mkdir -p /opt/code-server/config /opt/code-server/workspace

cat <<EOF > /opt/code-server/docker-compose.yml
services:
  code-server:
    image: lscr.io/linuxserver/code-server:latest
    container_name: code-server
    environment:
      - PUID=0
      - PGID=0
      - TZ=America/Los_Angeles
      - PROXY_DOMAIN=code-code.mikehathaway.com
      - DEFAULT_WORKSPACE=/config/workspace
      - PWA_APPNAME=code-server
    volumes:
      - code_config:/config
    ports:
      - 8443:8443
    restart: unless-stopped

volumes:
  code_config:
EOF

cd /opt/code-server
docker compose up -d
echo "✅ code-server is running on https://$(hostname -I | awk '{print $1}'):8443"

echo "=========================="
echo "All done! Git, Docker, Portainer, code-server, SSH, and Neofetch are installed and configured."
