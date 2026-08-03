#!/usr/bin/env bash
#
# setup_ssl.sh — Let's Encrypt certificate for maintest.site
# ==========================================================
# Run as root (or with sudo). Requires:
#   - DNS A record: maintest.site -> 193.181.216.124
#   - nginx config from deploy/nginx/maintest.site.conf already installed
#   - port 80 (and 443) reachable through the firewall
#
# Usage:
#   sudo bash setup_ssl.sh

set -euo pipefail

# certbot needs root to write to /etc/letsencrypt and reload nginx.
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root (or with full sudo):"
    echo "  sudo bash $0"
    exit 1
fi

DOMAIN="maintest.site"

echo "==> Verifying DNS resolves to this server"
SERVER_IP="$(curl -4 -fsSL ifconfig.me || echo '')"
DNS_IP="$(getent hosts "${DOMAIN}" | awk '{print $1}' | head -n1 || echo '')"
if [ -z "${DNS_IP}" ]; then
    echo "ERROR: ${DOMAIN} does not resolve via DNS."
    echo "  Add an A record: ${DOMAIN} -> 193.181.216.124 (or your server IP)"
    exit 1
fi
if [ -n "${SERVER_IP}" ] && [ "${DNS_IP}" != "${SERVER_IP}" ]; then
    echo "WARNING: ${DOMAIN} resolves to ${DNS_IP}, but this server's public IP is ${SERVER_IP}."
    echo "  Continuing anyway — certbot will validate via HTTP-01."
fi
echo "  ${DOMAIN} -> ${DNS_IP}"

echo "==> Preparing certificate challenge directory"
mkdir -p /var/www/certbot

echo "==> Running certbot (--nginx)"
certbot --nginx \
    -d "${DOMAIN}" \
    --redirect \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email

echo "==> Testing auto-renewal"
certbot renew --dry-run

echo ""
echo "=== SSL setup complete ==="
echo "  The site is now served over HTTPS:"
echo "    https://${DOMAIN}/gardenhouse"
echo "  Certificates auto-renew via the certbot systemd timer."