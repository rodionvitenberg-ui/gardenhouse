#!/usr/bin/env bash
# deploy/lib/common.sh — shared helpers for GardenHouse deploy scripts
# Source from other scripts:  # shellcheck source=lib/common.sh
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# shellcheck disable=SC2034

# ---------------------------------------------------------------------------
# Defaults (override via env before sourcing, or export before running scripts)
# ---------------------------------------------------------------------------
: "${APP_NAME:=gardenhouse}"
: "${APP_USER:=maintest}"
# APP_GROUP is resolved at runtime from the OS — do NOT assume it equals APP_USER.
# On Webdock the profile user often has primary group `sudo`, not `maintest`.
: "${APP_DIR:=/var/www/${APP_NAME}}"
: "${DOMAIN:=maintest.site}"
: "${SERVER_IP:=193.181.216.124}"
: "${REPO_URL:=https://github.com/rodionvitenberg-ui/gardenhouse.git}"
: "${REPO_BRANCH:=main}"
: "${DB_NAME:=gardenhouse_db}"
: "${DB_USER:=gardenhouse_user}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log()  { echo "==> $*"; }
ok()   { echo "    OK  $*"; }
warn() { echo "    !!  $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "run as root:  sudo bash $0 $*"
    fi
}

# Resolve the real primary group of APP_USER (e.g. "sudo" on Webdock).
resolve_app_identity() {
    if ! id "${APP_USER}" >/dev/null 2>&1; then
        die "user '${APP_USER}' does not exist.
  On Webdock create the profile first, or set APP_USER to your login:
    sudo APP_USER=myuser bash $0"
    fi
    APP_GROUP="$(id -gn "${APP_USER}")"
    APP_HOME="$(getent passwd "${APP_USER}" | cut -d: -f6)"
    if [ -z "${APP_HOME}" ] || [ ! -d "${APP_HOME}" ]; then
        warn "home for ${APP_USER} missing — using /home/${APP_USER}"
        APP_HOME="/home/${APP_USER}"
        mkdir -p "${APP_HOME}"
        chown "${APP_USER}:${APP_GROUP}" "${APP_HOME}"
    fi
    export APP_USER APP_GROUP APP_HOME APP_DIR DOMAIN
    log "Identity: user=${APP_USER} group=${APP_GROUP} home=${APP_HOME}"
    log "App dir:  ${APP_DIR}"
}

# chown to app user + THEIR real primary group (never invents group=username)
app_chown() {
    local target="$1"
    chown -R "${APP_USER}:${APP_GROUP}" "${target}"
}

# Own a path using primary group via chown user:  (portable)
ensure_app_dir() {
    mkdir -p "${APP_DIR}"
    app_chown "${APP_DIR}"
}

# Write a systemd unit from a .template file, substituting __APP_USER__ / __APP_GROUP__ / __APP_DIR__
install_unit_from_template() {
    local template="$1"
    local dest="$2"
    if [ ! -f "${template}" ]; then
        die "unit template missing: ${template}"
    fi
    sed \
        -e "s|__APP_USER__|${APP_USER}|g" \
        -e "s|__APP_GROUP__|${APP_GROUP}|g" \
        -e "s|__APP_DIR__|${APP_DIR}|g" \
        "${template}" > "${dest}"
    ok "installed ${dest} (User=${APP_USER} Group=${APP_GROUP})"
}

ensure_env_key() {
    local file="$1" key="$2" value="$3"
    if [ ! -f "${file}" ]; then
        printf '%s=%s\n' "${key}" "${value}" > "${file}"
        return
    fi
    if grep -q "^${key}=" "${file}"; then
        # Use | delimiter — values may contain /
        sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${file}"
    fi
}

read_env_key() {
    local file="$1" key="$2"
    grep -E "^${key}=" "${file}" 2>/dev/null | head -n1 | cut -d= -f2- || true
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
