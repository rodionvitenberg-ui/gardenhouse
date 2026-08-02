# GardenHouse — Father's Garden

Поместье «Сад Отца»: гостевой дом, питомник многолетних растений, журнал садовода.  
Сайт: [maintest.site/gardenhouse](https://maintest.site/gardenhouse)

---

## Архитектура проекта

Монорепозиторий из двух окружений:

```
gardenhouse/
├── backend/                  # Django REST API (Python)
│   ├── core/                 # настройки, URL, WSGI
│   ├── shop/                 # каталог товаров, заказы
│   ├── guests/               # дома, галерея, бронирования
│   ├── journal/              # журнал садовода
│   ├── scripts/setup_db.sh   # инициализация PostgreSQL из .env
│   └── requirements.txt
├── frontend/                 # Next.js (TypeScript, Tailwind, next-intl)
│   ├── src/app/[locale]/     # страницы с локалями ru/en
│   ├── src/components/       # компоненты по Design System Raus
│   ├── src/lib/api.ts        # axios-клиент к Django API
│   └── next.config.ts        # basePath /gardenhouse, standalone
├── deploy/                   # файлы деплоя на сервер (см. deploy/DEPLOY.md)
└── README.md
```

Фронтенд и бэкенд изолированы: общение только через REST API. Django отдаёт JSON по `/api/`, Next.js рендерит страницы и ходит к API через axios.

---

## Деплой на сервер (актуальная инструкция)

**Подробная инструкция с объяснением каждого шага: [`deploy/DEPLOY.md`](deploy/DEPLOY.md)**

Кратко:

```bash
# На сервере, от пользователя с sudo:
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git wget build-essential software-properties-common
sudo apt install -y python3 python3-venv python3-pip python3-dev libpq-dev \
    nginx certbot python3-certbot-nginx postgresql postgresql-contrib

# Клонирование и запуск деплоя:
cd ~
git clone https://github.com/rodionvitenberg-ui/gardenhouse.git
cd gardenhouse
./deploy/deploy.sh --install-services
```

Скрипт автоматически:
- создаёт виртуальное окружение Python и ставит зависимости бэкенда;
- создаёт базу данных и роль через `backend/scripts/setup_db.sh` (читает пароль из `.env`);
- применяет миграции и сиды;
- собирает Next.js с basePath `/gardenhouse` в standalone-режиме;
- устанавливает systemd-сервисы `gardenhouse-backend` (Gunicorn :8000) и `gardenhouse-frontend` (Next.js :3000);
- настраивает nginx (`/gardenhouse` → Next.js, `/gardenhouse/api|admin` → Django, `/gardenhouse/media` → файлы);
- выпускает SSL-сертификат через certbot;
- перезапускает сервисы.

**Что происходит на сервере:**

```
Интернет
   │
Nginx (порт 80/443) — единственный публичный процесс
   ├── /gardenhouse/*          → Next.js  (127.0.0.1:3000)
   ├── /gardenhouse/api/       → Django   (127.0.0.1:8000)
   ├── /gardenhouse/admin/     → Django   (127.0.0.1:8000)
   └── /gardenhouse/media/     → файлы из backend/media (отдаёт сам nginx)
```

Оба сервиса слушают только `127.0.0.1` и запускаются от пользователя `maintest`, не от root. Принцип наименьших привилегий: наружу открыт только nginx, БД доступна только роли `garden_user` с паролем из `.env`.

## Эксплуатация

```bash
# Логи
journalctl -u gardenhouse-backend  -f --no-pager
journalctl -u gardenhouse-frontend -f --no-pager

# Перезапуск сервисов
sudo systemctl restart gardenhouse-backend gardenhouse-frontend

# Обновление кода (деплой)
./deploy/deploy.sh

# Продление сертификатов (обычно автоматическое)
sudo certbot renew

# Проверка портов (должны слушаться только 8000 и 3000 на localhost)
sudo ss -tlnp | grep -E ':(8000|3000)'
```

Проверка после деплоя:

```bash
curl http://127.0.0.1:8000/api/products/        # Django отвечает JSON
curl -I http://127.0.0.1:3000/gardenhouse/ru    # Next.js отвечает 200
curl -I https://maintest.site/gardenhouse/ru    # HTTPS извне работает
```

---

## Локальная разработка

### Backend (Django)

Все команды выполняются из `backend/`:

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # заполнить DB_* переменные
python manage.py migrate --noinput
python manage.py runserver
```

### Frontend (Next.js)

Все команды выполняются из `frontend/`:

```bash
cd frontend
npm install
cp .env.example .env.local  # NEXT_PUBLIC_API_URL=http://localhost:8000/api
npm run dev
```

---

## Устаревшее: Docker-вариант деплоя

> **Внимание:** ниже описан **предыдущий** способ развёртывания через Docker. Актуальный деплой — без Docker, через systemd-сервисы (см. [`deploy/DEPLOY.md`](deploy/DEPLOY.md)). Docker-файлы и `Makefile` сохранены в репозитории для истории.

### Проблема, которую решает Docker

Представьте: вы написали приложение на своём ноутбуке. Там установлены Python 3.12, Node.js 22, PostgreSQL 16 — и всё работает. Вы переносите приложение на сервер, а там Python 3.10, Node.js 18, PostgreSQL 14. Приложение падает с ошибками.

Это называется «проблема окружения»: код зависит не только от самого кода, но и от версий языка, системных библиотек, базы данных, прав доступа, переменных окружения.

**Docker решает эту проблему радикально**: он упаковывает приложение ВМЕСТЕ со всем его окружением в изолированный контейнер. Этот контейнер работает одинаково на вашем ноутбуке, на сервере и на компьютере коллеги.

| Термин | Что это | Аналогия |
|--------|---------|----------|
| **Образ (Image)** | «Чертеж» приложения | Класс в программировании |
| **Контейнер (Container)** | Запущенный экземпляр образа | Объект класса |
| **Docker Compose** | Оркестрация нескольких контейнеров | Дирижёр оркестра |

### Быстрый старт (Docker)

```bash
make build        # собрать образы
make up           # запустить контейнеры
make migrate      # миграции
make seed         # наполнить базу
make superuser    # создать суперпользователя
make logs         # логи
make down         # остановить
```

Все команды — из корня проекта.

---

## Полезные ссылки

- [Docker Docs](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Next.js](https://nextjs.org/docs)
- [Django](https://docs.djangoproject.com/)
- [Play with Docker](https://labs.play-with-docker.com/) — песочница в браузере