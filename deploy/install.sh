#!/usr/bin/env bash
#
# install.sh — FULL first-time install on a clean Ubuntu (Webdock-ready)
# ======================================================================
#
# Designed for Webdock where:
#   - login user is often `maintest`
#   - primary group is often `sudo` (NOT `maintest`) — we never invent a group
#   - OS is reinstalled clean; no leftover PM2/systemd assumed
#
# Usage (on the server, after cloning OR from this repo):
#
#   sudo bash deploy/install.sh
#   sudo bash deploy/install.sh --skip-ufw          # if Webdock panel firewall is enough
#   sudo bash deploy/install.sh --with-ssl          # also run certbot (DNS must work)
#   sudo APP_USER=maintest bash deploy/install.sh
#
# What it does:
#   1. Packages (nginx, postgres, python, certbot, build tools)
#   2. Node.js 22
#   3. App directory /var/www/gardenhouse + code
#   4. PostgreSQL role + database
#   5. Backend venv, .env, migrate, collectstatic, seed
#   6. Frontend .env.production, npm install, next build (basePath=/gardenhouse)
#   7. systemd units (User=maintest Group=<real primary group>)
#   8. nginx site for /gardenhouse
#   9. Smoke tests — fails if frontend/API do not respond
#
# Later updates:  sudo bash deploy/deploy.sh
# SSL only:       sudo bash deploy/setup_ssl.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

SKIP_UFW=false
WITH_SSL=false
SKIP_SEED=false
for arg in "$@"; do
    case "${arg}" in
        --skip-ufw)   SKIP_UFW=true ;;
        --with-ssl)   WITH_SSL=true ;;
        --skip-seed)  SKIP_SEED=true ;;
        -h|--help)
            sed -n '2,35p' "$0"
            exit 0
            ;;
        *)
            die "unknown argument: ${arg}"
            ;;
    esac
done

require_root
resolve_app_identity

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
log "[1/10] System packages"
# ---------------------------------------------------------------------------
apt-get update -y
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
    rsync \
    ufw

ok "apt packages installed"

# ---------------------------------------------------------------------------
log "[2/10] Node.js 22"
# ---------------------------------------------------------------------------
if ! command_exists node || ! node --version 2>/dev/null | grep -qE '^v22\.'; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi
ok "Node $(node --version)  npm $(npm --version)"

# ---------------------------------------------------------------------------
log "[3/10] Firewall (optional)"
# ---------------------------------------------------------------------------
if [ "${SKIP_UFW}" = true ]; then
    warn "UFW skipped (--skip-ufw). Open TCP 80/443 in Webdock panel if needed."
else
    # Never lock ourselves out: SSH first, then nginx, then enable.
    ufw allow OpenSSH >/dev/null 2>&1 || true
    ufw allow "Nginx Full" >/dev/null 2>&1 || true
    # Only enable if not already active — non-interactive
    if ! ufw status 2>/dev/null | grep -qi "Status: active"; then
        ufw --force enable >/dev/null 2>&1 || warn "ufw enable failed (ok if hoster firewall is used)"
    fi
    ufw status verbose | head -20 || true
fi

# ---------------------------------------------------------------------------
log "[4/10] Application directory + code"
# ---------------------------------------------------------------------------
THIS_REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"
ensure_app_dir

if [ -d "${APP_DIR}/.git" ]; then
    log "Updating existing git repo at ${APP_DIR}"
    # Preserve local .env files during pull
    sudo -u "${APP_USER}" git -C "${APP_DIR}" fetch origin || true
    sudo -u "${APP_USER}" git -C "${APP_DIR}" checkout "${REPO_BRANCH}" || true
    sudo -u "${APP_USER}" git -C "${APP_DIR}" pull --ff-only origin "${REPO_BRANCH}" \
        || warn "git pull failed — using code already on disk"
elif [ "${THIS_REPO}" = "${APP_DIR}" ]; then
    ok "Running from ${APP_DIR} (already the app dir)"
elif [ -f "${THIS_REPO}/frontend/package.json" ] && [ -f "${THIS_REPO}/backend/manage.py" ]; then
    log "Syncing code from ${THIS_REPO} → ${APP_DIR}"
    rsync -a \
        --exclude '.git' \
        --exclude 'backend/venv' \
        --exclude 'frontend/node_modules' \
        --exclude 'frontend/.next' \
        --exclude 'backend/__pycache__' \
        --exclude '**/__pycache__' \
        --exclude 'backend/db.sqlite3' \
        "${THIS_REPO}/" "${APP_DIR}/"
    # Keep a .git if we can clone for future updates
    if [ ! -d "${APP_DIR}/.git" ]; then
        if git -C "${THIS_REPO}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            # Prefer real clone for future deploy.sh pulls
            if [ -n "${REPO_URL}" ]; then
                rm -rf "${APP_DIR}.gittmp" 2>/dev/null || true
                if git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${APP_DIR}.gittmp" 2>/dev/null; then
                    mv "${APP_DIR}.gittmp/.git" "${APP_DIR}/.git"
                    rm -rf "${APP_DIR}.gittmp"
                    ok "attached .git from ${REPO_URL}"
                else
                    warn "could not clone ${REPO_URL} — updates via deploy.sh may need manual copy"
                fi
            fi
        fi
    fi
