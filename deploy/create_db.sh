#!/usr/bin/env bash
#
# create_db.sh — creates the PostgreSQL role + database for GardenHouse
# =====================================================================
# Run as root (or with sudo). Idempotent — safe to re-run.
#
# Usage:
#   sudo bash create_db.sh
#
# The generated DB password is written into:
#   /var/www/gardenhouse/backend/.env  (DB_PASSWORD=...)
# If backend/.env already exists, only an absent DB_PASSWORD is filled in —
# existing secrets are never overwritten.

set -euo pipefail

# These scripts must run as root: they create PostgreSQL roles/databases
# (via `sudo -u postgres`) and chown the app directory.
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root (or with full sudo):"
    echo "  sudo bash $0"
    exit 1
fi

APP_DIR="/var/www/gardenhouse"
DB_NAME="gardenhouse_db"
DB_USER="gardenhouse_user"
ENV_FILE="${APP_DIR}/backend/.env"

echo "==> Ensuring app directory exists"
mkdir -p "${APP_DIR}"
mkdir -p "${APP_DIR}/backend"

echo "==> Checking for existing DB password"
if [ -f "${ENV_FILE}" ] && grep -q "^DB_PASSWORD=." "${ENV_FILE}" && ! grep -q "^DB_PASSWORD=change-me-generated-by-deploy-script" "${ENV_FILE}"; then
    DB_PASSWORD="$(grep "^DB_PASSWORD=" "${ENV_FILE}" | head -n1 | cut -d'=' -f2-)"
    echo "Using existing DB_PASSWORD from ${ENV_FILE}"
else
    DB_PASSWORD="$(openssl rand -hex 24)"
    echo "Generated a new random DB password"
fi

echo "==> Creating PostgreSQL role '${DB_USER}' (if missing)"
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';"
    echo "  Role created"
else
    # Update password to keep it in sync with what we store in .env
    sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';"
    echo "  Role already exists — password re-synced"
fi

echo "==> Creating database '${DB_NAME}' (if missing)"
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
    echo "  Database created"
else
    echo "  Database already exists"
fi

echo "==> Granting privileges"
sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

echo "==> Ensuring app user group exists"
APP_USER="maintest"
if ! getent group "${APP_USER}" >/dev/null 2>&1; then
    groupadd --system "${APP_USER}"
    echo "  Created system group '${APP_USER}'"
fi
usermod -g "${APP_USER}" "${APP_USER}" >/dev/null 2>&1 || true

echo "==> Writing DB_PASSWORD into ${ENV_FILE}"
touch "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

if grep -q "^DB_PASSWORD=" "${ENV_FILE}"; then
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" "${ENV_FILE}"
else
    printf '\n# --- Database (managed by create_db.sh) ---\nDB_PASSWORD=%s\n' "${DB_PASSWORD}" >> "${ENV_FILE}"
fi
chown -R maintest:maintest "${APP_DIR}"

echo ""
echo "=== Database ready ==="
echo "  Name      : ${DB_NAME}"
echo "  User      : ${DB_USER}"
echo "  Password  : stored in ${ENV_FILE}"
echo "  Host/Port : localhost:5432 (default PostgreSQL)"
echo ""
echo "Next: run deploy.sh"