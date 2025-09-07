# Ubuntu Docker Setup with Portainer and Neofetch

This repository contains a script to set up **Docker**, the **Docker Compose plugin**, **Portainer**, and **Neofetch** on an Ubuntu server.  
It also creates a **user-centric Docker workspace** for future projects.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Using the Script](#using-the-script)
- [Docker Workspace](#docker-workspace)
- [Portainer Access](#portainer-access)
- [Neofetch](#neofetch)
- [Future Docker Projects](#future-docker-projects)

---

## Prerequisites

- Ubuntu 20.04+ or 22.04+
- Sudo or root privileges
- Internet connection

---

## Installation

1. **Update system packages:**

```bash
sudo apt update && sudo apt upgrade -y
```

2. **Install Git if not already installed:**

```bash
sudo apt install -y git
```

3. **Clone this repository:**

```bash
git clone https://github.com/your-username/ubuntu-docker-setup.git
```

4. **Navigate to the repository folder:**

```bash
cd ubuntu-docker-setup
```

---

## Using the Script

Run the setup script with root privileges:

```bash
sudo bash ubuntu_docker_setup.sh
```

The script will:

- Install Docker Engine, Docker CLI, containerd, and Docker Compose plugin
- Add your user to the Docker group
- Create a Docker workspace at `~/docker`
- Set up Portainer in `~/docker/portainer` with `docker-compose.yml`
- Install Neofetch, configure it to show the server IP, and run it at login

> **Note:** You may need to log out and back in for Docker group changes to take effect.

---

## Docker Workspace

All future Docker projects should live in the Docker workspace:

```
~/docker
```

Each project can have its own `docker-compose.yml` file.  
For example, Portainer is located in:

```
~/docker/portainer
```

Manage containers with:

```bash
cd ~/docker/portainer
docker compose up -d    # Start containers
docker compose down      # Stop containers
```

---

## Portainer Access

After running the script, you can access Portainer via your server's IP on port 9000:

```
http://<server-ip>:9000
```

Replace `<server-ip>` with the IP address shown at the end of the setup script.

---

## Neofetch

Neofetch is installed and configured to display your server's IP address.  
It will automatically run when the user logs in.

---

## Future Docker Projects

To create a new Docker project:

1. Create a new folder inside `~/docker`:

```bash
mkdir ~/docker/myproject
cd ~/docker/myproject
```

2. Add your `docker-compose.yml` for the project.
3. Start or stop your containers:

```bash
docker compose up -d
docker compose down
```

This workflow ensures all Docker projects are organized and easy to manage.

---

## License

This repository is licensed under the MIT License. See `LICENSE` for details.


