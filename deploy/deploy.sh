#!/usr/bin/env bash
#
# deploy.sh — update already-installed GardenHouse (pull, build, restart)
# ======================================================================
# Prerequisites: install.sh has been run once.
#
#   sudo bash /var/www/gardenhouse/deploy/deploy.sh
#   sudo bash deploy/deploy.sh --skip-seed
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

SKIP_SEED=false
for arg in "$@"; do
    case "${arg}" in
        --skip-seed) SKIP_SEED=true ;;
        -h|--help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *) die "unknown argument: ${arg}" ;;
    esac
done

require_root
resolve_app_identity

if [ ! -d "${APP_DIR}/backend" ] || [ ! -d "${APP_DIR}/frontend" ]; then
    die "${APP_DIR} does not look installed. Run: sudo bash deploy/install.sh"
fi

PYTHON_BIN="${APP_DIR}/backend/venv/bin/python"
PIP_BIN="${APP_DIR}/backend/venv/bin/pip"

# ---------------------------------------------------------------------------
log "[1/7] Update code"
# ---------------------------------------------------------------------------
if [ -d "${APP_DIR}/.git" ]; then
    sudo -u "${APP_USER}" git -C "${APP_DIR}" fetch origin
    sudo -u "${APP_USER}" git -C "${APP_DIR}" checkout "${REPO_BRANCH}"
    sudo -u "${APP_USER}" git -C "${APP_DIR}" pull --ff-only origin "${REPO_BRANCH}" \
        || warn "git pull --ff-only failed (local commits?). Continuing with disk code."
else
    warn "no .git in ${APP_DIR} — skipped pull (sync code manually)"
fi
app_chown "${APP_DIR}"

# ---------------------------------------------------------------------------
log "[2/7] Backend dependencies + .env guards"
# ---------------------------------------------------------------------------
BACKEND_ENV="${APP_DIR}/backend/.env"
if [ ! -f "${BACKEND_ENV}" ]; then
    die "missing ${BACKEND_ENV} — run install.sh first"
fi
ensure_env_key "${BACKEND_ENV}" "DJANGO_SECURE_SSL_REDIRECT" "False"
ensure_env_key "${BACKEND_ENV}" "DJANGO_FORCE_SCRIPT_NAME" "/gardenhouse"
ensure_env_key "${BACKEND_ENV}" "DJANGO_DEBUG" "False"
chmod 600 "${BACKEND_ENV}"
app_chown "${BACKEND_ENV}"

if [ ! -x "${PYTHON_BIN}" ]; then
    sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/backend/venv"
fi
sudo -u "${APP_USER}" "${PIP_BIN}" install --upgrade pip
sudo -u "${APP_USER}" "${PIP_BIN}" install -r "${APP_DIR}/backend/requirements.txt"

# ---------------------------------------------------------------------------
log "[3/7] Django migrate + collectstatic"
# ---------------------------------------------------------------------------
sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" migrate --noinput
sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
    "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" collectstatic --noinput

if [ "${SKIP_SEED}" != true ]; then
    sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
        "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_data \
        || warn "seed_data skipped/failed"
    sudo -u "${APP_USER}" env PATH="${APP_DIR}/backend/venv/bin:$PATH" \
        "${PYTHON_BIN}" "${APP_DIR}/backend/manage.py" seed_journal \
        || warn "seed_journal skipped/failed"
fi

# ---------------------------------------------------------------------------
log "[4/7] Frontend env + build"
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