else
    log "Cloning ${REPO_URL} → ${APP_DIR}"
    # empty dir or incomplete
    if [ -z "$(ls -A "${APP_DIR}" 2>/dev/null || true)" ]; then
        git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${APP_DIR}"
    else
        die "${APP_DIR} is not empty and is not a git repo. Clear it or place the project there."
    fi
fi

app_chown "${APP_DIR}"
ok "code ready at ${APP_DIR}"

# ---------------------------------------------------------------------------
log "[5/10] PostgreSQL database"
# ---------------------------------------------------------------------------
systemctl enable postgresql
systemctl start postgresql

# Generate or reuse DB password
BACKEND_ENV="${APP_DIR}/backend/.env"
mkdir -p "${APP_DIR}/backend"
DB_PASSWORD=""
if [ -f "${BACKEND_ENV}" ]; then
    DB_PASSWORD="$(read_env_key "${BACKEND_ENV}" DB_PASSWORD)"
fi
if [ -z "${DB_PASSWORD}" ] || [ "${DB_PASSWORD}" = "change-me-generated-by-deploy-script" ] || [ "${DB_PASSWORD}" = "change-me" ]; then
    DB_PASSWORD="$(openssl rand -hex 24)"
    ok "generated new DB password"
else
    ok "reusing DB password from existing backend/.env"
fi

# Create role + DB (idempotent)
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';
  ELSE
    ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;
SQL

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
    ok "database ${DB_NAME} created"
else
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};" || true
    ok "database ${DB_NAME} already exists"
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" <<SQL
GRANT ALL ON SCHEMA public TO ${DB_USER};
ALTER SCHEMA public OWNER TO ${DB_USER};
SQL
ok "PostgreSQL role ${DB_USER} + DB ${DB_NAME} ready"

# ---------------------------------------------------------------------------
log "[6/10] Backend .env + Python venv"
# ---------------------------------------------------------------------------
if [ ! -f "${BACKEND_ENV}" ]; then
    cp "${APP_DIR}/backend/.env.production.example" "${BACKEND_ENV}"
fi

SECRET_KEY="$(read_env_key "${BACKEND_ENV}" DJANGO_SECRET_KEY)"
if [ -z "${SECRET_KEY}" ] || [[ "${SECRET_KEY}" == change-me* ]]; then
    SECRET_KEY="$(openssl rand -hex 48)"
fi

ensure_env_key "${BACKEND_ENV}" "DJANGO_SECRET_KEY" "${SECRET_KEY}"
ensure_env_key "${BACKEND_ENV}" "DJANGO_DEBUG" "False"
ensure_env_key "${BACKEND_ENV}" "DJANGO_SECURE_SSL_REDIRECT" "False"
ensure_env_key "${BACKEND_ENV}" "DJANGO_ALLOWED_HOSTS" "${DOMAIN},www.${DOMAIN},${SERVER_IP},127.0.0.1,localhost"
ensure_env_key "${BACKEND_ENV}" "DJANGO_FORCE_SCRIPT_NAME" "/gardenhouse"
ensure_env_key "${BACKEND_ENV}" "DJANGO_CSRF_TRUSTED_ORIGINS" "https://${DOMAIN},http://${DOMAIN}"
ensure_env_key "${BACKEND_ENV}" "DB_NAME" "${DB_NAME}"
ensure_env_key "${BACKEND_ENV}" "DB_USER" "${DB_USER}"
ensure_env_key "${BACKEND_ENV}" "DB_PASSWORD" "${DB_PASSWORD}"
ensure_env_key "${BACKEND_ENV}" "DB_HOST" "localhost"
ensure_env_key "${BACKEND_ENV}" "DB_PORT" "5432"
ensure_env_key "${BACKEND_ENV}" "CORS_ALLOWED_ORIGINS" "https://${DOMAIN},http://${DOMAIN}"
chmod 600 "${BACKEND_ENV}"
app_chown "${BACKEND_ENV}"
ok "backend/.env written"

sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/backend/venv"
sudo -u "${APP_USER}" "${APP_DIR}/backend/venv/bin/pip" install --upgrade pip
sudo -u "${APP_USER}" "${APP_DIR}/backend/venv/bin/pip" install -r "${APP_DIR}/backend/requirements.txt"
ok "Python venv + requirements"

PYTHON_BIN="${APP_DIR}/backend/venv/bin/python"
sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" migrate --noinput
sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" collectstatic --noinput

mkdir -p "${APP_DIR}/backend/media" "${APP_DIR}/backend/staticfiles"
app_chown "${APP_DIR}/backend/media"
app_chown "${APP_DIR}/backend/staticfiles"

if [ "${SKIP_SEED}" != true ]; then
    sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
        "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_data \
        || warn "seed_data failed (non-fatal)"
    sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
        "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_journal \
        || warn "seed_journal failed (non-fatal)"
fi
ok "Django migrated + collectstatic"

# ---------------------------------------------------------------------------
log "[7/10] Frontend .env.production + build"
# ---------------------------------------------------------------------------
FRONTEND_ENV="${APP_DIR}/frontend/.env.production"
if [ ! -f "${FRONTEND_ENV}" ]; then
    cp "${APP_DIR}/frontend/.env.production.example" "${FRONTEND_ENV}"
fi
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_SITE_URL" "https://${DOMAIN}/gardenhouse"
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_BASE_PATH" "/gardenhouse"
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_API_URL" "/gardenhouse/api"
ensure_env_key "${FRONTEND_ENV}" "API_URL" "http://127.0.0.1:8000/api"
app_chown "${FRONTEND_ENV}"
ok "frontend/.env.production (basePath=/gardenhouse)"

