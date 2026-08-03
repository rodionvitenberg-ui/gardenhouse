# Деплой GardenHouse на maintest.site/gardenhouse

Сайт открывается по адресу:

```
https://maintest.site/gardenhouse      → редирект на /gardenhouse/ru
https://maintest.site/gardenhouse/ru   — русский (default)
https://maintest.site/gardenhouse/en   — English
```

Деплой **только скриптами** (без интерактивного SSH-тюнинга с вашей машины разработчика). Все команды ниже выполняются **на сервере** под пользователем с `sudo`.

---

## 1. Архитектура

```
Интернет
   │
Nginx :80 / :443          ← единственный публичный процесс
   ├── /gardenhouse/api/     → Gunicorn 127.0.0.1:8000/api/   (prefix stripped)
   ├── /gardenhouse/admin/   → Gunicorn 127.0.0.1:8000/admin/
   ├── /gardenhouse/static/  → backend/staticfiles/
   ├── /gardenhouse/media/   → backend/media/
   └── /gardenhouse/*        → Next.js  127.0.0.1:3000
                                  └── next-intl: ru | en
```

| Компонент | Как крутится | Порт |
|-----------|--------------|------|
| Django (Gunicorn) | systemd `gardenhouse-backend` | 127.0.0.1:8000 |
| Next.js | PM2 `gardenhouse-frontend` | 127.0.0.1:3000 |
| PostgreSQL | системный сервис | 5432 (localhost) |
| Nginx | reverse proxy + TLS | 80, 443 |

Каталог приложения на сервере: **`/var/www/gardenhouse`**  
Системный пользователь: **`maintest`**

---

## 2. Почему `/gardenhouse` и как живёт локализация

### Frontend (Next.js + next-intl)

- `NEXT_PUBLIC_BASE_PATH=/gardenhouse` → `next.config.ts` → `basePath`
- Все маршруты, `next/link`, `next/image`, `/_next/*` получают префикс автоматически
- next-intl (`src/proxy.ts` + `src/i18n/routing.ts`): локали `ru`, `en`, default `ru`
- Итоговые URL: `/gardenhouse/ru/...`, `/gardenhouse/en/...`
- `NEXT_PUBLIC_API_URL=/gardenhouse/api` — same-origin, CORS не нужен
- `NEXT_PUBLIC_*` **вшиваются на `next build`** — смена basePath = пересборка

### Backend (Django)

- `DJANGO_FORCE_SCRIPT_NAME=/gardenhouse` — префикс в redirect/pagination
- `MEDIA_URL` / `STATIC_URL` автоматически становятся `/gardenhouse/media/` и `/gardenhouse/static/`
- Nginx **снимает** `/gardenhouse` при проксировании на Gunicorn (`proxy_pass …/api/`)

---

## 3. Первичный деплой (с нуля)

### 3.1. DNS

A-запись:

```
maintest.site  →  <IP сервера>   (сейчас в скриптах: 193.181.216.124)
```

### 3.2. Клонирование

```bash
# Любой удобный путь, откуда запустить setup (потом код живёт в /var/www/gardenhouse)
cd /tmp
git clone https://github.com/rodionvitenberg-ui/gardenhouse.git
cd gardenhouse
```

Если репозиторий private — клонируйте с deploy-ключом или токеном.

### 3.3. Четыре скрипта по порядку

```bash
# 1) Пакеты: nginx, postgres, node 22, pm2, certbot, user maintest
sudo bash deploy/setup_server.sh

# 2) PostgreSQL: роль gardenhouse_user + БД gardenhouse_db
sudo bash deploy/create_db.sh

# 3) Код → deps → build → migrate → collectstatic → сервисы + nginx
sudo bash deploy/deploy.sh

# 4) Let's Encrypt (только когда DNS уже указывает на этот сервер)
sudo bash deploy/setup_ssl.sh
```

После шага 3 сайт уже отвечает по HTTP. После шага 4 — по HTTPS.

### 3.4. Суперпользователь Django (опционально)

```bash
sudo -u maintest /var/www/gardenhouse/backend/venv/bin/python \
  /var/www/gardenhouse/backend/manage.py createsuperuser
```

Админка: `https://maintest.site/gardenhouse/admin/`

---

## 4. Обновление (каждый релиз)

На машине разработки: commit + push в `main`.

На сервере:

```bash
sudo bash /var/www/gardenhouse/deploy/deploy.sh
```

Скрипт сделает `git pull`, пересоберёт фронт, применит миграции, перезапустит backend и frontend.

> Если правили `NEXT_PUBLIC_*` в `frontend/.env.production` — убедитесь, что файл содержит нужные значения **до** `npm run build` (скрипт не перезаписывает существующий `.env.production`).

---

## 5. Переменные окружения

### Frontend — `frontend/.env.production`

Шаблон: `frontend/.env.production.example` (копируется deploy.sh при первом запуске).

| Переменная | Значение prod |
|------------|---------------|
| `NEXT_PUBLIC_SITE_URL` | `https://maintest.site/gardenhouse` |
| `NEXT_PUBLIC_BASE_PATH` | `/gardenhouse` |
| `NEXT_PUBLIC_API_URL` | `/gardenhouse/api` |
| `API_URL` | `http://127.0.0.1:8000/api` (sitemap, server-side) |

