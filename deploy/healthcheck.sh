#!/usr/bin/env bash
#
# healthcheck.sh — paste this output when debugging
#   sudo bash /var/www/gardenhouse/deploy/healthcheck.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
resolve_app_identity

PUBLIC_IP="$(curl -4 -fsSL --max-time 5 ifconfig.me 2>/dev/null || echo unknown)"
DNS_IP="$(getent ahostsv4 "${DOMAIN}" 2>/dev/null | awk '{print $1}' | head -1 || true)"

echo "======== healthcheck $(date -Is) ========"
echo "user:group  ${APP_USER}:${APP_GROUP}"
echo "APP_DIR     ${APP_DIR}"
echo "public IP   ${PUBLIC_IP}"
echo "DNS ${DOMAIN} ${DNS_IP:-UNRESOLVED}"
echo
echo "----- ports -----"
ss -tlnp | grep -E ':80 |:443 |:3000 |:8000 ' || echo "(none)"
echo
echo "----- systemd -----"
systemctl is-active nginx gardenhouse-backend gardenhouse-frontend 2>&1 || true
echo
echo "----- unit files (User/Group) -----"
grep -E '^(User|Group|ExecStart)=' /etc/systemd/system/gardenhouse-*.service 2>/dev/null || true
echo
echo "----- frontend env -----"
grep -E '^(NEXT_PUBLIC_|API_URL)' "${APP_DIR}/frontend/.env.production" 2>/dev/null || echo "no .env.production"
echo
echo "----- next.config standalone output? -----"
if [ -f "${APP_DIR}/frontend/next.config.ts" ] \
   && sed 's|//.*||g' "${APP_DIR}/frontend/next.config.ts" \
        | grep -qE '^[[:space:]]*output:[[:space:]]*["'\'']standalone["'\'']'; then
    echo "FAIL: real output standalone is set"
else
    echo "(no standalone output key — good)"
fi
echo
echo "----- probes -----"
for url in \
    "http://127.0.0.1:8000/api/products/" \
    "http://127.0.0.1:3000/gardenhouse/ru" \
    "http://127.0.0.1:3000/ru" \
    "http://127.0.0.1/gardenhouse/ru" \
    "http://127.0.0.1/gardenhouse"
do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 "${url}" 2>/dev/null || echo ERR)"
    echo "  ${code}  ${url}"
done
echo
echo "----- recent frontend logs -----"
journalctl -u gardenhouse-frontend -n 25 --no-pager 2>/dev/null || true
echo
echo "----- recent backend logs -----"
journalctl -u gardenhouse-backend -n 15 --no-pager 2>/dev/null || true
echo "======== end ========"