# Guard: refuse real standalone output in next.config (hangs on Next 16).
# Match only a code line, not comments like: // never use output standalone
has_standalone_output() {
    local f
    for f in \
        "${APP_DIR}/frontend/next.config.ts" \
        "${APP_DIR}/frontend/next.config.js" \
        "${APP_DIR}/frontend/next.config.mjs"
    do
        [ -f "${f}" ] || continue
        # Strip // line comments, then look for assignment at start of a line
        if sed 's|//.*||g' "${f}" | grep -qE '^[[:space:]]*output:[[:space:]]*["'\'']standalone["'\'']'; then
            return 0
        fi
    done
    return 1
}
if has_standalone_output; then
    die "frontend next.config still has output:\"standalone\".
  Remove that config key — this project uses \`next start\`, not standalone server.js."
fi

# npm install (not ci — OOM-safe on small VPS)
sudo -u "${APP_USER}" bash -c "cd ${APP_DIR}/frontend && npm install"
sudo -u "${APP_USER}" env NODE_ENV=production bash -c "cd ${APP_DIR}/frontend && npm run build"

if [ ! -d "${APP_DIR}/frontend/.next" ]; then
    die "next build did not produce ${APP_DIR}/frontend/.next"
fi
# Verify basePath baked in
if [ -f "${APP_DIR}/frontend/.next/required-server-files.json" ]; then
    if ! grep -q '"basePath": "/gardenhouse"' "${APP_DIR}/frontend/.next/required-server-files.json" 2>/dev/null; then
        warn "basePath /gardenhouse not found in build metadata — check .env.production and rebuild"
    else
        ok "build has basePath=/gardenhouse"
    fi
fi
ok "Next.js built"

# ---------------------------------------------------------------------------
log "[8/10] systemd services"
# ---------------------------------------------------------------------------
# Kill anything that might hold :3000 / :8000 from experiments
pkill -f "next start" 2>/dev/null || true
pkill -f "next-server" 2>/dev/null || true
pkill -f "gunicorn.*gardenhouse" 2>/dev/null || true
if command_exists pm2; then
    sudo -u "${APP_USER}" env PM2_HOME="${APP_HOME}/.pm2" pm2 kill 2>/dev/null || true
    pm2 kill 2>/dev/null || true
fi
sleep 1

install_unit_from_template \
    "${APP_DIR}/deploy/systemd/gardenhouse-backend.service.template" \
    /etc/systemd/system/gardenhouse-backend.service
install_unit_from_template \
    "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service.template" \
    /etc/systemd/system/gardenhouse-frontend.service

systemctl daemon-reload
systemctl enable gardenhouse-backend.service gardenhouse-frontend.service
systemctl restart gardenhouse-backend.service
systemctl restart gardenhouse-frontend.service
sleep 2

if ! systemctl is-active --quiet gardenhouse-backend; then
    journalctl -u gardenhouse-backend -n 40 --no-pager || true
    die "gardenhouse-backend failed to start"
fi
if ! systemctl is-active --quiet gardenhouse-frontend; then
    journalctl -u gardenhouse-frontend -n 40 --no-pager || true
    die "gardenhouse-frontend failed to start"
fi
ok "backend + frontend systemd active (User=${APP_USER} Group=${APP_GROUP})"

# ---------------------------------------------------------------------------
log "[9/10] nginx"
# ---------------------------------------------------------------------------
mkdir -p /var/www/certbot
NGINX_SRC="${APP_DIR}/deploy/nginx/maintest.site.conf"
NGINX_AVAIL="/etc/nginx/sites-available/${DOMAIN}.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}.conf"

if [ -f "${NGINX_AVAIL}" ] && grep -q "managed by Certbot" "${NGINX_AVAIL}"; then
    warn "${NGINX_AVAIL} is certbot-managed — not overwriting TLS blocks"
else
    sed -e "s|__APP_DIR__|${APP_DIR}|g" "${NGINX_SRC}" > "${NGINX_AVAIL}"
    ok "wrote ${NGINX_AVAIL}"
fi

# Remove default site and other conflicting mains
rm -f /etc/nginx/sites-enabled/default
# Drop any other enabled site that claims our domain (except ours)
for f in /etc/nginx/sites-enabled/*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    if [ "${base}" = "${DOMAIN}.conf" ]; then
        continue
    fi
    if grep -q "${DOMAIN}" "$f" 2>/dev/null; then
        rm -f "$f"
        warn "removed conflicting site ${f}"
    fi
done
ln -sfn "${NGINX_AVAIL}" "${NGINX_ENABLED}"

nginx -t
systemctl enable nginx
systemctl restart nginx
ok "nginx reloaded"

# ---------------------------------------------------------------------------
log "[10/10] Smoke tests"
# ---------------------------------------------------------------------------
sleep 1
FAIL=0
probe() {
    local url="$1"
    local expect="$2"  # substring of status codes e.g. 200|301|302|307|308
    local code
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "${url}" 2>/dev/null || echo ERR)"
    if echo "${code}" | grep -qE "^(${expect})\$"; then
        ok "${code}  ${url}"
    else
        warn "${code}  ${url}  (expected ${expect})"
        FAIL=1
    fi
}

probe "http://127.0.0.1:8000/api/products/" "200"
probe "http://127.0.0.1:3000/gardenhouse/ru" "200|301|302|307|308"
probe "http://127.0.0.1:3000/ru" "404"   # without basePath must 404
probe "http://127.0.0.1/gardenhouse/ru" "200|301|302|307|308"
probe "http://127.0.0.1/gardenhouse" "200|301|302|307|308"

echo
if [ "${FAIL}" -ne 0 ]; then
    warn "Some probes failed — check:"
    echo "    journalctl -u gardenhouse-frontend -n 50 --no-pager"
    echo "    journalctl -u gardenhouse-backend  -n 50 --no-pager"
    echo "    nginx -t; tail -50 /var/log/nginx/error.log"
    echo "    ss -tlnp | grep -E ':80|:3000|:8000'"
    exit 1
fi

if [ "${WITH_SSL}" = true ]; then
    log "Running setup_ssl.sh (--with-ssl)"
    bash "${APP_DIR}/deploy/setup_ssl.sh" || warn "SSL setup failed — run later: sudo bash ${APP_DIR}/deploy/setup_ssl.sh"
fi

echo
echo "=============================================="
echo "  INSTALL OK"
echo "=============================================="
echo "  User/group : ${APP_USER}:${APP_GROUP}"
echo "  App dir    : ${APP_DIR}"
echo "  Site (HTTP): http://${DOMAIN}/gardenhouse"
echo "  Locale RU  : http://${DOMAIN}/gardenhouse/ru"
echo "  Locale EN  : http://${DOMAIN}/gardenhouse/en"
echo "  API        : http://${DOMAIN}/gardenhouse/api/"
echo "  Admin      : http://${DOMAIN}/gardenhouse/admin/"
echo
echo "  Services:"
echo "    systemctl status gardenhouse-backend gardenhouse-frontend nginx"
echo
echo "  Next steps:"
echo "    1. Open http://${DOMAIN}/gardenhouse in browser (HTTP until SSL)"
echo "    2. DNS A record ${DOMAIN} → this server"
echo "    3. sudo bash ${APP_DIR}/deploy/setup_ssl.sh"
echo "    4. Optional superuser:"
echo "       sudo -u ${APP_USER} ${PYTHON_BIN} ${APP_DIR}/backend/manage.py createsuperuser"
echo "    5. Later updates: sudo bash ${APP_DIR}/deploy/deploy.sh"
echo "=============================================="
