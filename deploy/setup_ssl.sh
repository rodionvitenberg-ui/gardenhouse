#!/usr/bin/env bash
#
# setup_ssl.sh — Let's Encrypt for maintest.site (run after DNS works)
# ==================================================================
#   sudo bash /var/www/gardenhouse/deploy/setup_ssl.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
resolve_app_identity

if ! command_exists certbot; then
    apt-get update -y
    apt-get install -y certbot python3-certbot-nginx
fi

mkdir -p /var/www/certbot

log "DNS check for ${DOMAIN}"
SERVER_IP_LIVE="$(curl -4 -fsSL --max-time 5 ifconfig.me 2>/dev/null || echo '')"
DNS_IP="$(getent ahostsv4 "${DOMAIN}" 2>/dev/null | awk '{print $1}' | head -1 || true)"
DNS_IP="${DNS_IP:-$(getent hosts "${DOMAIN}" 2>/dev/null | awk '{print $1}' | head -1 || true)}"

if [ -z "${DNS_IP}" ]; then
    die "${DOMAIN} does not resolve. Add A record → this server, wait for DNS, retry."
fi
ok "${DOMAIN} → ${DNS_IP}"
if [ -n "${SERVER_IP_LIVE}" ] && [ "${DNS_IP}" != "${SERVER_IP_LIVE}" ]; then
    warn "DNS (${DNS_IP}) != this host public IP (${SERVER_IP_LIVE}). Certbot may fail."
fi

# Ensure nginx is up and serving on 80
systemctl is-active --quiet nginx || systemctl start nginx
nginx -t

log "certbot --nginx"
certbot --nginx \
    -d "${DOMAIN}" \
    -d "www.${DOMAIN}" \
    --redirect \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    || certbot --nginx \
        -d "${DOMAIN}" \
        --redirect \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email

# After SSL, ensure Django still does not do its own redirect
BACKEND_ENV="${APP_DIR}/backend/.env"
if [ -f "${BACKEND_ENV}" ]; then
    ensure_env_key "${BACKEND_ENV}" "DJANGO_SECURE_SSL_REDIRECT" "False"
    ensure_env_key "${BACKEND_ENV}" "DJANGO_CSRF_TRUSTED_ORIGINS" "https://${DOMAIN}"
    ensure_env_key "${BACKEND_ENV}" "CORS_ALLOWED_ORIGINS" "https://${DOMAIN}"
    systemctl restart gardenhouse-backend || true
fi

certbot renew --dry-run || warn "renew dry-run failed (timer may still work later)"

echo
echo "=== SSL OK ==="
echo "  https://${DOMAIN}/gardenhouse"
echo "  https://${DOMAIN}/gardenhouse/ru"