### Backend — `backend/.env`

Шаблон: `backend/.env.production.example`.

| Переменная | Значение prod |
|------------|---------------|
| `DJANGO_DEBUG` | `False` |
| `DJANGO_SECURE_SSL_REDIRECT` | `False` (редирект делает nginx) |
| `DJANGO_FORCE_SCRIPT_NAME` | `/gardenhouse` |
| `DJANGO_ALLOWED_HOSTS` | `maintest.site,...` |
| `DJANGO_CSRF_TRUSTED_ORIGINS` | `https://maintest.site` |
| `DB_*` | `gardenhouse_db` / `gardenhouse_user` / пароль |

Секреты (`DJANGO_SECRET_KEY`, `DB_PASSWORD`) генерируются скриптами и **не коммитятся**.

---

## 6. Логи и перезапуск

```bash
# Backend
sudo journalctl -u gardenhouse-backend -f --no-pager
sudo systemctl restart gardenhouse-backend

# Frontend (PM2)
sudo -u maintest bash -c 'export PM2_HOME=/home/maintest/.pm2; pm2 logs gardenhouse-frontend'
sudo -u maintest bash -c 'export PM2_HOME=/home/maintest/.pm2; pm2 restart gardenhouse-frontend'
sudo -u maintest bash -c 'export PM2_HOME=/home/maintest/.pm2; pm2 status'

# Nginx
sudo nginx -t && sudo systemctl reload nginx
sudo tail -f /var/log/nginx/error.log
```

---

## 7. Чеклист после деплоя

```bash
# Локально на сервере
curl -sI http://127.0.0.1:3000/gardenhouse/ru | head -5     # Next → 200
curl -s  http://127.0.0.1:8000/api/products/ | head -c 200  # Django → JSON

# Снаружи (после SSL)
curl -sI https://maintest.site/gardenhouse          # 3xx → /gardenhouse/ru
curl -sI https://maintest.site/gardenhouse/ru       # 200
curl -sI https://maintest.site/gardenhouse/en       # 200
curl -s  https://maintest.site/gardenhouse/api/products/ | head -c 200
```

В браузере:

1. Открыть `https://maintest.site/gardenhouse` — должна открыться русская версия.
2. Переключатель языка EN/RU — URL меняется на `/en` / `/ru`, контент переводится.
3. Видео/логотипы/шрифт грузятся (пути с `/gardenhouse/...`).
4. Каталог shop/journal — картинки из API с путём `/gardenhouse/media/...`.

---

## 8. Если на сервере уже был старый деплой

Раньше код мог лежать в `/home/maintest/gardenhouse` и крутиться через systemd `gardenhouse-frontend`.

Перед первым запуском нового `deploy.sh`:

```bash
# Остановить старый фронт (systemd), если был
sudo systemctl disable --now gardenhouse-frontend 2>/dev/null || true
sudo rm -f /etc/systemd/system/gardenhouse-frontend.service
sudo systemctl daemon-reload
pkill -f "next start" 2>/dev/null || true

# Остановить старый backend, если unit указывал на другой путь
sudo systemctl stop gardenhouse-backend 2>/dev/null || true
```

Затем полный цикл `setup_server` (идемпотентен) → `create_db` → `deploy` → `setup_ssl` (если SSL ещё нет).

Медиа из старого пути:

```bash
sudo rsync -av /home/maintest/gardenhouse/backend/media/ /var/www/gardenhouse/backend/media/
sudo chown -R maintest:maintest /var/www/gardenhouse/backend/media
```

---

## 9. Типичные проблемы

| Симптом | Причина | Что сделать |
|---------|---------|-------------|
| `ERR_TOO_MANY_REDIRECTS` | Django `SECURE_SSL_REDIRECT=True` за nginx | В `backend/.env`: `DJANGO_SECURE_SSL_REDIRECT=False`, restart backend |
| 404 на `/gardenhouse/ru` | basePath не вшит в билд | Проверить `frontend/.env.production`, пересобрать (`deploy.sh`) |
| API 404 | nginx не strip'ает prefix | Должен быть `proxy_pass http://127.0.0.1:8000/api/;` |
| Картинки API 404 | `MEDIA_URL` без `/gardenhouse` | Нужен актуальный `settings.py` + `DJANGO_FORCE_SCRIPT_NAME` |
| EADDRINUSE :3000 | Старый `next start` не убит | `pkill -f "next start"`, `pm2 restart` |
| `npm ci` OOM | Мало RAM | Скрипт использует `npm install` — не менять на `ci` |
| Certbot перезаписал conf | Нормально | `deploy.sh` не трогает conf с маркером Certbot |

---

## 10. Локальная разработка (не prod)

```bash
# Backend
cd backend && python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # без FORCE_SCRIPT_NAME
python manage.py migrate && python manage.py runserver

# Frontend — basePath пустой
cd frontend
cp .env.example .env.local   # NEXT_PUBLIC_API_URL=http://localhost:8000/api
npm install && npm run dev
```

Локально сайт: `http://localhost:3000/ru` (без `/gardenhouse`).
