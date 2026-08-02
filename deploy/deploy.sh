#!/usr/bin/env bash
#
# deploy.sh — автоматический деплой Gardenhouse на Ubuntu-сервере.
#
# Выполняет (идемпотентно):
#   1. Клонирование репозитория в /home/maintest/gardenhouse (если нет)
#   2. Backend: venv + pip install + .env + создание БД (setup_db.sh) + миграции + seed
#   3. Frontend: npm ci + .env.production + next build + подготовка standalone
#   4. Установка systemd-сервисов и nginx (только с флагом --install-services)
#   5. Перезапуск сервисов
#
# Использование:
#   ./deploy.sh                 # полный деплой приложения (без установки служб)
#   ./deploy.sh --install-services   # + копирование unit-файлов, nginx, certbot
#   ./deploy.sh --skip-seed     # пропустить сиды (если БД уже заполнена)
#
# Требования: пользователь с sudo, уже установленные пакеты из README.
#

set -euo pipefail

# --- Параметры ---
APP_USER="${APP_USER:-maintest}"
APP_DIR="${APP_DIR:-/home/${APP_USER}/gardenhouse}"
REPO_URL="${REPO_URL:-https://github.com/rodionvitenberg-ui/gardenhouse.git}"
DOMAIN="${DOMAIN:-maintest.site}"
INSTALL_SERVICES=false
SKIP_SEED=false

for arg in "$@"; do
    case "${arg}" in
        --install-services) INSTALL_SERVICES=true ;;
        --skip-seed)        SKIP_SEED=true ;;
        *) echo "Неизвестный аргумент: ${arg}" >&2; exit 1 ;;
    esac
done

echo "==> Deploy Gardenhouse"
echo "    APP_DIR:  ${APP_DIR}"
echo "    DOMAIN:   ${DOMAIN}"

# --- 1. Клонирование репозитория ---
if [[ ! -d "${APP_DIR}/.git" ]]; then
    echo "==> Клонирование репозитория..."
    mkdir -p "$(dirname "${APP_DIR}")"
    git clone "${REPO_URL}" "${APP_DIR}"
else
    echo "==> Репозиторий уже есть, обновляем..."
    cd "${APP_DIR}"
    git pull --ff-only
fi

cd "${APP_DIR}"
git fetch --tags

# --- 2. Backend ---
echo "==> Backend: установка зависимостей..."
python3 -m venv "${APP_DIR}/backend/venv"
"${APP_DIR}/backend/venv/bin/pip" install --upgrade pip
"${APP_DIR}/backend/venv/bin/pip" install -r "${APP_DIR}/backend/requirements.txt"

echo "==> Backend: готовим .env (если нет)..."

if [[ ! -f "${APP_DIR}/backend/.env" ]]; then
    # Генерируем DJANGO_SECRET_KEY, если в .env.example стоит заглушка
    SECRET_KEY="$(python3 -c "import secrets; print(secrets.token_hex(50))")"
    sed -e "s/^DJANGO_SECRET_KEY=.*/DJANGO_SECRET_KEY=${SECRET_KEY}/" \
        "${APP_DIR}/backend/.env.example" > "${APP_DIR}/backend/.env"
    chmod 600 "${APP_DIR}/backend/.env"
    echo "    backend/.env создан (секрет сгенерирован)."
    echo "    ВНИМАНИЕ: проверьте DB_PASSWORD в ${APP_DIR}/backend/.env и выполните "
    echo "    ${APP_DIR}/backend/scripts/setup_db.sh от имени пользователя postgres,"
    echo "    если БД ещё не создана."
else
    echo "    backend/.env уже существует — пропускаем."
fi

echo "==> Backend: инициализация базы данных..."
# Скрипт сам читает пароль из .env и создаёт роль/БД.
# На сервере потребуются права администратора PostgreSQL.
if command -v sudo >/dev/null 2>&1 && sudo -n -u postgres true 2>/dev/null; then
    # Домашний каталог maintest закрыт правами 700 — пользователь postgres не сможет
    # прочитать скрипт и .env по исходному пути (Permission denied). Копируем их во
    # временную директорию в /tmp с открытыми правами и запускаем скрипт оттуда.
    TMP_DB_DIR="$(mktemp -d /tmp/gardenhouse-db.XXXXXX)"
    trap 'rm -rf "${TMP_DB_DIR}"' EXIT
    chmod 755 "${TMP_DB_DIR}"
    cp "${APP_DIR}/backend/scripts/setup_db.sh" "${TMP_DB_DIR}/setup_db.sh"
    cp "${APP_DIR}/backend/.env" "${TMP_DB_DIR}/.env"
    chmod 644 "${TMP_DB_DIR}/setup_db.sh" "${TMP_DB_DIR}/.env"
    sudo -n -u postgres env ENV_FILE="${TMP_DB_DIR}/.env" bash "${TMP_DB_DIR}/setup_db.sh"
