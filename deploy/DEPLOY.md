# Деплой Gardenhouse на Ubuntu-сервер

Документ пошагово объясняет, **что** и **зачем** мы делаем при развёртывании сайта на сервере. Сайт будет открываться по адресу:

```
https://maintest.site/gardenhouse/ru
```

---

## 1. Общая архитектура (что будет на сервере)

```
Интернет (клиент)
   │
   ▼
Nginx (порт 80/443)  ← единственный процесс, который "смотрит наружу"
   │  https://maintest.site/gardenhouse/*
   ├── /gardenhouse/api/   →  Django (Gunicorn) на 127.0.0.1:8000
   ├── /gardenhouse/admin/ →  Django (Gunicorn) на 127.0.0.1:8000
   ├── /gardenhouse/media/ →  файлы из /home/maintest/gardenhouse/backend/media
   └── всё остальное        →  Next.js (standalone) на 127.0.0.1:3000
```

**Почему nginx?** Это front-контроллер (reverse proxy). Он единственный имеет публичные порты 80/443, терминирует TLS (HTTPS), раздаёт статику и направляет запросы внутренним сервисам. Django и Next.js слушают только `127.0.0.1` — их не видно снаружи напрямую. Это **принцип наименьших привилегий**: наружу открыто только то, что необходимо.

---

## 2. Разделение прав (кто есть кто на сервере)

| Кто | Что делает | Права |
|-----|-----------|-------|
| **root** | Установка пакетов, системные службы | Полные |
| **maintest** (обычный пользователь) | Клонирует репозиторий, управляет кодом, venv, npm | Свой домашний каталог |
| **postgres** (системный пользователь БД) | Создаёт роль и базу данных | Только БД |
| **nginx** (системный пользователь) | Читает файлы медиа для раздачи | Read-only |
| **gardenhouse-backend.service** (systemd) | Запускает Gunicorn от лица `maintest` | Ограничено только кодом |
| **gardenhouse-frontend.service** (systemd) | Запускает Next.js от лица `maintest` | Ограничено только кодом |

### Почему не запускать всё от root?
- **Безопасность**: если приложение скомпрометируют, атакующий получает права только того пользователя, под которым работает процесс. От `maintest` он не сможет читать `/root`, менять систему и т.д.
- **Защита БД**: Django подключается к PostgreSQL **не как суперпользователь `postgres`**, а как отдельная роль `garden_user` с паролем из `.env`. Перехват пароля даёт доступ только к одной базе `garden_db`, а не ко всему кластеру PostgreSQL.
- **Чистые права на файлы**: код принадлежит `maintest` (`chown -R maintest:maintest`), поэтому службы, запущенные от `maintest`, могут читать и писать только в свой проект.

---

## 3. Порядок деплоя (что делаем и почему)

