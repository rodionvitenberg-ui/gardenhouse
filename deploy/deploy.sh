#!/usr/bin/env bash
#
# deploy.sh — full deployment of GardenHouse
# ===========================================
# Run as root (or with sudo). Assumes setup_server.sh and create_db.sh
# were already run:
#   sudo bash setup_server.sh
#   sudo bash create_db.sh
#
# What it does:
#   1. Clones/pulls the code into /var/www/gardenhouse
#   2. Creates backend/.env from the production template (generating a
#      one-time Django SECRET_KEY; never overwrites existing secrets)
#   3. Creates frontend/.env.production from the template
#   4. Installs Python deps + Node deps, runs migrations, collectstatic,
#      seeds the database
#   5. Installs systemd units and the nginx config, restarts services
#
# Usage:
#   sudo bash deploy.sh
#
# The repo is PUBLIC/private via HTTPS — if it's a private repo, clone it
# manually first (as the gardenhouse user) and re-run this script.

set -euo pipefail

# These scripts must run as root: they configure systemd units and nginx,
# create the app user, and use `sudo -u` internally.
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root (or with full sudo):"
    echo "  sudo bash $0"
    exit 1
fi

APP_NAME="gardenhouse"
APP_USER="maintest"
APP_DIR="/var/www/${APP_NAME}"
REPO_URL="https://github.com/rodionvitenberg-ui/gardenhouse.git"
REPO_BRANCH="main"

PYTHON_BIN="${APP_DIR}/backend/venv/bin/python"
PIP_BIN="${APP_DIR}/backend/venv/bin/pip"
GUNICORN_BIN="${APP_DIR}/backend/venv/bin/gunicorn"

DOMAIN="maintest.site"
SERVER_IP="193.181.216.124"

echo "==> [1/9] Ensuring app user and directory exist"
if ! id "${APP_USER}" >/dev/null 2>&1; then
    echo "  ERROR: user '${APP_USER}' does not exist."
    echo "  Run setup_server.sh first."
    exit 1
fi
# Ensure the matching group exists and is the user's primary group, so that
# `chown user:user` doesn't fail with "invalid group" for pre-existing
# system users whose primary group is nogroup.
if ! getent group "${APP_USER}" >/dev/null 2>&1; then
    groupadd --system "${APP_USER}"
    echo "  Created system group '${APP_USER}'"
fi
usermod -g "${APP_USER}" "${APP_USER}" >/dev/null 2>&1 || true
mkdir -p "${APP_DIR}"
chown -R "${APP_USER}":"${APP_USER}" "${APP_DIR}"

echo "==> [2/9] Cloning / updating code"
if [ ! -d "${APP_DIR}/.git" ]; then
    git clone "${REPO_URL}" "${APP_DIR}"
    chown -R "${APP_USER}":"${APP_USER}" "${APP_DIR}"
else
    sudo -u "${APP_USER}" git -C "${APP_DIR}" fetch origin
    sudo -u "${APP_USER}" git -C "${APP_DIR}" checkout "${REPO_BRANCH}"
    sudo -u "${APP_USER}" git -C "${APP_DIR}" pull --ff-only origin "${REPO_BRANCH}"
fi

echo "==> [3/9] Ensuring backend/.env is the production config"
BACKEND_ENV="${APP_DIR}/backend/.env"
DB_USER_EXPECTED="gardenhouse_user"
DB_NAME_EXPECTED="gardenhouse_db"

# Recreate .env from the template when it is missing or still holds dev
# credentials (e.g. a local .env copied to the server with garden_user).
NEED_RECREATE=0
if [ ! -f "${BACKEND_ENV}" ]; then
    NEED_RECREATE=1
elif ! grep -q "^DB_USER=${DB_USER_EXPECTED}$" "${BACKEND_ENV}" \
     || ! grep -q "^DB_NAME=${DB_NAME_EXPECTED}$" "${BACKEND_ENV}"; then
    NEED_RECREATE=1
fi

if [ "${NEED_RECREATE}" = "1" ]; then
    cp "${APP_DIR}/backend/.env.production.example" "${BACKEND_ENV}"
    SECRET_KEY="$(openssl rand -hex 48)"
    # Replace the placeholder secret with a real generated one
    sed -i "s|^DJANGO_SECRET_KEY=.*|DJANGO_SECRET_KEY=${SECRET_KEY}|" "${BACKEND_ENV}"
    echo "  Recreated ${BACKEND_ENV} from the production template with a fresh SECRET_KEY"