else
    echo "    !!! Не удалось запустить setup_db.sh с правами postgres (нет passwordless sudo)."
    echo "    Выполните вручную от имени maintest:"
    echo "        sudo bash -c 'tmp=\$(mktemp -d); chmod 755 \$tmp; cp ${APP_DIR}/backend/scripts/setup_db.sh ${APP_DIR}/backend/.env \$tmp/; chmod 644 \$tmp/setup_db.sh \$tmp/.env; sudo -u postgres env ENV_FILE=\$tmp/.env bash \$tmp/setup_db.sh; rm -rf \$tmp'"
fi

echo "==> Backend: миграции..."
cd "${APP_DIR}/backend"
"${APP_DIR}/backend/venv/bin/python" manage.py migrate --noinput

if [[ "${SKIP_SEED}" != "true" ]]; then
    echo "==> Backend: seed данных..."
    "${APP_DIR}/backend/venv/bin/python" manage.py seed_data --noinput || \
        "${APP_DIR}/backend/venv/bin/python" manage.py seed_journal --noinput || true
fi

# --- 3. Frontend ---
echo "==> Frontend: установка зависимостей..."
cd "${APP_DIR}/frontend"
npm ci

echo "==> Frontend: .env.production..."
if [[ -f "${APP_DIR}/deploy/.env.production" ]]; then
    cp "${APP_DIR}/deploy/.env.production" "${APP_DIR}/frontend/.env.production"
    echo "    Скопирован из deploy/.env.production"
else
    echo "    !!! deploy/.env.production не найден — используем .env.production.example"
    cp "${APP_DIR}/frontend/.env.production.example" "${APP_DIR}/frontend/.env.production"
fi

echo "==> Frontend: сборка (next build)..."
npm run build

echo "==> Frontend: подготовка standalone..."
# В standalone-режиме Next.js собирает server.js, но не копирует public и static.
STANDALONE_DIR="${APP_DIR}/frontend/.next/standalone"
mkdir -p "${STANDALONE_DIR}"
cp -r "${APP_DIR}/frontend/public" "${STANDALONE_DIR}/public"
mkdir -p "${STANDALONE_DIR}/.next"
cp -r "${APP_DIR}/frontend/.next/static" "${STANDALONE_DIR}/.next/static"

# --- 4. Установка сервисов и nginx (опционально) ---
if [[ "${INSTALL_SERVICES}" == "true" ]]; then
    echo "==> Установка systemd-сервисов..."
    sudo cp "${APP_DIR}/deploy/systemd/gardenhouse-backend.service" "/etc/systemd/system/"
    sudo cp "${APP_DIR}/deploy/systemd/gardenhouse-frontend.service" "/etc/systemd/system/"
    # Подставляем APP_USER/APP_DIR в unit-файлы на случай нестандартных путей
    sudo sed -i "s|/home/maintest|${APP_DIR%/*}|g" "/etc/systemd/system/gardenhouse-backend.service"
    sudo sed -i "s|/home/maintest|${APP_DIR%/*}|g" "/etc/systemd/system/gardenhouse-frontend.service"
    sudo systemctl daemon-reload
    sudo systemctl enable gardenhouse-backend gardenhouse-frontend

    echo "==> Установка nginx..."
    sudo cp "${APP_DIR}/deploy/nginx/maintest.site" "/etc/nginx/sites-available/${DOMAIN}"
    sudo ln -sfn "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/${DOMAIN}"
    # Проверка конфигурации
    sudo nginx -t
    sudo systemctl reload nginx || sudo systemctl restart nginx

    echo "==> SSL-сертификат (certbot)..."
    if ! sudo certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" --non-interactive --agree-tos --redirect; then
        echo "    !!! certbot не смог выпустить сертификат."
        echo "        Убедитесь, что DNS A-запись ${DOMAIN} и www.${DOMAIN} указывает на этот сервер."
    fi
else
    echo "==> Установка служб пропущена (добавьте --install-services при первом деплое)."
fi

# --- 5. Перезапуск сервисов ---
echo "==> Перезапуск сервисов..."
sudo systemctl restart gardenhouse-backend gardenhouse-frontend || true
sudo systemctl status gardenhouse-backend --no-pager || true
sudo systemctl status gardenhouse-frontend --no-pager || true

echo
echo "==> Деплой завершён."
echo "    Сайт:  https://${DOMAIN}/gardenhouse/ru"
echo "    Админ:  https://${DOMAIN}/gardenhouse/admin"
echo
echo "    Если сервисы не запустились, смотрите логи:"
echo "        journalctl -u gardenhouse-backend  -f --no-pager"
echo "        journalctl -u gardenhouse-frontend -f --no-pager"