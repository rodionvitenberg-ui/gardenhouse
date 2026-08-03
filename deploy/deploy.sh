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
# Guard rails: production MUST serve under /gardenhouse (next-intl locales on top).
# Re-assert critical keys without wiping custom overrides the operator may have added.
ensure_env_key() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "${file}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${file}"
    fi
}
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_BASE_PATH" "/gardenhouse"
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_SITE_URL" "https://${DOMAIN}/gardenhouse"
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_API_URL" "/gardenhouse/api"
ensure_env_key "${FRONTEND_ENV}" "API_URL" "http://127.0.0.1:8000/api"
echo "  Ensured basePath=/gardenhouse and API paths in ${FRONTEND_ENV}"
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

echo "==> [7b/9] Preparing Next.js standalone runtime"
# output: "standalone" does not bundle public/ or .next/static — copy them in.
# Without this, CSS/JS/images 404 and the app looks "not working".
STANDALONE_DIR="${APP_DIR}/frontend/.next/standalone"
# Monorepo layouts sometimes nest as standalone/frontend/ — detect server.js.
if [ ! -f "${STANDALONE_DIR}/server.js" ] && [ -f "${STANDALONE_DIR}/frontend/server.js" ]; then
    STANDALONE_DIR="${STANDALONE_DIR}/frontend"
fi
if [ ! -f "${STANDALONE_DIR}/server.js" ]; then
    echo "ERROR: standalone server.js not found under ${APP_DIR}/frontend/.next/standalone"
    echo "  Find it: find ${APP_DIR}/frontend/.next/standalone -name server.js"
    exit 1
fi
mkdir -p "${STANDALONE_DIR}/.next"
# static assets
rm -rf "${STANDALONE_DIR}/.next/static"
cp -a "${APP_DIR}/frontend/.next/static" "${STANDALONE_DIR}/.next/static"
# public/ (videos, logos, fonts)
rm -rf "${STANDALONE_DIR}/public"
cp -a "${APP_DIR}/frontend/public" "${STANDALONE_DIR}/public"
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}/frontend/.next"
echo "  Standalone ready: ${STANDALONE_DIR}/server.js"
# Persist path for the systemd unit if nested
if [ "${STANDALONE_DIR}" != "${APP_DIR}/frontend/.next/standalone" ]; then
    echo "  NOTE: server.js is nested at ${STANDALONE_DIR}"
    # Rewrite unit paths at install time below via sed if needed
fi
export STANDALONE_DIR

echo "==> [8/9] Django: migrations, collectstatic, seed"
sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" migrate --noinput \
    --settings=core.settings

sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" collectstatic --noinput \
    --settings=core.settings

# Seeds are idempotent-ish; never fail the whole deploy on re-seed.
sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_data --settings=core.settings \
    || echo "  WARNING: seed_data failed (ok if data already present)"

sudo -u "${APP_USER}" env \
    PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_journal --settings=core.settings \
    || echo "  WARNING: seed_journal failed (ok if data already present)"

echo "==> [9/9] Installing systemd (backend + frontend) + nginx config"
# Stop leftover PM2 / orphan next (older deploys used PM2).
if command -v pm2 >/dev/null 2>&1; then
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" \
        pm2 delete gardenhouse-frontend >/dev/null 2>&1 || true
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" \
        pm2 save --force >/dev/null 2>&1 || true
fi
pkill -f "next start" >/dev/null 2>&1 || true
pkill -f "node_modules/next/dist/bin/next" >/dev/null 2>&1 || true
sleep 1

STANDALONE_DIR="${STANDALONE_DIR:-${APP_DIR}/frontend/.next/standalone}"
if [ ! -f "${STANDALONE_DIR}/server.js" ] && [ -f "${APP_DIR}/frontend/.next/standalone/frontend/server.js" ]; then
    STANDALONE_DIR="${APP_DIR}/frontend/.next/standalone/frontend"
fi
if [ ! -f "${STANDALONE_DIR}/server.js" ]; then
    echo "ERROR: ${STANDALONE_DIR}/server.js missing — build/prepare step failed"
    exit 1
fi

cp "${APP_DIR}/deploy/systemd/gardenhouse-backend.service" /etc/systemd/system/
cp "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service" /etc/systemd/system/
# If standalone server.js is nested, fix WorkingDirectory/ExecStart in the unit.
if [ "${STANDALONE_DIR}" != "${APP_DIR}/frontend/.next/standalone" ]; then
    sed -i "s|/var/www/gardenhouse/frontend/.next/standalone|${STANDALONE_DIR}|g" \
        /etc/systemd/system/gardenhouse-frontend.service
