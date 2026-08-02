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

APP_NAME="gardenhouse"
APP_USER="gardenhouse"
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

# Ensure the PostgreSQL role exists and the password stored in .env is real
# (not a placeholder) and in sync with the role.
ROLE_EXISTS="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER_EXPECTED}'" 2>/dev/null | tr -d ' ' || echo '')"
if [ "${ROLE_EXISTS}" != "1" ]; then
    echo "  ERROR: PostgreSQL role '${DB_USER_EXPECTED}' does not exist."
    echo "  Run create_db.sh first (it creates the role and the database)."
    exit 1
fi

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
# Prefer a clean install, but fall back to `npm install` if the lockfile
# is out of sync with package.json — the deploy shouldn't be blocked by that.
sudo -u "${APP_USER}" bash -c "cd ${APP_DIR}/frontend && (npm ci || npm install)"

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

echo "==> [9/9] Installing systemd units + nginx config"
cp "${APP_DIR}/deploy/systemd/gardenhouse-backend.service" /etc/systemd/system/
cp "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable gardenhouse-backend.service
systemctl enable gardenhouse-frontend.service
systemctl restart gardenhouse-backend.service
systemctl restart gardenhouse-frontend.service

cp "${APP_DIR}/deploy/nginx/maintest.site.conf" /etc/nginx/sites-available/maintest.site.conf
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
echo "  Backend  : http://127.0.0.1:8001  (systemd: gardenhouse-backend)"
echo "  Frontend : http://127.0.0.1:3000  (systemd: gardenhouse-frontend)"
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