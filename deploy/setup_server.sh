#!/usr/bin/env bash
#
# setup_server.sh — one-time server provisioning for GardenHouse
# ==============================================================
# Run as root (or with sudo) on a clean Ubuntu 24.04 (Noble) server.
# Installs: nginx, PostgreSQL, certbot, git, Python 3.12 venv, Node.js 22,
# and creates the application user + /var/www/gardenhouse directory.
#
# Usage:
#   sudo bash setup_server.sh
#
# Safe to re-run; every step is idempotent.

set -euo pipefail

# These scripts must run as root: they install system packages, create the
# app user, configure systemd units and nginx, and use `sudo -u` internally.
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root (or with full sudo):"
    echo "  sudo bash $0"
    exit 1
fi

APP_NAME="gardenhouse"
APP_USER="maintest"
APP_DIR="/var/www/${APP_NAME}"
DOMAIN="maintest.site"
SERVER_IP="193.181.216.124"

echo "==> [1/6] Updating apt package index"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

echo "==> [2/6] Installing system packages"
apt-get install -y \
    nginx \
    postgresql \
    postgresql-contrib \
    git \
    curl \
    ca-certificates \
    gnupg \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    build-essential \
    libpq-dev \
    certbot \
    python3-certbot-nginx \
    ufw

echo "==> [3/6] Installing Node.js 22 (NodeSource)"
if ! command -v node >/dev/null 2>&1 || ! node --version 2>/dev/null | grep -q "^v22"; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi
echo "Node: $(node --version), npm: $(npm --version)"

echo "==> [4/6] Creating application user and directory"
if ! id "${APP_USER}" >/dev/null 2>&1; then
    useradd --system --create-home --user-group --shell /bin/bash --comment "GardenHouse app" "${APP_USER}"
    echo "Created system user '${APP_USER}'"
else
    echo "User '${APP_USER}' already exists"
fi
# Ensure the matching group exists and is the user's primary group.
# Some pre-existing system users have "nogroup" as their primary group,
# which makes `chown user:user` fail with "invalid group".
if ! getent group "${APP_USER}" >/dev/null 2>&1; then
    groupadd --system "${APP_USER}"
    echo "Created system group '${APP_USER}'"
fi
usermod -g "${APP_USER}" "${APP_USER}" >/dev/null 2>&1 || true
mkdir -p "${APP_DIR}"
chown -R "${APP_USER}":"${APP_USER}" "${APP_DIR}"

echo "==> [5/6] Configuring firewall (allow 22, 80, 443)"
ufw allow OpenSSH
ufw allow "Nginx Full"
ufw --force enable

echo "==> [6/6] Enabling nginx + starting PostgreSQL"
systemctl enable nginx
systemctl restart nginx
systemctl enable postgresql
systemctl restart postgresql

echo ""
echo "=== Setup complete ==="
echo "  App directory : ${APP_DIR}"
echo "  App user      : ${APP_USER}"
echo ""
echo "Next steps:"
echo "  1. Verify DNS: A record ${DOMAIN} -> ${SERVER_IP}"
echo "  2. Run create_db.sh   (creates PostgreSQL role + database)"
echo "  3. Run deploy.sh      (clone code, install deps, build, start services)"
echo "  4. Run setup_ssl.sh   (Let's Encrypt certificate for ${DOMAIN})"