else
    echo "  ${BACKEND_ENV} already has the production DB credentials — left untouched"
fi
chmod 600 "${BACKEND_ENV}"
chown "${APP_USER}":"${APP_USER}" "${BACKEND_ENV}"

# Ensure the SSL redirect flag is present (False behind nginx) even when the
# .env already existed — Django would otherwise redirect in an endless loop.
if ! grep -q "^DJANGO_SECURE_SSL_REDIRECT=" "${BACKEND_ENV}"; then
    printf 'DJANGO_SECURE_SSL_REDIRECT=False\n' >> "${BACKEND_ENV}"
    chown "${APP_USER}":"${APP_USER}" "${BACKEND_ENV}"
    echo "  Added DJANGO_SECURE_SSL_REDIRECT=False to ${BACKEND_ENV}"
fi

# Ensure the PostgreSQL role exists and the password stored in .env is real
DB_PASSWORD="$(grep "^DB_PASSWORD=" "${BACKEND_ENV}" | head -n1 | cut -d'=' -f2- || true)"
if [ -z "${DB_PASSWORD}" ] || [ "${DB_PASSWORD}" = "change-me-generated-by-deploy-script" ]; then
    DB_PASSWORD="$(openssl rand -hex 24)"
    sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "ALTER ROLE ${DB_USER_EXPECTED} WITH LOGIN PASSWORD '${DB_PASSWORD}';" >/dev/null
    if grep -q "^DB_PASSWORD=" "${BACKEND_ENV}"; then
        sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" "${BACKEND_ENV}"
    else
        printf '\nDB_PASSWORD=%s\n' "${DB_PASSWORD}" >> "${BACKEND_ENV}"
    fi
    chown "${APP_USER}":"${APP_USER}" "${BACKEND_ENV}"
    echo "  Generated a fresh DB password, synced to PostgreSQL and ${BACKEND_ENV}"
else
    # Existing password — keep the PostgreSQL role in sync with it.
    sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "ALTER ROLE ${DB_USER_EXPECTED} WITH LOGIN PASSWORD '${DB_PASSWORD}';" >/dev/null
    echo "  DB password already set — PostgreSQL role re-synced"
fi

echo "==> [4/9] Creating frontend/.env.production"
FRONTEND_ENV="${APP_DIR}/frontend/.env.production"
if [ ! -f "${FRONTEND_ENV}" ]; then
    cp "${APP_DIR}/frontend/.env.production.example" "${FRONTEND_ENV}"
    echo "  Created ${FRONTEND_ENV}"
else
    echo "  ${FRONTEND_ENV} already exists — leaving it untouched"
fi
chown "${APP_USER}":"${APP_USER}" "${FRONTEND_ENV}"

echo "==> [5/9] Installing backend dependencies"
sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/backend/venv"
sudo -u "${APP_USER}" "${PIP_BIN}" install --upgrade pip
sudo -u "${APP_USER}" "${PIP_BIN}" install -r "${APP_DIR}/backend/requirements.txt"

echo "==> [6/9] Installing frontend dependencies"
# Use `npm install` (NOT `npm ci`): on small-RAM VPS boxes `npm ci` can be
# killed by the OOM killer while unpacking, whereas `npm install` reuses the
# existing node_modules and needs far less memory. The lockfile still governs
# dependency versions unless package.json changed.
sudo -u "${APP_USER}" bash -c "cd ${APP_DIR}/frontend && npm install"

echo "==> [7/9] Building frontend"
# Next.js reads .env.production automatically during build.
sudo -u "${APP_USER}" env \
    NODE_ENV=production \
    bash -c "cd ${APP_DIR}/frontend && npm run build"

echo "==> [8/9] Django: migrations, collectstatic, seed"
sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" migrate --noinput \
    --settings=core.settings

sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" collectstatic --noinput \
    --settings=core.settings

sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_data --settings=core.settings

sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_journal --settings=core.settings

echo "==> [9/9] Installing systemd (backend) + PM2 (frontend) + nginx config"
# Backend runs under systemd (Gunicorn).
cp "${APP_DIR}/deploy/systemd/gardenhouse-backend.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable gardenhouse-backend.service
systemctl restart gardenhouse-backend.service

