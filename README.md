# GardenHouse — Father's Garden

Гостевой дом + питомник.  
**Прод (тест):** [http://maintest.site/gardenhouse](http://maintest.site/gardenhouse)  
Локали: **ru** (default), **en**.

---

## Стек

- **backend/** — Django REST + admin (Gunicorn)
- **frontend/** — Next.js 16 + next-intl + Tailwind (`basePath=/gardenhouse` в prod)
- **deploy/** — установка на Webdock/Ubuntu только скриптами

---

## Деплой на чистый сервер (Webdock)

Пользователь профиля (часто `maintest`) имеет primary group **`sudo`**, не `maintest`.  
Скрипты это учитывают автоматически.

```bash
sudo mkdir -p /var/www
sudo git clone https://github.com/rodionvitenberg-ui/gardenhouse.git /var/www/gardenhouse
cd /var/www/gardenhouse

# must show: "build": "next build --webpack"
grep build frontend/package.json

sudo bash deploy/install.sh          # всё: пакеты, БД, webpack-build, nginx, systemd
# sudo bash deploy/install.sh --skip-ufw

# когда DNS A → этот сервер:
sudo bash deploy/setup_ssl.sh
```

Переустановка с нуля (если предыдущий деплой «поехал»): снести `/var/www/gardenhouse` + units, снова clone + `install.sh` — см. [deploy/DEPLOY.md](deploy/DEPLOY.md).

Сайт до SSL: **`http://maintest.site/gardenhouse`**  
После SSL: **`https://maintest.site/gardenhouse`**

Обновления:

```bash
sudo bash /var/www/gardenhouse/deploy/deploy.sh
```

Подробности: **[deploy/DEPLOY.md](deploy/DEPLOY.md)**  
Диагностика: `sudo bash deploy/healthcheck.sh`

---

## Локальная разработка

```bash
# Backend
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python manage.py migrate && python manage.py runserver

# Frontend (без basePath)
cd frontend
npm install
cp .env.example .env.local   # NEXT_PUBLIC_API_URL=http://localhost:8000/api
npm run dev
```

Локально: `http://localhost:3000/ru`

---

## Сервисы на сервере

| Unit | Порт |
|------|------|
| `gardenhouse-backend` | 127.0.0.1:8000 |
| `gardenhouse-frontend` | 127.0.0.1:3000 |
| `nginx` | 80 / 443 → `/gardenhouse` |
