#!/usr/bin/env bash
#
# fix_frontend_webpack.sh — one-shot repair when /gardenhouse/ru hangs (000ERR)
# ===========================================================================
# Root cause we hit: Next 16.2 default Turbopack prod build hangs on
# /gardenhouse/[locale]. Webpack build returns 200.
#
#   sudo bash /var/www/gardenhouse/deploy/fix_frontend_webpack.sh
#   # or from a clone:
#   sudo bash deploy/fix_frontend_webpack.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
resolve_app_identity

FE="${APP_DIR}/frontend"
[ -d "${FE}" ] || die "missing ${FE}"

log "1/6 Stop frontend"
systemctl stop gardenhouse-frontend 2>/dev/null || true
# free port
if command_exists pm2; then
    sudo -u "${APP_USER}" env PM2_HOME="${APP_HOME}/.pm2" pm2 delete all 2>/dev/null || true
fi
# do not pkill our own bash via -f next; kill by port if needed
fuser -k 3000/tcp 2>/dev/null || true
sleep 1

log "2/6 Ensure package.json uses webpack"
sudo -u "${APP_USER}" python3 - <<PY
import json
from pathlib import Path
p = Path("${FE}/package.json")
d = json.loads(p.read_text())
d.setdefault("scripts", {})["build"] = "next build --webpack"
p.write_text(json.dumps(d, indent=2) + "\n")
print("build =", d["scripts"]["build"])
PY

# env
FRONTEND_ENV="${FE}/.env.production"
if [ ! -f "${FRONTEND_ENV}" ]; then
    cp "${FE}/.env.production.example" "${FRONTEND_ENV}"
fi
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_BASE_PATH" "/gardenhouse"
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_SITE_URL" "https://${DOMAIN}/gardenhouse"
ensure_env_key "${FRONTEND_ENV}" "NEXT_PUBLIC_API_URL" "/gardenhouse/api"
ensure_env_key "${FRONTEND_ENV}" "API_URL" "http://127.0.0.1:8000/api"
app_chown "${FRONTEND_ENV}"
ok "env BASE_PATH=$(grep BASE_PATH "${FRONTEND_ENV}")"

log "3/6 Clean .next + npm install"
sudo -u "${APP_USER}" bash -c "cd ${FE} && rm -rf .next && npm install"

log "4/6 next build --webpack (watch for line: Next.js ... (webpack))"
BUILD_LOG="/tmp/gardenhouse-webpack-build.log"
if ! sudo -u "${APP_USER}" env NODE_ENV=production \
    bash -c "cd ${FE} && npx next build --webpack" \
    2>&1 | tee "${BUILD_LOG}"; then
    die "build failed — see ${BUILD_LOG}"
fi

if ! grep -q '(webpack)' "${BUILD_LOG}"; then
    warn "Did not see '(webpack)' in build log — full banner lines:"
    grep -iE 'Next\.js|webpack|turbopack' "${BUILD_LOG}" || true
    if grep -qi 'turbopack' "${BUILD_LOG}" && ! grep -qi 'webpack' "${BUILD_LOG}"; then
        die "This was a Turbopack build. Abort."
    fi
fi
ok "build finished"

log "5/6 Ensure systemd unit + start"
if [ -f "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service.template" ]; then
    install_unit_from_template \
        "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service.template" \
        /etc/systemd/system/gardenhouse-frontend.service
    systemctl daemon-reload
fi
# unit must point at APP_DIR
systemctl cat gardenhouse-frontend 2>/dev/null | grep -E 'WorkingDirectory|ExecStart|User=' || true
systemctl enable gardenhouse-frontend
systemctl restart gardenhouse-frontend
sleep 3
systemctl is-active --quiet gardenhouse-frontend || {
    journalctl -u gardenhouse-frontend -n 50 --no-pager || true
    die "service not active"
}
ok "service active"
ss -tlnp | grep 3000 || warn "nothing on :3000"

log "6/6 Probes"
for url in \
    "http://127.0.0.1:3000/gardenhouse" \
    "http://127.0.0.1:3000/gardenhouse/ru" \
    "http://127.0.0.1:3000/ru" \
    "http://127.0.0.1/gardenhouse/ru"
do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${url}" 2>/dev/null || echo ERR)"
    echo "    ${code}  ${url}"
done

RU="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 http://127.0.0.1:3000/gardenhouse/ru 2>/dev/null || echo ERR)"
if ! echo "${RU}" | grep -qE '^(200|301|302|307|308)$'; then
    echo
    warn "STILL FAILING. Extra debug:"
    curl -v --max-time 8 http://127.0.0.1:3000/gardenhouse/ru 2>&1 | tail -25 || true
    journalctl -u gardenhouse-frontend -n 30 --no-pager || true
    free -h || true
    die "probe /gardenhouse/ru = ${RU}"
fi

echo
echo "=== FIX OK ==="
echo "  Open: http://${DOMAIN}/gardenhouse"
echo "  (or https:// if SSL already set up)"
