# GardenHouse — Father's Garden

Поместье «Сад Отца»: гостевой дом, питомник многолетних растений, журнал садовода.

**Прод (тест-домен):** [https://maintest.site/gardenhouse](https://maintest.site/gardenhouse)  
Локали: **ru** (по умолчанию), **en** → `/gardenhouse/ru`, `/gardenhouse/en`.

---

## Архитектура

```
gardenhouse/
├── backend/                  # Django REST API + admin
│   ├── core/                 # settings, urls, wsgi
│   ├── shop/ guests/ journal/
│   ├── scripts/setup_db.sh
│   └── requirements.txt
├── frontend/                 # Next.js 16 + next-intl + Tailwind
│   ├── src/app/[locale]/     # страницы ru/en
│   ├── src/i18n/             # routing, navigation, messages
│   ├── src/lib/api.ts        # axios → Django
│   └── next.config.ts        # basePath из NEXT_PUBLIC_BASE_PATH
├── deploy/                   # скрипты деплоя (см. deploy/DEPLOY.md)
└── README.md
```

Фронт и бэк общаются только через REST. На проде nginx отдаёт всё под `/gardenhouse`.

---

## Деплой на сервер (скриптами)

Подробно: **[`deploy/DEPLOY.md`](deploy/DEPLOY.md)**.

На сервере (sudo), один раз:

```bash
git clone https://github.com/rodionvitenberg-ui/gardenhouse.git
cd gardenhouse

sudo bash deploy/setup_server.sh   # nginx, postgres, node, pm2, user maintest
sudo bash deploy/create_db.sh      # БД gardenhouse_db
sudo bash deploy/deploy.sh         # build + migrate + сервисы + nginx
sudo bash deploy/setup_ssl.sh      # Let's Encrypt (когда DNS готов)
```

Обновление кода:

```bash
sudo bash /var/www/gardenhouse/deploy/deploy.sh
```

### Схема трафика

```
Интернет → Nginx (80/443)
             ├── /gardenhouse/api|admin  → Gunicorn :8000
             ├── /gardenhouse/media|static → файлы
             └── /gardenhouse/*          → Next.js :3000 (next-intl)
```

Приложение лежит в `/var/www/gardenhouse`, процессы — от пользователя `maintest`.

### Проверка

```bash
curl -I https://maintest.site/gardenhouse/ru
curl    https://maintest.site/gardenhouse/api/products/
```

Логи:

```bash
sudo journalctl -u gardenhouse-backend -f --no-pager
sudo -u maintest bash -c 'export PM2_HOME=/home/maintest/.pm2; pm2 logs gardenhouse-frontend'
```

---

## Локальная разработка

### Backend

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python manage.py migrate --noinput
python manage.py runserver
```

### Frontend

```bash
cd frontend
npm install
cp .env.example .env.local   # NEXT_PUBLIC_API_URL=http://localhost:8000/api
npm run dev
```

Локально **без** basePath: `http://localhost:3000/ru`.

На проде basePath `/gardenhouse` задаётся через `frontend/.env.production` (см. `.env.production.example`).

---

## Полезные ссылки

- [Next.js](https://nextjs.org/docs)
- [next-intl](https://next-intl.dev/)
- [Django](https://docs.djangoproject.com/)
- [PM2](https://pm2.keymetrics.io/)