### 3.1. Первичная установка пакетов

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git wget build-essential software-properties-common
sudo apt install -y python3 python3-venv python3-pip python3-dev libpq-dev nginx certbot python3-certbot-nginx postgresql postgresql-contrib
```

- **`python3-venv`** — создание изолированных окружений Python (чтобы зависимости проекта не ломали системный Python).
- **`libpq-dev`** — заголовочные файлы для сборки `psycopg2-binary` (драйвер PostgreSQL для Django).
- **`nginx`** — reverse proxy (см. §1).
- **`certbot`** + `python3-certbot-nginx` — бесплатные TLS-сертификаты Let's Encrypt, автоматически встраиваемые в nginx.
- **`postgresql` / `postgresql-contrib`** — сервер БД и дополнительные модули.

---

### 3.2. Клонирование репозитория

```bash
cd ~
git clone https://github.com/rodionvitenberg-ui/gardenhouse.git
cd gardenhouse
```

Всё приложение лежит в `/home/maintest/gardenhouse`.

---

### 3.3. Бэкенд: виртуальное окружение и зависимости

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

**Зачем venv?** Python на Ubuntu глобальный. Если ставить зависимости проекта туда, разные проекты будут конфликтовать. `venv` — изолированная копия Python внутри папки проекта. Каждый сервис получает только свои пакеты.

---

### 3.4. Бэкенд: конфигурация `.env`

```bash
nano .env   # или скопировать из .env.example и заполнить
```

Ключевые переменные (Django уже умеет их читать благодаря `core/settings.py`):

```
DJANGO_SECRET_KEY=<длинная случайная строка>   # подпись сессий/токенов
DJANGO_DEBUG=False                              # продакшен: показывать только реальные ошибки
DJANGO_ALLOWED_HOSTS=maintest.site,www.maintest.site
DB_NAME=garden_db
DB_USER=garden_user
DB_PASSWORD=<надёжный пароль>
DB_HOST=localhost
DB_PORT=5432
```

**Почему `DJANGO_DEBUG=False`?** В dev-режиме Django выдаёт клиенту страницы с трейсбеками, структуру БД, пути к файлам — это брешь. В проде показывается только "500" без деталей, а подробности пишутся в журнал.

---

### 3.5. PostgreSQL: роль и база данных

Запускаем созданный скрипт (`setup_db.sh`). Он читает `DB_NAME`, `DB_USER`, `DB_PASSWORD` из `.env`, создаёт роль с паролем и базу данных, выдаёт права:

```bash
sudo -i -u postgres bash /home/maintest/gardenhouse/backend/scripts/setup_db.sh
```

**Разбор того, что делает скрипт:**

1. **Роль** `garden_user` — это "логин" PostgreSQL. Он создаётся **отдельно от системного пользователя Linux**. Django будет подключаться именно этой ролью.
2. **База** `garden_db` — владельцем назначается `garden_user`. Принцип: база принадлежит приложению, а не суперпользователю.
3. **`GRANT ALL PRIVILEGES ON DATABASE garden_db TO garden_user`** — грант на уровне базы (подключение + create schema и т.п.).
4. **`GRANT ALL ON SCHEMA public TO garden_user`** + **`ALTER SCHEMA public OWNER TO garden_user`** — критично для **PostgreSQL 15+**: начиная с этой версии, публичная схема по умолчанию не принадлежит обычной роли. Без этого шага Django не сможет создавать таблицы при `migrate`.

**Типичная ошибка `Permission denied` при запуске из `deploy.sh`:**

```
bash: /home/maintest/gardenhouse/backend/scripts/setup_db.sh: Permission denied
```

Причина — **права доступа к домашнему каталогу**: `/home/maintest` создаётся с правами `700` (только владелец `maintest` может входить). Когда `deploy.sh` пытается запустить скрипт от имени пользователя `postgres`:

```bash
sudo -u postgres bash /home/maintest/gardenhouse/backend/scripts/setup_db.sh
```

пользователь `postgres` не может даже **пройти по пути** `/home/maintest` — у него нет права `x` на эту директорию, хотя сам скрипт и `.env` лежат с нормальными правами. Отсюда и `Permission denied` — и это **правильное поведение системы**, а не баг: закрытый домашний каталог защищает твои файлы от чтения другими пользователями.

**Решение:** копируем нужные файлы во временную директорию с открытыми правами и запускаем оттуда:

```bash
tmp=$(mktemp -d)
chmod 755 "$tmp"
cp /home/maintest/gardenhouse/backend/scripts/setup_db.sh "$tmp/"
cp /home/maintest/gardenhouse/backend/.env "$tmp/"
chmod 644 "$tmp/setup_db.sh" "$tmp/.env"
sudo -u postgres env ENV_FILE="$tmp/.env" bash "$tmp/setup_db.sh"
rm -rf "$tmp"
```

Именно это `deploy.sh` делает автоматически: создаёт `/tmp/gardenhouse-db.XXXXXX`, кладёт туда скрипт и `.env`, запускает `setup_db.sh` от имени `postgres`, а по завершении удаляет временную папку. Пароль из `.env` в постоянном виде при этом нигде не остаётся.

---

### 3.6. Миграции и сиды

```bash
python manage.py migrate --noinput
python manage.py seed_data --noinput   # если есть
python manage.py createsuperuser --noinput  # создаст суперпользователя админки
```

`migrate` создаёт **таблицы** по описаниям моделей Django. Без него приложение упадёт на первом запросе ("relation does not exist").

---

### 3.7. Frontend: сборка Next.js

```bash
cd ../frontend
npm ci
# создаём .env.production:
#   NEXT_PUBLIC_SITE_URL=https://maintest.site/gardenhouse
#   NEXT_PUBLIC_BASE_PATH=/gardenhouse
#   NEXT_PUBLIC_API_URL=/gardenhouse/api
#   API_URL=http://127.0.0.1:8000/api
npm run build
```

**Почему `basePath=/gardenhouse`?** Next.js должен знать, что живёт не на корне домена, а в подкаталоге. Тогда он:
- добавляет префикс ко всем внутренним ссылкам `next/link`;
- раздаёт статику из `/gardenhouse/_next/static/`;
- корректно обрабатывает `sitemap.ts` и `robots`.

**Зачем `NEXT_PUBLIC_API_URL=/gardenhouse/api`, а не абсолютный URL?** Чтобы браузер делал запрос на **тот же origin** (`https://maintest.site/gardenhouse/api`). Тогда нет CORS, нет лишнего сетевого перехода, и cookie работают в рамках одного домена.

