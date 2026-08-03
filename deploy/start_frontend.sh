#!/usr/bin/env bash
#
# start_frontend.sh — rebuild (if needed) + start Next with `next start`
# =====================================================================
#   sudo bash /var/www/gardenhouse/deploy/start_frontend.sh
#   sudo bash /var/www/gardenhouse/deploy/start_frontend.sh --rebuild
#   sudo bash /var/www/gardenhouse/deploy/start_frontend.sh --pm2
#

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo bash $0"
    exit 1
fi

APP_DIR="${APP_DIR:-/var/www/gardenhouse}"
APP_USER="${APP_USER:-maintest}"
FE="${APP_DIR}/frontend"
REBUILD=false
USE_PM2=false
for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD=true ;;
        --pm2) USE_PM2=true ;;
    esac
done

echo "==> Env (basePath must be /gardenhouse)"
if [ ! -f "${FE}/.env.production" ]; then
    cp "${FE}/.env.production.example" "${FE}/.env.production"
    chown "${APP_USER}:${APP_USER}" "${FE}/.env.production"
fi
# Force critical production keys
for kv in \
    "NEXT_PUBLIC_BASE_PATH=/gardenhouse" \
    "NEXT_PUBLIC_SITE_URL=https://maintest.site/gardenhouse" \
    "NEXT_PUBLIC_API_URL=/gardenhouse/api" \
    "API_URL=http://127.0.0.1:8000/api"
do
    key="${kv%%=*}"
    val="${kv#*=}"
    if grep -q "^${key}=" "${FE}/.env.production"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "${FE}/.env.production"
    else
        printf '%s=%s\n' "${key}" "${val}" >> "${FE}/.env.production"
    fi
done
grep -E '^(NEXT_PUBLIC_BASE_PATH|NEXT_PUBLIC_API_URL)=' "${FE}/.env.production"
chown "${APP_USER}:${APP_USER}" "${FE}/.env.production"

# Detect standalone still configured (old build)
if [ -f "${FE}/next.config.ts" ] && grep -q 'output:\s*["'\'']standalone["'\'']' "${FE}/next.config.ts"; then
    echo "WARNING: next.config still has output:standalone — remove it and rebuild"
fi

if [ "${REBUILD}" = true ] || [ ! -d "${FE}/.next" ]; then
    echo "==> Building frontend (npm run build)"
    sudo -u "${APP_USER}" bash -c "cd ${FE} && npm install && NODE_ENV=production npm run build"
else
    echo "==> Using existing ${FE}/.next (pass --rebuild to force)"
fi

if [ ! -d "${FE}/.next" ]; then
    echo "ERROR: build missing"
    exit 1
fi

echo "==> Stopping old processes on :3000"
systemctl stop gardenhouse-frontend 2>/dev/null || true
if command -v pm2 >/dev/null 2>&1; then
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 delete all 2>/dev/null || true
    pm2 delete all 2>/dev/null || true
fi
pkill -f "next start" 2>/dev/null || true
pkill -f "next-server" 2>/dev/null || true
pkill -f "${FE}/.next/standalone" 2>/dev/null || true
sleep 1

if [ "${USE_PM2}" = true ]; then
    echo "==> Start with PM2 (next start)"
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 start "${APP_DIR}/deploy/pm2/ecosystem.config.cjs"
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 save
    sleep 2
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 status
else
    echo "==> Start with systemd (next start)"
    cp "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable gardenhouse-frontend.service
    systemctl restart gardenhouse-frontend.service
    sleep 2
    systemctl status gardenhouse-frontend --no-pager -l || true
fi

echo
echo "==> Ports"
ss -tlnp | grep -E ':3000 |:80 ' || true
echo
echo "==> Probes (expect 200/307/308 on /gardenhouse/ru)"
for url in \
    "http://127.0.0.1:3000/gardenhouse/ru" \
    "http://127.0.0.1:3000/gardenhouse" \
    "http://127.0.0.1:3000/ru" \
    "http://127.0.0.1/gardenhouse/ru"
do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 "${url}" 2>/dev/null || echo ERR)"
    echo "  ${code}  ${url}"
done
echo
echo "If :3000/gardenhouse/ru is OK but :80 fails → fix nginx:"
echo "  sudo cp ${APP_DIR}/deploy/nginx/maintest.site.conf /etc/nginx/sites-available/"
echo "  sudo ln -sfn /etc/nginx/sites-available/maintest.site.conf /etc/nginx/sites-enabled/"
echo "  sudo rm -f /etc/nginx/sites-enabled/default"
echo "  sudo nginx -t && sudo systemctl reload nginx"
echo
echo "Browser: http://maintest.site/gardenhouse"
