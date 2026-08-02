#!/usr/bin/env bash
#
# setup_db.sh — инициализация PostgreSQL на сервере.
#
# Читает параметры подключения из .env (по умолчанию backend/.env):
#   DB_NAME, DB_USER, DB_PASSWORD, DB_HOST, DB_PORT
# Создаёт (если отсутствует) роль с паролем и базу данных,
# выдаёт привилегии и настраивает схему public.
#
# Использование:
#   ./scripts/setup_db.sh                 # читает ../.env
#   ENV_FILE=/path/to/.env ./setup_db.sh  # свой .env
#
# Требуется доступ администратора PostgreSQL (по приоритету):
#   1. текущий пользователь = postgres
#   2. passwordless sudo (sudo -n -u postgres psql)
#   3. psql -U postgres
#
# Скрипт идемпотентен: повторный запуск безопасен — роль/БД не дублируются,
# пароль роли обновляется до значения из .env.
#

set -euo pipefail

# --- Определяем расположение скрипта ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/../.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Ошибка: файл окружения не найден: ${ENV_FILE}" >&2
    exit 1
fi

# --- Чтение переменных из .env ---
read_env() {
    local key="$1"
    local val
    val="$(grep -E "^${key}=" "${ENV_FILE}" | head -n1 | cut -d= -f2-)"
    # Обрезаем пробелы по краям
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    # Снимаем парные кавычки, если есть
    if [[ "${#val}" -ge 2 ]]; then
        if [[ "${val:0:1}" == '"' && "${val: -1}" == '"' ]]; then
            val="${val:1:${#val}-2}"
        elif [[ "${val:0:1}" == "'" && "${val: -1}" == "'" ]]; then
            val="${val:1:${#val}-2}"
        fi
    fi
    echo "${val}"
}

DB_NAME="$(read_env DB_NAME)"
DB_USER="$(read_env DB_USER)"
DB_PASSWORD="$(read_env DB_PASSWORD)"
DB_HOST="$(read_env DB_HOST)"
DB_PORT="$(read_env DB_PORT)"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

if [[ -z "${DB_NAME}" || -z "${DB_USER}" || -z "${DB_PASSWORD}" ]]; then
    echo "Ошибка: в ${ENV_FILE} должны быть заданы DB_NAME, DB_USER, DB_PASSWORD" >&2
    exit 1
fi

# --- Валидация имён (защита от SQL-инъекций через .env) ---
if ! [[ "${DB_USER}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "Ошибка: DB_USER содержит недопустимые символы: ${DB_USER}" >&2
    exit 1
fi
if ! [[ "${DB_NAME}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "Ошибка: DB_NAME содержит недопустимые символы: ${DB_NAME}" >&2
    exit 1
fi

# --- Экранирование SQL-литерала (одинарная кавычка -> '') ---
escape_literal() {
    printf '%s' "${1}" | sed "s/'/''/g"
}

DB_PASSWORD_SQL="$(escape_literal "${DB_PASSWORD}")"

# --- Выбор команды psql с правами администратора ---
if [[ "$(id -un)" == "postgres" ]]; then
    PSQL_ADMIN=(psql -v ON_ERROR_STOP=1 -p "${DB_PORT}")
elif command -v sudo >/dev/null 2>&1; then
    if sudo -n -u postgres true 2>/dev/null; then
        PSQL_ADMIN=(sudo -n -u postgres psql -v ON_ERROR_STOP=1 -p "${DB_PORT}")
    else
        echo "Ошибка: требуется доступ к postgres, но passwordless sudo недоступен." >&2
        echo "Запустите от пользователя postgres:  sudo -i -u postgres bash ${SCRIPT_DIR}/setup_db.sh" >&2
        exit 1
    fi
else
    PSQL_ADMIN=(psql -U postgres -v ON_ERROR_STOP=1 -p "${DB_PORT}")
fi

# --- Проверка подключения ---
if ! "${PSQL_ADMIN[@]}" -d postgres -tAc "SELECT 1" >/dev/null 2>&1; then
    echo "Ошибка: не удалось подключиться к PostgreSQL как администратор." >&2
    exit 1
fi

echo "Подключение к PostgreSQL: OK"

# --- 1. Роль: создаём или обновляем пароль ---
"${PSQL_ADMIN[@]}" -d postgres <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD_SQL}';
        RAISE NOTICE 'Role ${DB_USER} created';
    ELSE
        ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD_SQL}';
        RAISE NOTICE 'Role ${DB_USER} already exists — password updated';
    END IF;
END
\$\$;
SQL
echo "Роль: ${DB_USER} готова"

# --- 2. База данных: создаём, если отсутствует ---
if [[ "$("${PSQL_ADMIN[@]}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'")" == "1" ]]; then
    echo "База данных ${DB_NAME} уже существует — пропускаем создание"
    "${PSQL_ADMIN[@]}" -d postgres -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};"
else
    "${PSQL_ADMIN[@]}" -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
    echo "База данных ${DB_NAME} создана"
fi

# --- 3. Права на уровне БД ---
"${PSQL_ADMIN[@]}" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
echo "Привилегии на БД: выданы"

# --- 4. Схема public (важно для PostgreSQL 15+) ---
"${PSQL_ADMIN[@]}" -d "${DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
"${PSQL_ADMIN[@]}" -d "${DB_NAME}" -c "ALTER SCHEMA public OWNER TO ${DB_USER};"
echo "Схема public: настроена"

echo
echo "Готово! База данных подготовлена для миграций Django:"
echo "  DB_NAME:    ${DB_NAME}"
echo "  DB_USER:    ${DB_USER}"
echo "  DB_HOST:    ${DB_HOST}"
echo "  DB_PORT:    ${DB_PORT}"
echo "  Пароль:     взят из ${ENV_FILE}"