**Зачем `API_URL=http://127.0.0.1:8000/api` (без NEXT_PUBLIC)?** Это серверная переменная для `sitemap.ts` — она используется во время генерации sitemap на сервере, поэтому ходит к Django **напрямую через localhost**, минуя лишний круг через nginx.

Проверить сборку локально:
```bash
NEXT_PUBLIC_BASE_PATH=/gardenhouse npm run build
```

---

### 3.8. Standalone (вырезание минимального сервера)

Next.js умеет собирать **standalone-режим** (`output: "standalone"` в `next.config.ts`):

```bash
cp -r .next/static .next/standalone/.next/static
cp -r public .next/standalone/public
```

Он создаёт минимальный Node-сервер в `.next/standalone/server.js`, в который входят только файлы, реально используемые приложением. Но `public/` и `static/` он **не копирует сам** — поэтому мы добавляем их вручную. Именно этот `server.js` и будет запускать systemd-сервис.

---

### 3.9. systemd-сервисы (автозапуск и наблюдение)

Создаём два unit-файла в `/etc/systemd/system/`:

**`gardenhouse-backend.service`** (Django/Gunicorn):
```
[Service]
User=maintest                     # не root!
WorkingDirectory=/home/maintest/gardenhouse/backend
EnvironmentFile=/home/maintest/gardenhouse/backend/.env
ExecStart=/home/maintest/gardenhouse/backend/venv/bin/gunicorn core.wsgi:application --bind 127.0.0.1:8000 --workers 3
Restart=always
[Install]
WantedBy=multi-user.target
```

**`gardenhouse-frontend.service`** (Next.js standalone):
```
[Service]
User=maintest
WorkingDirectory=/home/maintest/gardenhouse/frontend
Environment=HOSTNAME=127.0.0.1
Environment=PORT=3000
ExecStart=/home/maintest/gardenhouse/frontend/.next/standalone/server.js
Restart=always
[Install]
WantedBy=multi-user.target
```

**Почему `User=maintest`?** Сервисы — это демоны, которые живут всё время. Если их запустить от root, любая дыра в приложении = полный root на сервере. От `maintest` — максимум ущерб ограничен домашней папкой. Это прямой пример принципа наименьших привилегий.