fi
systemctl daemon-reload
systemctl enable gardenhouse-backend.service gardenhouse-frontend.service
systemctl restart gardenhouse-backend.service
systemctl restart gardenhouse-frontend.service

# Prefer systemd; if operator insists on PM2, ecosystem is also standalone-aware.
if command -v pm2 >/dev/null 2>&1; then
    # Keep PM2 clean so it does not fight systemd for :3000
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 delete gardenhouse-frontend >/dev/null 2>&1 || true
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 delete gardenhouse-front >/dev/null 2>&1 || true
fi

# Fail the deploy if services did not come up.
sleep 2
if ! systemctl is-active --quiet gardenhouse-backend.service; then
    echo "ERROR: gardenhouse-backend failed to start"
    systemctl status gardenhouse-backend --no-pager -l || true
    journalctl -u gardenhouse-backend -n 40 --no-pager || true
    exit 1
fi
if ! systemctl is-active --quiet gardenhouse-frontend.service; then
    echo "ERROR: gardenhouse-frontend failed to start"
    systemctl status gardenhouse-frontend --no-pager -l || true
    journalctl -u gardenhouse-frontend -n 40 --no-pager || true
    exit 1
fi
echo "  Backend  : active (systemd)"
echo "  Frontend : active (systemd, standalone server.js)"
echo "  Probe    : $(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3000/gardenhouse/ru || echo ERR)"

# Copy the nginx config from the repo — UNLESS the live one was already
# modified by Certbot. Overwriting it would strip the `listen 443 ssl` block
# and certificate paths that `certbot --nginx` injected, breaking HTTPS.
if [ -f /etc/nginx/sites-available/maintest.site.conf ] \
   && grep -q "managed by Certbot" /etc/nginx/sites-available/maintest.site.conf; then
    echo "  /etc/nginx/sites-available/maintest.site.conf already managed by Certbot — leaving HTTPS block intact"
    # Ensure the root redirect AND the raw-static-assets redirect exist in the
    # live config (idempotent). Insert them BEFORE `listen 443 ssl;` so they
    # land inside the HTTPS server block — appending to the end of the file
    # would place them outside any server block and break `nginx -t`.
    if ! grep -q "location = /" /etc/nginx/sites-available/maintest.site.conf; then
        sed -i '/listen 443 ssl;/i \    # Domain root -> the app\n    location = / {\n        return 301 /gardenhouse;\n    }' /etc/nginx/sites-available/maintest.site.conf
    fi
    if ! grep -q "location ~\* \^/\(?!gardenhouse" /etc/nginx/sites-available/maintest.site.conf; then
        sed -i '/listen 443 ssl;/i \    # Raw static assets requested WITHOUT the /gardenhouse prefix (see template for details)\n    location ~* ^/(?!gardenhouse|api|admin|static|media|_next|\.well-known)([^/]+\\.(?:jpg|jpeg|png|gif|webp|svg|mp4|webm|mov|woff2?|ttf|otf|ico|avif|pdf))$ {\n        return 301 /gardenhouse/$1;\n    }' /etc/nginx/sites-available/maintest.site.conf
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
echo "  Frontend : http://127.0.0.1:3000  (systemd: gardenhouse-frontend)"
echo "  Public   : http://${DOMAIN}/gardenhouse     (→ /gardenhouse/ru)"
echo "  English  : http://${DOMAIN}/gardenhouse/en"
echo "  API      : http://${DOMAIN}/gardenhouse/api/"
echo "  Admin    : http://${DOMAIN}/gardenhouse/admin/"
echo ""
echo "Smoke checks (on the server):"
echo "  systemctl status gardenhouse-backend gardenhouse-frontend --no-pager"
echo "  curl -I http://127.0.0.1:3000/gardenhouse/ru"
echo "  curl    http://127.0.0.1:8000/api/products/"
echo "  curl -I http://${DOMAIN}/gardenhouse/ru"
echo ""
echo "Next:"
echo "  1. Ensure DNS A record: ${DOMAIN} -> ${SERVER_IP}"
echo "  2. If needed, create a superuser:"
echo "       sudo -u ${APP_USER} ${PYTHON_BIN} ${APP_DIR}/backend/manage.py createsuperuser"
echo "  3. Issue SSL (first deploy only, after DNS works):"
echo "       sudo bash ${APP_DIR}/deploy/setup_ssl.sh"
echo "  4. Sync local media if needed:"
echo "       rsync -av backend/media/ ${APP_USER}@${SERVER_IP}:${APP_DIR}/backend/media/"