# Frontend runs under PM2.
# 1) Fully stop and disable the old systemd unit (if any). Merely removing
#    the unit file leaves a running `next start` process holding port 3000.
if systemctl list-unit-files | grep -q '^gardenhouse-frontend.service'; then
    systemctl disable --now gardenhouse-frontend.service >/dev/null 2>&1 || true
fi
rm -f /etc/systemd/system/gardenhouse-frontend.service
systemctl daemon-reload
# 2) Kill ANY orphaned `next start` process (e.g. started manually or by the
#    old systemd unit before it was disabled). Without this, PM2 fails with
#    EADDRINUSE and crash-loops forever.
pkill -f "next start" >/dev/null 2>&1 || true
sleep 1
sudo -u "${APP_USER}" env \
    PM2_HOME="/home/${APP_USER}/.pm2" \
    pm2 startOrReload "${APP_DIR}/deploy/pm2/ecosystem.config.cjs" --update-env
sudo -u "${APP_USER}" env \
    PM2_HOME="/home/${APP_USER}/.pm2" \
    pm2 save
# Auto-start PM2 on boot for the app user (idempotent: the `startup` command
# creates a systemd unit named pm2-<user>.service).
sudo -u "${APP_USER}" env \
    PM2_HOME="/home/${APP_USER}/.pm2" \
    pm2 startup systemd -u "${APP_USER}" --hp "/home/${APP_USER}" >/dev/null 2>&1 || true

# Copy the nginx config from the repo — UNLESS the live one was already
# modified by Certbot. Overwriting it would strip the `listen 443 ssl` block
# and certificate paths that `certbot --nginx` injected, breaking HTTPS.
if [ -f /etc/nginx/sites-available/maintest.site.conf ] \
   && grep -q "managed by Certbot" /etc/nginx/sites-available/maintest.site.conf; then
    echo "  /etc/nginx/sites-available/maintest.site.conf already managed by Certbot — leaving HTTPS block intact"
    # Still ensure the root redirect exists in the live config (idempotent).
    # Insert it BEFORE `listen 443 ssl;` so it lands inside the HTTPS server
    # block — appending to the end of the file would place it outside any
    # server block and break `nginx -t`.
    if ! grep -q "location = /" /etc/nginx/sites-available/maintest.site.conf; then
        sed -i '/listen 443 ssl;/i \    # Domain root -> the app\n    location = / {\n        return 301 /gardenhouse;\n    }' /etc/nginx/sites-available/maintest.site.conf
    fi
else
    cp "${APP_DIR}/deploy/nginx/maintest.site.conf" /etc/nginx/sites-available/maintest.site.conf
fi
# Remove ANY conflicting site config (the Ubuntu default site, or any config
# that already claims our domain). Otherwise nginx may route requests to an
# older server block and serve 404s from the wrong root.
for f in /etc/nginx/sites-enabled/*; do
    [ -e "$f" ] || continue
    if [ "$(basename "$f")" = "default" ] || grep -q "maintest.site" "$f" 2>/dev/null; then
        rm -f "$f"
        echo "  Removed conflicting nginx site: $f"
    fi
done
ln -sf /etc/nginx/sites-available/maintest.site.conf /etc/nginx/sites-enabled/maintest.site.conf
mkdir -p /var/www/certbot
nginx -t
systemctl reload nginx

echo ""
echo "=== Deploy complete ==="
echo "  Backend  : http://127.0.0.1:8000  (systemd: gardenhouse-backend)"
echo "  Frontend : http://127.0.0.1:3000  (pm2: gardenhouse-frontend)"
echo "  Public   : http://${DOMAIN}/gardenhouse"
echo ""
echo "Next:"
echo "  1. Ensure DNS A record: ${DOMAIN} -> ${SERVER_IP}"
echo "  2. If needed, create a superuser:"
echo "       sudo -u ${APP_USER} ${PYTHON_BIN} ${APP_DIR}/backend/manage.py createsuperuser"
echo "  3. Issue SSL: sudo bash ${APP_DIR}/deploy/setup_ssl.sh"
echo "     (only after DNS resolves and port 80 is reachable)"
echo "  4. If any media files exist locally (backend/media), sync them:"
echo "       rsync -av backend/media/ ${APP_USER}@${SERVER_IP}:${APP_DIR}/backend/media/"