# Only flag a real config assignment, not comments mentioning "standalone"
if [ -f "${APP_DIR}/frontend/next.config.ts" ] \
   && sed 's|//.*||g' "${APP_DIR}/frontend/next.config.ts" \
        | grep -qE '^[[:space:]]*output:[[:space:]]*["'\'']standalone["'\'']'; then
    die "next.config has output:standalone — remove that key before deploy"
fi

# Force webpack build script — Turbopack prod hang on /gardenhouse/[locale] (Next 16.2)
PKG_JSON="${APP_DIR}/frontend/package.json"
if ! grep -q 'next build --webpack' "${PKG_JSON}"; then
    warn "package.json build script missing --webpack — patching in place"
    sudo -u "${APP_USER}" python3 - <<PY
import json
from pathlib import Path
p = Path("${PKG_JSON}")
data = json.loads(p.read_text())
data.setdefault("scripts", {})["build"] = "next build --webpack"
p.write_text(json.dumps(data, indent=2) + "\n")
print("patched build -> next build --webpack")
PY
fi
ok "frontend build script: $(grep -E '"build"' "${PKG_JSON}")"

sudo -u "${APP_USER}" bash -c "cd ${APP_DIR}/frontend && npm install"
# Wipe previous .next so a Turbopack build cannot be reused by accident
sudo -u "${APP_USER}" bash -c "cd ${APP_DIR}/frontend && rm -rf .next"
sudo -u "${APP_USER}" env NODE_ENV=production bash -c "cd ${APP_DIR}/frontend && npm run build"
[ -d "${APP_DIR}/frontend/.next" ] || die "build failed — no .next"
# Sanity: webpack builds usually mention webpack in BUILD_ID timeline; check traces or just size
if [ -f "${APP_DIR}/frontend/.next/build-manifest.json" ] || [ -f "${APP_DIR}/frontend/.next/app-build-manifest.json" ]; then
    ok "build artifacts present under .next"
fi

# ---------------------------------------------------------------------------
log "[5/7] Refresh systemd units (User/Group from OS)"
# ---------------------------------------------------------------------------
install_unit_from_template \
    "${APP_DIR}/deploy/systemd/gardenhouse-backend.service.template" \
    /etc/systemd/system/gardenhouse-backend.service
install_unit_from_template \
    "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service.template" \
    /etc/systemd/system/gardenhouse-frontend.service
systemctl daemon-reload

# ---------------------------------------------------------------------------
log "[6/7] nginx (skip if certbot-managed)"
# ---------------------------------------------------------------------------
NGINX_SRC="${APP_DIR}/deploy/nginx/maintest.site.conf"
NGINX_AVAIL="/etc/nginx/sites-available/${DOMAIN}.conf"
if [ -f "${NGINX_AVAIL}" ] && grep -q "managed by Certbot" "${NGINX_AVAIL}"; then
    warn "nginx conf certbot-managed — left intact"
else
    sed -e "s|__APP_DIR__|${APP_DIR}|g" "${NGINX_SRC}" > "${NGINX_AVAIL}"
    ln -sfn "${NGINX_AVAIL}" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl reload nginx
    ok "nginx updated"
fi

# ---------------------------------------------------------------------------
log "[7/7] Restart services + probe"
# ---------------------------------------------------------------------------
# Free port 3000 from any leftover PM2
if command_exists pm2; then
    sudo -u "${APP_USER}" env PM2_HOME="${APP_HOME}/.pm2" pm2 delete all 2>/dev/null || true
    pm2 kill 2>/dev/null || true
fi
pkill -f "next start" 2>/dev/null || true
sleep 1

systemctl restart gardenhouse-backend
systemctl restart gardenhouse-frontend

systemctl is-active --quiet gardenhouse-backend || die "backend inactive"
systemctl is-active --quiet gardenhouse-frontend || {
    journalctl -u gardenhouse-frontend -n 40 --no-pager || true
    die "frontend inactive"
}

# Wait until port is open, then retry HTTP (first paint can be slow on small VPS)
for i in 1 2 3 4 5 6 7 8 9 10; do
    if ss -tln | grep -q '127.0.0.1:3000'; then
        break
    fi
    sleep 1
done

CODE="ERR"
for i in 1 2 3 4 5 6; do
    CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 http://127.0.0.1:3000/gardenhouse/ru 2>/dev/null || echo ERR)"
    echo "    probe frontend try ${i}: HTTP ${CODE}"
    if echo "${CODE}" | grep -qE '^(200|301|302|307|308)$'; then
        break
    fi
    # Turbopack hang returns 000 / timeout — no point hammering forever after first long wait
    if [ "${CODE}" = "000" ] || [ "${CODE}" = "000ERR" ] || [ "${CODE}" = "ERR" ]; then
        sleep 2
    else
        sleep 1
    fi
done

if ! echo "${CODE}" | grep -qE '^(200|301|302|307|308)$'; then
    warn "frontend probe failed (${CODE})"
    echo "    --- diagnostics ---"
    echo "    package.json build: $(grep -E '"build"' "${APP_DIR}/frontend/package.json" || true)"
    echo "    WorkingDirectory unit:"
    systemctl cat gardenhouse-frontend 2>/dev/null | grep -E 'WorkingDirectory|ExecStart|User=' || true
    ss -tlnp | grep -E ':3000|:8000|:80 ' || true
    echo "    curl -v (8s):"
    curl -v --max-time 8 http://127.0.0.1:3000/gardenhouse/ru 2>&1 | tail -30 || true
    echo "    /gardenhouse (should 308):"
    curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://127.0.0.1:3000/gardenhouse || true
    echo "    /ru (should 404 if basePath ok):"
    curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://127.0.0.1:3000/ru || true
    journalctl -u gardenhouse-frontend -n 40 --no-pager || true
    die "frontend probe failed (${CODE}).
  If /gardenhouse/ru hangs but /ru is 404: rebuild used Turbopack — need next build --webpack.
  Check: grep build ${APP_DIR}/frontend/package.json
  Manual: cd ${APP_DIR}/frontend && sudo -u ${APP_USER} rm -rf .next && sudo -u ${APP_USER} npm run build && sudo systemctl restart gardenhouse-frontend"
fi

API="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:8000/api/products/ 2>/dev/null || echo ERR)"
echo "    probe API:      HTTP ${API}"

NGX="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1/gardenhouse/ru 2>/dev/null || echo ERR)"
echo "    probe nginx:    HTTP ${NGX}"

echo
echo "=== Deploy OK ==="
echo "  App dir    : ${APP_DIR}"
echo "  http://${DOMAIN}/gardenhouse/ru"
echo "  User:Group = ${APP_USER}:${APP_GROUP}"
