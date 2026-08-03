# GardenHouse — деплой на Webdock (чистая Ubuntu)

Целевой URL:

| | |
|--|--|
| Сайт | `http(s)://maintest.site/gardenhouse` → `/gardenhouse/ru` |
| EN | `/gardenhouse/en` |
| API | `/gardenhouse/api/` |
| Admin | `/gardenhouse/admin/` |

## Важно про Webdock и пользователя

- Профиль часто называется **`maintest`**.
- **Primary group ≠ maintest**, обычно **`sudo`**.
- Скрипты **не** делают `chown maintest:maintest` и **не** меняют primary group.
- Группа берётся из ОС: `id -gn maintest` → подставляется в systemd (`User=` / `Group=`).

Проверка:

```bash
id maintest
# uid=... gid=... groups=...sudo...
```

## Архитектура

```
Интернет → nginx :80/:443
             ├── /gardenhouse/api|admin  → Gunicorn 127.0.0.1:8000
             ├── /gardenhouse/static|media → файлы
             └── /gardenhouse/*          → next start 127.0.0.1:3000
                                            next-intl: ru | en
```

- **Без PM2.** Только systemd.
- **Без `output: "standalone"`.** Только `next start`.
- **Сборка только через webpack** (`next build --webpack`).  
  Turbopack production-build на Next 16.2 зависает на `/gardenhouse/ru` (timeout 0 bytes),  
  при этом `/gardenhouse` → 308 и `/ru` → 404 выглядят «почти ок».
- Frontend: `NEXT_PUBLIC_BASE_PATH=/gardenhouse`.

## Чистая ОС — с нуля

Подключитесь по SSH (пользователь с sudo, обычно `maintest`).

**Runtime-код только в `/var/www/gardenhouse`.** Не используйте `~/gardenhouse` как боевой каталог — systemd смотрит в `/var/www`.

```bash
# 1) Клон
sudo mkdir -p /var/www
sudo git clone https://github.com/rodionvitenberg-ui/gardenhouse.git /var/www/gardenhouse
cd /var/www/gardenhouse

# 2) До install — обязательная проверка webpack
grep build frontend/package.json
# ожидаем: "build": "next build --webpack"

# 3) Полная установка (пакеты, БД, webpack-build, nginx, systemd + smoke)
sudo bash deploy/install.sh
# sudo bash deploy/install.sh --skip-ufw   # порты уже в панели Webdock

# 4) Когда DNS A maintest.site → IP сервера:
sudo bash deploy/setup_ssl.sh
```

После `install.sh` (ещё без SSL): `http://maintest.site/gardenhouse`

В логе build должно быть **`(webpack)`**.  
Install **упадёт**, если `/gardenhouse/ru` hang (Turbopack prod bug).

---

## Переустановка «снести и заново»

БД PostgreSQL можно **не** дропать. Сносим код + units:

```bash
sudo systemctl stop gardenhouse-frontend gardenhouse-backend 2>/dev/null || true
sudo rm -f /etc/systemd/system/gardenhouse-*.service
sudo systemctl daemon-reload
sudo fuser -k 3000/tcp 2>/dev/null || true

sudo rm -rf /var/www/gardenhouse

sudo git clone https://github.com/rodionvitenberg-ui/gardenhouse.git /var/www/gardenhouse
cd /var/www/gardenhouse
grep build frontend/package.json    # next build --webpack
sudo bash deploy/install.sh

curl -sI --max-time 15 http://127.0.0.1:3000/gardenhouse/ru | head -5
# → HTTP 200
```

## Обновление кода

```bash
sudo bash /var/www/gardenhouse/deploy/deploy.sh
# без повторного seed:
sudo bash /var/www/gardenhouse/deploy/deploy.sh --skip-seed
```

## Диагностика

```bash
sudo bash /var/www/gardenhouse/deploy/healthcheck.sh

sudo systemctl status gardenhouse-backend gardenhouse-frontend nginx --no-pager
sudo journalctl -u gardenhouse-frontend -n 50 --no-pager
sudo journalctl -u gardenhouse-backend  -n 50 --no-pager

curl -sI http://127.0.0.1:3000/gardenhouse/ru
curl -s  http://127.0.0.1:8000/api/products/ | head -c 200
curl -sI http://127.0.0.1/gardenhouse/ru
```

Ожидание:

| URL | Код |
|-----|-----|
| `:3000/gardenhouse/ru` | 200 / 307 |
| `:3000/ru` | **404** (basePath работает) |
| `:8000/api/products/` | 200 |
| `:80/gardenhouse/ru` | 200 / 307 |

## Сервисы

```bash
sudo systemctl restart gardenhouse-backend gardenhouse-frontend
sudo systemctl reload nginx
```

Логи:

```bash
sudo journalctl -u gardenhouse-frontend -f
sudo journalctl -u gardenhouse-backend -f
```

## Файлы

| Путь | Назначение |
|------|------------|
| `deploy/install.sh` | Первичная установка с нуля |
| `deploy/deploy.sh` | Обновление |
| `deploy/setup_ssl.sh` | Let's Encrypt |
| `deploy/healthcheck.sh` | Сводка для отладки |
| `deploy/lib/common.sh` | user/group, chown, unit templates |
| `deploy/systemd/*.template` | systemd с `__APP_USER__` / `__APP_GROUP__` |
| `deploy/nginx/maintest.site.conf` | reverse proxy `/gardenhouse` |

## Env (создаются скриптами)

- `backend/.env` — секреты, `DJANGO_FORCE_SCRIPT_NAME=/gardenhouse`
- `frontend/.env.production` — `NEXT_PUBLIC_BASE_PATH=/gardenhouse` (вшивается в **build**)

## Типичные ошибки (уже закрыты в новых скриптах)

| Было | Стало |
|------|--------|
| `chown maintest:maintest` → invalid group | `chown user:$(id -gn user)` |
| `Group=maintest` в unit | `Group=` реальная primary group |
| `next start` + `output:standalone` | standalone **запрещён**, только `next start` |
| PM2 пустой / другой user | только systemd |
| nginx без strip `/gardenhouse/api` | `proxy_pass …/api/` |
| install «успешен», сайт мёртв | smoke-тесты в конце install/deploy |

## Superuser Django

```bash
sudo -u maintest /var/www/gardenhouse/backend/venv/bin/python \
  /var/www/gardenhouse/backend/manage.py createsuperuser
```
