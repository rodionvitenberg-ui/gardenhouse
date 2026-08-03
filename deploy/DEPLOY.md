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
- Frontend: `NEXT_PUBLIC_BASE_PATH=/gardenhouse`.

## Чистая ОС — с нуля

Подключитесь по SSH (пользователь с sudo, обычно `maintest`):

```bash
# 1) Клон в рабочий каталог
sudo mkdir -p /var/www
sudo git clone https://github.com/rodionvitenberg-ui/gardenhouse.git /var/www/gardenhouse
sudo chown -R "$(id -u):$(id -g)" /var/www/gardenhouse

# 2) Полная установка (пакеты, БД, build, nginx, сервисы)
cd /var/www/gardenhouse
sudo bash deploy/install.sh

# Если Webdock-firewall в панели уже открывает 80/443:
# sudo bash deploy/install.sh --skip-ufw

# 3) Когда DNS A-запись maintest.site → IP сервера готова:
sudo bash deploy/setup_ssl.sh
```

После `install.sh` (ещё без SSL) откройте:

```
http://maintest.site/gardenhouse
```

Скрипт **сам** прогоняет smoke-тесты и **упадёт**, если Next/API/nginx не отвечают.

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