**Почему `Restart=always`?** Если процесс аварийно упал (переполнение памяти, исключение), systemd сам его поднимет через 5 секунд. Сайт остаётся живым даже при редких падениях.

**Активация:**
```bash
sudo systemctl daemon-reload        # перечитать unit-файлы
sudo systemctl enable gardenhouse-backend gardenhouse-frontend  # автозапуск при загрузке
sudo systemctl start gardenhouse-backend gardenhouse-frontend
sudo systemctl status gardenhouse-backend gardenhouse-frontend
```

---

### 3.9.1. Почему systemd, а не PM2?

Ответ — **и для Gunicorn (Python), и для Next.js (Node) здесь один инструмент уже встроен в ОС**. Ниже аргументы.

| Критерий | systemd | PM2 |
|----------|---------|-----|
| Откуда берётся | Часть ОС (init, процесс №1) — уже работает | Отдельный npm-пакет, требует установки `pm2` глобально |
| Управление Python (Gunicorn) | Да, родное | Нет — для Python всё равно нужен supervisor/systemd |
| Автозапуск при загрузке | `systemctl enable` — нативно | `pm2 startup` — **сам генерирует systemd-unit под капотом** |
| Логи | Единый `journalctl -u ...` | Своя панель `pm2 logs`, отдельные файлы логов |
| Права | Строгий `User=maintest`, sandbox (`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`) | Процессы от пользователя, запустившего pm2 |
| Лишний процесс | Нет — systemd всегда работает | + 1 постоянный демон PM2 (Node-процесс) |
| Лимиты ресурсов | Встроенные cgroups (`MemoryMax`, `CPUQuota`) | Менее строгие |

**Факт, который всё упрощает:** в вашем стеке **два разных процесса** — Django (Python) и Next.js (Node). Если бы мы взяли PM2 для Next.js, то для Django пришлось бы всё равно использовать второй механизм (supervisor или systemd). Получились бы **два разных способа управления** на одном сервере. Держать оба процесса в systemd — единообразно: один `systemctl restart gardenhouse-backend gardenhouse-frontend`, одни логи через `journalctl`, один автозапуск.

**Ирония PM2:** команда `pm2 startup` (без которой PM2 не переживёт перезагрузку) на самом деле **создаёт systemd-service**, который поднимает PM2. То есть даже PM2 в конечном счёте опирается на systemd. Зачем добавлять прослойку, если systemd уже умеет запускать наш `server.js` напрямую?

**Итог:** PM2 оправдан, когда на сервере десятки Node-микросервисов со своей логикой кластеризации. У нас — два процесса, и оба прекрасно живут под systemd: Gunicorn сам даёт воркеры (`--workers 3`), Next.js standalone сам даёт нужный сервер.

### 3.10. Nginx: TLS, маршрутизация, статика

**`/etc/nginx/sites-available/maintest.site`**:

```nginx
# HTTP → HTTPS
server {
    listen 80;
    server_name maintest.site;
    return 301 https://maintest.site$request_uri;
}

server {
    listen 443 ssl http2;
    server_name maintest.site;

    ssl_certificate     /etc/letsencrypt/live/maintest.site/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/maintest.site/privkey.pem;

    # Django API
    location /gardenhouse/api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Django admin
    location /gardenhouse/admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Media-файлы отдаёт сам nginx (быстрее, чем гонять через Python)
    location /gardenhouse/media/ {
        alias /home/maintest/gardenhouse/backend/media/;
    }

    # Всё остальное → Next.js
    location /gardenhouse {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Корень → сразу на русскую локаль
    location = / {
        return 301 https://maintest.site/gardenhouse/ru;
    }
}
```

**Что здесь важно понять:**

1. **`proxy_pass http://127.0.0.1:8000`** (без пути после порта!) — nginx передаёт Django **весь исходный URI целиком**: `/gardenhouse/api/products/`. Django видит его как `PATH_INFO`. Поэтому в `settings.py` стоит `FORCE_SCRIPT_NAME = os.getenv('DJANGO_FORCE_SCRIPT_NAME') or None` — при необходимости можно включить, чтобы Django генерировал URL с префиксом `/gardenhouse`.

