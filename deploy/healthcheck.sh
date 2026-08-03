#!/usr/bin/env bash
#
# healthcheck.sh — end-to-end "why the site doesn't open"
# =======================================================
# Run ON THE SERVER as root:
#   sudo bash /var/www/gardenhouse/deploy/healthcheck.sh
#
# Paste the full output when asking for help.
#

set -u

RED=$'\033[31m'
GRN=$'\033[32m'
YLW=$'\033[33m'
RST=$'\033[0m'

ok()   { echo "${GRN}OK${RST}  $*"; }
warn() { echo "${YLW}!!${RST}  $*"; }
bad()  { echo "${RED}FAIL${RST} $*"; }

if [ "$(id -u)" -ne 0 ]; then
    echo "Run: sudo bash $0"
    exit 1
fi

APP_DIR="${APP_DIR:-/var/www/gardenhouse}"
DOMAIN="${DOMAIN:-maintest.site}"
PUBLIC_IP="$(curl -4 -fsSL --max-time 5 ifconfig.me 2>/dev/null || echo unknown)"
DNS_IP="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -1)"
DNS_IP="${DNS_IP:-$(getent hosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -1)}"

echo "======== GardenHouse healthcheck $(date -Is) ========"
echo "Server public IP : $PUBLIC_IP"
echo "DNS $DOMAIN      : ${DNS_IP:-UNRESOLVED}"
echo "APP_DIR          : $APP_DIR"
echo

# --- 1. DNS ---
echo "----- 1. DNS -----"
if [ -z "${DNS_IP:-}" ]; then
    bad "DNS for $DOMAIN does not resolve"
elif [ "$PUBLIC_IP" != "unknown" ] && [ "$DNS_IP" != "$PUBLIC_IP" ]; then
    bad "DNS ($DNS_IP) != this server ($PUBLIC_IP)"
    warn "Browser hits another machine. Fix A-record or test via IP/Host header."
else
    ok "DNS points here ($DNS_IP)"
fi
echo

# --- 2. Ports ---
echo "----- 2. Listening ports -----"
ss -tlnp 2>/dev/null | grep -E ':80 |:443 |:3000 |:8000 ' || warn "none of 80/443/3000/8000 listening"
echo
if ss -tlnp 2>/dev/null | grep -q ':80 '; then ok "port 80 open (nginx?)"; else bad "port 80 NOT listening — browser HTTP will refuse"; fi
if ss -tlnp 2>/dev/null | grep -q ':443 '; then ok "port 443 open"; else warn "port 443 closed — https:// will ERR_CONNECTION_REFUSED (use http:// until SSL)"; fi
if ss -tlnp 2>/dev/null | grep -q ':3000 '; then ok "port 3000 open (Next)"; else bad "port 3000 NOT listening — frontend down"; fi
if ss -tlnp 2>/dev/null | grep -q ':8000 '; then ok "port 8000 open (Django)"; else bad "port 8000 NOT listening — backend down"; fi
echo

# --- 3. Processes ---
echo "----- 3. Processes -----"
systemctl is-active nginx >/dev/null 2>&1 && ok "nginx active" || bad "nginx NOT active → systemctl start nginx"
systemctl is-active gardenhouse-backend >/dev/null 2>&1 && ok "gardenhouse-backend active" || warn "gardenhouse-backend inactive (check gunicorn)"
systemctl is-active gardenhouse-frontend >/dev/null 2>&1 && ok "gardenhouse-frontend active" || warn "gardenhouse-frontend inactive (ok if you use PM2 instead)"

echo "PM2 as root:"
pm2 status 2>/dev/null || echo "  (no pm2 or empty)"
echo "PM2 as maintest:"
if id maintest >/dev/null 2>&1; then
    sudo -u maintest env PM2_HOME=/home/maintest/.pm2 PATH="/usr/bin:/usr/local/bin:$PATH" \
        pm2 status 2>/dev/null || echo "  (empty or pm2 missing for maintest)"
fi
echo "next/node on 3000:"
ss -tlnp 2>/dev/null | grep ':3000 ' || true
echo

# --- 4. Build / env ---
echo "----- 4. Frontend build & env -----"
if [ -d "$APP_DIR/frontend/.next" ]; then ok ".next exists"; else bad "no $APP_DIR/frontend/.next — need npm run build"; fi
if [ -f "$APP_DIR/frontend/.env.production" ]; then
    ok ".env.production present"
    grep -E '^(NEXT_PUBLIC_BASE_PATH|NEXT_PUBLIC_SITE_URL|NEXT_PUBLIC_API_URL)=' \
        "$APP_DIR/frontend/.env.production" || warn "key NEXT_PUBLIC_* missing"
else
    bad "no .env.production"
fi
if [ -f "$APP_DIR/frontend/node_modules/next/dist/bin/next" ]; then
    ok "next binary present"
else
    bad "next binary missing — npm install in frontend/"
fi
echo

# --- 5. Local curls (the truth) ---
echo "----- 5. Local HTTP probes (most important) -----"
probe() {
    local url="$1"
    local out code
    out="$(curl -sS -D- -o /tmp/gh-hc-body.txt --max-time 8 "$url" 2>&1)" || true
    code="$(printf '%s' "$out" | awk 'BEGIN{c="ERR"} /^HTTP/{c=$2} END{print c}')"
    if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ] || [ "$code" = "308" ]; then
        ok "$code  $url"
        printf '%s\n' "$out" | head -8 | sed 's/^/      /'
    else
        bad "$code  $url"
        printf '%s\n' "$out" | head -12 | sed 's/^/      /'
        head -c 200 /tmp/gh-hc-body.txt 2>/dev/null | sed 's/^/      body: /'
        echo
    fi
}

probe "http://127.0.0.1:3000/gardenhouse/ru"
probe "http://127.0.0.1:3000/ru"
probe "http://127.0.0.1:8000/api/products/"
probe "http://127.0.0.1/gardenhouse"
probe "http://127.0.0.1/gardenhouse/ru"
probe "http://127.0.0.1/"
if [ -n "${DNS_IP:-}" ]; then
    probe "http://${DOMAIN}/gardenhouse/ru"
fi
echo

# --- 6. nginx config ---
echo "----- 6. nginx config -----"
nginx -t 2>&1 || bad "nginx -t failed"
echo "sites-enabled:"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || true
echo "gardenhouse locations (if any):"
grep -RIn "gardenhouse\|proxy_pass\|listen " /etc/nginx/sites-enabled/ 2>/dev/null | head -40 || warn "no sites-enabled match"
echo

# --- 7. Firewall ---
echo "----- 7. Firewall -----"
if command -v ufw >/dev/null; then
    ufw status verbose 2>/dev/null | head -30
else
    warn "ufw not found"
fi
echo

# --- 8. Verdict ---
echo "----- 8. What to open in the browser -----"
if ! ss -tlnp 2>/dev/null | grep -q ':443 '; then
    warn "Use HTTP not HTTPS until certbot:"
    echo "      http://${DOMAIN}/gardenhouse"
    echo "      http://${DOMAIN}/gardenhouse/ru"
else
    echo "      https://${DOMAIN}/gardenhouse"
fi
echo
echo "If step 5 shows OK on 127.0.0.1:3000 but FAIL on 127.0.0.1/gardenhouse → nginx problem"
echo "If step 5 FAIL on :3000 → frontend (PM2/systemd/build/basePath)"
echo "If step 5 OK locally but browser refused → DNS / hoster firewall / you use https"
echo "======== end healthcheck ========"
