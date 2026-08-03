#!/usr/bin/env bash
#
# debug_frontend.sh — isolate hang on /gardenhouse/ru (bypasses nginx + systemd)
# ==============================================================================
#   sudo bash /var/www/gardenhouse/deploy/debug_frontend.sh
#
# Prints facts, then runs `next start` in foreground on :3001 as app user.
# In another SSH session:
#   curl -sI --max-time 15 http://127.0.0.1:3001/gardenhouse/ru
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
resolve_app_identity
FE="${APP_DIR}/frontend"

echo "======== FACTS ========"
echo "APP_DIR=$APP_DIR  user=$APP_USER group=$APP_GROUP"
echo "package.json build:"
grep -E '"build"' "${FE}/package.json" || true
echo "basePath in build:"
python3 - <<PY
import json
from pathlib import Path
p = Path("${FE}/.next/required-server-files.json")
if p.exists():
    print(json.load(open(p))["config"].get("basePath"))
else:
    print("NO .next — need build")
PY
echo "middleware.js size:"
ls -la "${FE}/.next/server/middleware.js" 2>/dev/null || echo missing
echo "locale page exists:"
ls -la "${FE}/.next/server/app" 2>/dev/null | head -20
find "${FE}/.next/server/app" -path '*locale*' -name 'page.js' 2>/dev/null | head -10
echo
echo "env.production:"
grep -E '^(NEXT_PUBLIC_|API_URL)' "${FE}/.env.production" 2>/dev/null || true
echo
echo "free -h:"; free -h | head -5
echo
echo "systemd unit:"
systemctl cat gardenhouse-frontend 2>/dev/null | grep -E 'ExecStart|WorkingDirectory|User|Protect|Private' || true
echo
echo "probe via systemd :3000 (current):"
for url in /gardenhouse /gardenhouse/ru /ru; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 "http://127.0.0.1:3000${url}" 2>/dev/null || echo ERR)
  echo "  $code  $url"
done
echo
echo "======== MANUAL next start on :3001 (Ctrl+C to stop) ========"
echo "In another terminal run:"
echo "  curl -sI --max-time 20 http://127.0.0.1:3001/gardenhouse/ru | head -15"
echo "  curl -sI --max-time 5  http://127.0.0.1:3001/gardenhouse | head -5"
echo

systemctl stop gardenhouse-frontend 2>/dev/null || true
fuser -k 3001/tcp 2>/dev/null || true
sleep 1

cd "${FE}"
exec sudo -u "${APP_USER}" env \
  NODE_ENV=production \
  HOSTNAME=127.0.0.1 \
  PORT=3001 \
  /usr/bin/node "${FE}/node_modules/next/dist/bin/next" start -H 127.0.0.1 -p 3001