2. **`X-Forwarded-Proto $scheme`** — Django за nginx видит соединение как HTTP (внутри), но по этому заголовку понимает, что клиент пришёл по HTTPS. Без него `SECURE_SSL_REDIRECT` зациклит редиректы.

3. **Медиа раздаёт nginx напрямую, минуя Python** — это и быстрее, и снимает нагрузку с Gunicorn. Django в проде сам не раздаёт файлы (`static()` работает только при `DEBUG=True`).

4. **`location /gardenhouse` (без `=`) → Next.js** — сюда попадает и `/_next/*`, и страницы `/ru`, `/en`, и все внутренние маршруты. Next.js сам знает про basePath и отвечает правильно.

**Активация:**
```bash
sudo ln -s /etc/nginx/sites-available/maintest.site /etc/nginx/sites-enabled/
sudo nginx -t            # проверка синтаксиса
sudo systemctl reload nginx
```

---

### 3.11. TLS-сертификаты (Let's Encrypt)

```bash
sudo certbot --nginx -d maintest.site -d www.maintest.site --redirect
```

Certbot:
1. Проверяет, что домен реально смотрит на этот сервер (HTTP-челлендж на порту 80);
2. Выпускает сертификат;
3. **Автоматически правит конфиг nginx**: добавляет `ssl_certificate`, настраивает HTTP→HTTPS, включает автопродление (сертификаты живут 90 дней).

---

## 4. Установка на сервере за 2 команды

Всё описанное выше автоматизировано в `deploy/deploy.sh`:

```bash
cd ~ && git clone https://github.com/rodionvitenberg-ui/gardenhouse.git && cd gardenhouse
./deploy/deploy.sh --install-services
```

Скрипт сам:
- клонирует/обновляет код;
- создаёт venv и ставит Python-зависимости;
- создаёт `.env` из `.env.example`, если его нет;
- запускает `setup_db.sh` (требует passwordless sudo или прав postgres);
- выполняет миграции и сиды;
- ставит npm-зависимости и собирает frontend из `deploy/.env.production`;
- копирует unit-файлы и nginx-конфиг, активирует их;
- запускает certbot;
- перезапускает сервисы.

> **Внимание**: перед первым запуском отредактируйте `deploy/.env.production` (если будете использовать свой вариант) и убедитесь, что у `sudo` есть доступ к `postgres` (см. §3.5).

---

## 5. Эксплуатация (повседневные операции)

```bash
# Логи бэкенда/фронтенда
journalctl -u gardenhouse-backend  -f --no-pager
journalctl -u gardenhouse-frontend -f --no-pager

# Перезапуск после деплоя
sudo systemctl restart gardenhouse-backend gardenhouse-frontend

# Обновление кода (без установки служб)
./deploy/deploy.sh

# Обновление кода + переустановка служб/nginx
./deploy/deploy.sh --install-services

# Сертификаты продлеваются автоматически, но можно вручную:
sudo certbot renew

# Проверить, что прослушивается только локально
sudo ss -tlnp | grep -E ':(8000|3000)'
```

---

## 6. Чек-лист "что проверить после деплоя"

- [ ] `curl http://127.0.0.1:8000/api/products/` — Django отвечает JSON.
- [ ] `curl http://127.0.0.1:3000/gardenhouse/ru` — Next.js отвечает HTML (или redirect).
- [ ] `sudo nginx -t` — конфиг валиден.
- [ ] `curl -I https://maintest.site/gardenhouse/ru` — HTTPS работает, код 200.
- [ ] `https://maintest.site/gardenhouse/media/...` — файлы медиа раздаются (если есть).
- [ ] Админка открывается и принимает логин.