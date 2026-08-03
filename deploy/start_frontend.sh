#!/usr/bin/env bash
#
# start_frontend.sh — start Next.js standalone correctly
# ======================================================
# Fixes the classic mistake:
#   next start  +  output:"standalone"  → broken / wrong
# Correct:
#   node .next/standalone/server.js
#
#   sudo bash /var/www/gardenhouse/deploy/start_frontend.sh
#   # or with PM2:
#   sudo bash /var/www/gardenhouse/deploy/start_frontend.sh --pm2
#

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo bash $0"
    exit 1
fi

APP_DIR="${APP_DIR:-/var/www/gardenhouse}"
APP_USER="${APP_USER:-maintest}"
USE_PM2=false
for arg in "$@"; do
    case "$arg" in
        --pm2) USE_PM2=true ;;
    esac
done

FE="${APP_DIR}/frontend"
STANDALONE="${FE}/.next/standalone"
if [ ! -f "${STANDALONE}/server.js" ] && [ -f "${STANDALONE}/frontend/server.js" ]; then
    STANDALONE="${STANDALONE}/frontend"
fi

echo "==> Checking build"
if [ ! -d "${FE}/.next" ]; then
    echo "ERROR: no ${FE}/.next — run: sudo -u ${APP_USER} bash -c 'cd ${FE} && npm run build'"
    exit 1
fi
if [ ! -f "${STANDALONE}/server.js" ]; then
    echo "ERROR: no standalone server.js. Looking:"
    find "${FE}/.next" -name 'server.js' 2>/dev/null | head -20 || true
    echo "Rebuild with output standalone, then re-run this script."
    exit 1
fi

echo "==> Copying public + static into standalone (required)"
mkdir -p "${STANDALONE}/.next"
rm -rf "${STANDALONE}/.next/static"
cp -a "${FE}/.next/static" "${STANDALONE}/.next/static"
rm -rf "${STANDALONE}/public"
cp -a "${FE}/public" "${STANDALONE}/public"
chown -R "${APP_USER}:${APP_USER}" "${FE}/.next"
echo "  server: ${STANDALONE}/server.js"

echo "==> Stopping old next/pm2 that may hold :3000"
if command -v pm2 >/dev/null 2>&1; then
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 delete gardenhouse-frontend 2>/dev/null || true
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 delete gardenhouse-front 2>/dev/null || true
    pm2 delete gardenhouse-frontend 2>/dev/null || true
fi
systemctl stop gardenhouse-frontend 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
pkill -f "node_modules/next/dist/bin/next" 2>/dev/null || true
pkill -f "${FE}/.next/standalone" 2>/dev/null || true
sleep 1

if [ "${USE_PM2}" = true ]; then
    echo "==> Starting via PM2 (standalone)"
    # Write a tiny runtime ecosystem with the resolved STANDALONE path
    ECO="/tmp/gardenhouse-frontend.pm2.cjs"
    cat > "${ECO}" <<EOF
module.exports = {
  apps: [{
    name: "gardenhouse-frontend",
    cwd: "${STANDALONE}",
    script: "server.js",
    env: { NODE_ENV: "production", HOSTNAME: "127.0.0.1", PORT: "3000" },
    instances: 1,
    exec_mode: "fork",
    autorestart: true,
    max_memory_restart: "500M",
  }],
};
EOF
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 start "${ECO}"
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 save
    sleep 2
    sudo -u "${APP_USER}" env PM2_HOME="/home/${APP_USER}/.pm2" PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 status
else
    echo "==> Starting via systemd (standalone)"
    cp "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service" /etc/systemd/system/
    if [ "${STANDALONE}" != "${FE}/.next/standalone" ]; then
        sed -i "s|/var/www/gardenhouse/frontend/.next/standalone|${STANDALONE}|g" \
            /etc/systemd/system/gardenhouse-frontend.service
    fi
    systemctl daemon-reload
    systemctl enable gardenhouse-frontend.service
    systemctl restart gardenhouse-frontend.service
    sleep 2
    systemctl status gardenhouse-frontend --no-pager -l || true
fi

echo
echo "==> Ports"
ss -tlnp | grep ':3000 ' || echo "WARNING: nothing on :3000"
echo
echo "==> Probes"
for url in \
    "http://127.0.0.1:3000/gardenhouse/ru" \
    "http://127.0.0.1:3000/ru" \
    "http://127.0.0.1/gardenhouse/ru"
do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 "${url}" 2>/dev/null || echo ERR)"
    echo "  ${code}  ${url}"
done
echo
echo "Browser (no SSL yet):  http://maintest.site/gardenhouse"
echo "Logs systemd: journalctl -u gardenhouse-frontend -f"
echo "Logs PM2:     sudo -u maintest env PM2_HOME=/home/maintest/.pm2 pm2 logs"
