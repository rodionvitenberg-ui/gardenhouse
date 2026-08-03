#!/usr/bin/env bash
#
# diagnose.sh — why maintest.site might refuse connections
# Run ON THE SERVER:
#   sudo bash /var/www/gardenhouse/deploy/diagnose.sh
#   # or from a local clone:
#   sudo bash deploy/diagnose.sh
#

set -u

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo bash $0"
    exit 1
fi

APP_DIR="${APP_DIR:-/var/www/gardenhouse}"
DOMAIN="${DOMAIN:-maintest.site}"
PUBLIC_IP="$(curl -4 -fsSL --max-time 5 ifconfig.me 2>/dev/null || curl -4 -fsSL --max-time 5 icanhazip.com 2>/dev/null || echo 'unknown')"
DNS_IP="$(getent ahostsv4 "${DOMAIN}" 2>/dev/null | awk '{print $1}' | head -n1 || true)"
DNS_IP="${DNS_IP:-$(getent hosts "${DOMAIN}" 2>/dev/null | awk '{print $1}' | head -n1 || echo '')}"

echo "=============================================="
echo " GardenHouse connectivity diagnose"
echo "=============================================="
echo "Time        : $(date -Is)"
echo "Server IP   : ${PUBLIC_IP}"
echo "DNS ${DOMAIN}: ${DNS_IP:-NOT RESOLVED}"
if [ -n "${DNS_IP}" ] && [ "${PUBLIC_IP}" != "unknown" ] && [ "${DNS_IP}" != "${PUBLIC_IP}" ]; then
    echo "!! DNS does NOT point to this server (${DNS_IP} != ${PUBLIC_IP})"
    echo "   Fix the A record, or open http://${PUBLIC_IP}/gardenhouse from a browser."
elif [ -n "${DNS_IP}" ] && [ "${PUBLIC_IP}" != "unknown" ]; then
    echo "OK DNS points to this server"
fi
echo

echo "--- Listening ports (80 / 443 / 3000 / 8000) ---"
ss -tlnp | grep -E ':80 |:443 |:3000 |:8000 ' || echo "(nothing on 80/443/3000/8000)"
echo

echo "--- nginx ---"
systemctl is-active nginx 2>/dev/null || true
systemctl is-enabled nginx 2>/dev/null || true
if systemctl is-active --quiet nginx; then
    echo "OK nginx is running"
else
    echo "!! nginx is NOT running — start: systemctl start nginx"
    systemctl status nginx --no-pager -l | head -30 || true
fi
echo "nginx -t:"
nginx -t 2>&1 || true
echo "sites-enabled:"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || true
echo

echo "--- firewall (ufw) ---"
if command -v ufw >/dev/null 2>&1; then
    ufw status verbose || true
else
    echo "ufw not installed"
fi
echo
echo "--- iptables INPUT (first 30 lines) ---"
iptables -L INPUT -n -v 2>/dev/null | head -30 || true
echo

echo "--- backend (Gunicorn) ---"
systemctl is-active gardenhouse-backend 2>/dev/null || true
systemctl status gardenhouse-backend --no-pager -l 2>/dev/null | head -25 || true
echo

echo "--- frontend (PM2 as maintest) ---"
if id maintest >/dev/null 2>&1; then
    sudo -u maintest env PM2_HOME=/home/maintest/.pm2 pm2 status 2>/dev/null || echo "PM2 status failed"
else
    echo "user maintest missing"
fi
echo

echo "--- local HTTP probes ---"
for url in \
    "http://127.0.0.1/" \
    "http://127.0.0.1/gardenhouse" \
    "http://127.0.0.1/gardenhouse/ru" \
    "http://127.0.0.1:3000/gardenhouse/ru" \
    "http://127.0.0.1:8000/api/products/"
do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "${url}" 2>/dev/null || echo "ERR")"
    echo "  ${code}  ${url}"
done
echo

echo "--- TLS (443) ---"
if ss -tln | grep -q ':443 '; then
    echo "OK something listens on 443"
    curl -sSI --max-time 5 "https://127.0.0.1/gardenhouse/ru" -k 2>&1 | head -8 || true
else
    echo "!! Nothing listens on port 443"
    echo "   Browser opening https://${DOMAIN} will show ERR_CONNECTION_REFUSED"
    echo "   until you run: sudo bash ${APP_DIR}/deploy/setup_ssl.sh"
    echo "   Meanwhile use:  http://${DOMAIN}/gardenhouse"
fi
echo

echo "--- cloud / external hints ---"
echo "If local curls work but the browser still refuses:"
echo "  1) Open http:// (not https://) until SSL is set up"
echo "  2) Check provider Security Group / firewall allows TCP 80 (and 443 after SSL)"
echo "  3) Confirm DNS A record ${DOMAIN} → ${PUBLIC_IP}"
echo "  4) Try http://${PUBLIC_IP}/gardenhouse (Host header may matter; nginx needs server_name)"
echo
echo "Quick fixes if nginx down:"
echo "  systemctl start nginx && systemctl enable nginx"
echo "  nginx -t && systemctl reload nginx"
echo "Quick fixes if app down:"
echo "  systemctl restart gardenhouse-backend"
echo "  sudo -u maintest env PM2_HOME=/home/maintest/.pm2 pm2 restart gardenhouse-frontend"
echo "=============================================="
