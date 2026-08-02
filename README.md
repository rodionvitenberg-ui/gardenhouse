# GardenHouse — Father's Garden

Поместье «Сад Отца»: гостевой дом, питомник многолетних растений, журнал садовода.  
Сайт: [maintest.site/gardenhouse](https://maintest.site/gardenhouse)

---

## Что такое Docker и зачем он нужен

### Проблема, которую решает Docker

Представьте: вы написали приложение на своём ноутбуке. Там установлены Python 3.12, Node.js 22, PostgreSQL 16 — и всё работает. Вы переносите приложение на сервер, а там Python 3.10, Node.js 18, PostgreSQL 14. Приложение падает с ошибками. Знакомо?

Это называется «проблема окружения»: код зависит не только от самого кода, но и от версий языка, системных библиотек, базы данных, прав доступа, переменных окружения.

**Docker решает эту проблему радикально**: он упаковывает приложение ВМЕСТЕ со всем его окружением в изолированный контейнер. Этот контейнер работает одинаково на вашем ноутбуке, на сервере и на компьютере коллеги.

### Три ключевых понятия

| Термин | Что это | Аналогия |
|--------|---------|----------|
| **Образ (Image)** | «Чертеж» приложения: ОС, библиотеки, ваш код — упаковано в неизменяемый слой | Класс в программировании |
| **Контейнер (Container)** | Запущенный экземпляр образа — изолированный процесс со своей файловой системой, сетью, env | Объект класса |
| **Docker Compose** | Инструмент для запуска нескольких контейнеров, которые работают вместе | Дирижёр оркестра |

---

## Архитектура на сервере (Ubuntu 24.04, 2GB RAM)

```
                    ┌─────────────────────────────┐
                    │   Пользователь (браузер)    │
                    └─────────────┬───────────────┘
                                  │ 443 (HTTPS)
                    ┌─────────────▼───────────────┐
                    │  Хостовой nginx (systemd)  │
                    │  - SSL (certbot)            │
                    │  - маршрутизация проектов   │
                    │  /gardenhouse → Docker      │
                    │  /project2 → (будущее)      │
                    └─────────────┬───────────────┘
                                  │ 127.0.0.1:8080
                    ┌─────────────▼───────────────┐
                    │  Docker nginx (контейнер)   │
                    │  - статика/медиа            │
                    │  - прокси frontend/backend  │
                    └──────┬──────────────┬───────┘
                           │              │
              ┌────────────▼────┐  ┌──────▼────────────┐
              │ frontend:3000   │  │ backend:8000      │
              │ (Next.js SSR)   │──│ (Django/Gunicorn) │
              └─────────────────┘  └──────┬────────────┘
                                          │ host.docker.internal
                              ┌───────────▼────────────┐
                              │  Хостовой PostgreSQL   │
                              │  (systemd, :5432)      │
                              └────────────────────────┘
```

**В чем смысл двух nginx?**

Хостовой nginx — «диспетчер» всего сервера. Он принимает запросы снаружи (порты 80/443), терминирует SSL и решает, какому проекту адресовать запрос (`/gardenhouse`, позже `/project2`). Чтобы на одном сервере жило несколько проектов.

Docker nginx — «внутренний» nginx проекта. Он слушает только `127.0.0.1:8080` (не доступен извне), проксирует на frontend/backend и раздаёт статику напрямую из вольюмов. Такой подход позволяет не конфликтовать за порты 80/443.

**Почему PostgreSQL не в Docker?**

На сервере **уже установлен** хостовой PostgreSQL (через systemd) с данными проекта. Поднимать второй PostgreSQL в контейнере — значит тратить ~150 MB оперативки из 2 GB и рисковать расхождением данных. Поэтому бэкенд подключается к хостовому PostgreSQL через `host.docker.internal`.

**Бюджет памяти (итого ~620 MB из 2 GB):**

| Сервис | Память | Способ |
|--------|--------|--------|
| backend (Gunicorn) | ~350 MB | 2 воркера + `--preload` |
| frontend (Next.js) | ~250 MB | standalone-вывод |
| Docker nginx | ~20 MB | Alpine, 1 воркер |

Остаётся **1.4 GB** для системы и будущего второго проекта.

---

## Команды управления

Все команды выполняются из корня проекта (`/var/www/gardenhouse`).

### Жизненный цикл

| Команда | Что делает |
|---------|-----------|
| `make build` | Собрать Docker-образы заново |
| `make up` | Запустить все контейнеры в фоне |
| `make down` | Остановить все контейнеры |
| `make restart` | Перезапустить все контейнеры |
| `make clean` | Полная остановка + удаление образов и томов |

### Мониторинг

| Команда | Что делает |
|---------|-----------|
| `make ps` | Список запущенных контейнеров |
| `make health` | Статус контейнеров |
| `make stats` | Потребление CPU/RAM в реальном времени |
| `make logs` | Логи всех сервисов (Ctrl+C — выход) |
| `make logs-backend` | Логи только бэкенда |
| `make logs-frontend` | Логи только фронтенда |
| `make logs-nginx` | Логи только Docker-nginx |

### Django

| Команда | Что делает |
|---------|-----------|
| `make migrate` | Применить миграции |
| `make seed` | Наполнить базу данными |
| `make superuser` | Создать суперпользователя |
| `make collectstatic` | Пересобрать статику |

### Доступ внутрь контейнеров

| Команда | Что делает |
|---------|-----------|
| `make shell-backend` | bash в контейнере backend |
| `make shell-frontend` | shell в контейнере frontend |
| `make shell-nginx` | shell в контейнере nginx |
| `make shell-db` | psql в **хостовой** PostgreSQL |
| `make check-db` | Проверить доступность PostgreSQL |

### Очистка (важно для 15 GB диска!)

| Команда | Что делает |
|---------|-----------|
| `make prune` | Удалить все неиспользуемые образы, контейнеры, тома, кэш сборки |

После каждой пересборки остаются «dangling» образы `<none>:<none>` и кэш сборки. Они съедают гигабайты диска. Автоматическая очистка настроена через cron (каждое воскресенье в 3:00), но можно запустить и вручную.

---

## Шпаргалка Docker

```bash
# Контейнеры
docker ps                # запущенные
docker ps -a             # все
docker stop <name>       # остановить
docker start <name>      # запустить
docker restart <name>    # перезапустить
docker rm <name>         # удалить
docker logs -f <name>    # логи в реальном времени
docker exec -it <name> bash  # войти внутрь

# Образы
docker images            # список
docker pull alpine       # скачать
docker rmi <image>       # удалить
docker system df         # сколько места занимает Docker

# Очистка
docker container prune        # остановленные контейнеры
docker image prune -a         # неиспользуемые образы
docker volume prune           # неиспользуемые тома
docker system prune -a --volumes --force   # всё сразу (агрессивно)
```

---

## Деплой на сервер (полная инструкция)

### Шаг 0. Подготовка (один раз)

На сервере Ubuntu 24.04:

```bash
# 1. Установить Docker
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # права без sudo (перелогиниться после)

# 2. Проверить PostgreSQL и nginx
sudo systemctl status postgresql
sudo systemctl status nginx

# 3. Проверить, что старые systemd-сервисы остановлены (deploy.sh сделает это автоматически)
# Но если хотите вручную:
sudo systemctl stop gardenhouse-backend gardenhouse-frontend
sudo systemctl disable gardenhouse-backend gardenhouse-frontend
```

### Шаг 1. Разместить код на сервере

```bash
sudo mkdir -p /var/www/gardenhouse
sudo chown $USER:$USER /var/www/gardenhouse
cd /var/www/gardenhouse

# Скопировать файлы проекта (git clone или rsync с локальной машины)
git clone https://github.com/rodionvitenberg-ui/gardenhouse.git .
```

Если локальная разработка — проще заливать через rsync/SFTP:

```bash
# С локальной машины
rsync -avz --exclude node_modules --exclude .next --exclude venv \
  ./ user@maintest.site:/var/www/gardenhouse/
```

### Шаг 2. Настроить переменные окружения

```bash
cd /var/www/gardenhouse
cp deploy/.env.production .env.production
nano .env.production
```

Обязательно замените:
- `DJANGO_SECRET_KEY` — случайная строка (команда: `python3 -c "import secrets; print(secrets.token_hex(32))"`)
- `DB_PASSWORD` — пароль для PostgreSQL

### Шаг 3. Запустить деплой

```bash
sudo bash deploy/deploy.sh
```

Скрипт автоматически:
- проверяет Docker, Compose, PostgreSQL, nginx
- **останавливает старые systemd-сервисы** (освобождает ~600 MB RAM)
- создаёт роль `garden_user` и базу `garden_db` в PostgreSQL (если нет)
- собирает Docker-образы (`docker compose build`)
- запускает контейнеры (`docker compose up -d`)
- ждёт готовности backend
- обновляет хостовой nginx конфиг (`deploy/nginx/maintest.site.conf`)
- применяет миграции + seed
- настраивает еженедельную очистку Docker через cron

### Шаг 4. Проверить

```bash
make ps          # контейнеры работают
make health      # все healthy
curl http://127.0.0.1:8080/gardenhouse/en   # внутренняя проверка (должен вернуть HTML)
```

Откройте в браузере: **https://maintest.site/gardenhouse**  
(если SSL ещё не настроен — http://maintest.site/gardenhouse)

Локализация:
- `/gardenhouse` → редирект на язык браузера (ru/en)
- `/gardenhouse/ru` — русская
- `/gardenhouse/en` — английская

Админка: `/gardenhouse/admin/`

### Обновление кода после изменений

```bash
cd /var/www/gardenhouse
git pull                    # забрать новые коммиты
make build                  # пересобрать образы
make up                     # перезапустить контейнеры
make migrate                # миграции, если были изменения моделей
```

Или просто повторно: `sudo bash deploy/deploy.sh`

---

## Добавление второго проекта на этот же сервер

1. Создайте `/var/www/project2` со своим `docker-compose.yml`.
2. Убедитесь, что его внутренний nginx слушает **другой порт** (например, `127.0.0.1:8081`).
3. В хостовом nginx добавьте location для второго проекта:

```nginx
location ^~ /project2 {
    proxy_pass http://127.0.0.1:8081;
    # ... те же proxy_set_header ...
}
```

4. `sudo nginx -t && sudo systemctl reload nginx`

Порты 80/443 разделяет хостовой nginx, поэтому проекты не конфликтуют.

---

## Структура файлов деплоя

```
deploy/
├── docker/
│   ├── Dockerfile.backend     # Django + Gunicorn (multi-stage)
│   ├── Dockerfile.frontend    # Next.js standalone (multi-stage)
│   ├── entrypoint.sh          # wait-db → migrate → collectstatic → gunicorn
│   ├── nginx.conf             # Внутренний nginx (1 воркер, gzip, лимиты)
│   └── nginx-site.conf        # Роутинг /gardenhouse внутри Docker
├── nginx/
│   └── maintest.site.conf     # Хостовой nginx: SSL + роутинг на :8080
├── deploy.sh                  # Скрипт установки на сервер
├── .env.production            # Шаблон переменных окружения
├── systemd/                   # [Устаревшее] старый bare-metal деплой
└── pm2/                       # [Устаревшее] старый PM2 конфиг
docker-compose.yml             # Оркестрация контейнеров
Makefile                       # Команды управления
.dockerignore                  # Что не попадает в сборку
README.md                      # Этот файл
```

---

## Устранение неполадок

### Backend не поднимается

```bash
make logs-backend
```

Типичные причины:
- PostgreSQL не доступен → проверьте: `make check-db`
- Пароль не совпадает → проверьте `DB_PASSWORD` в `.env.production`
- База не создана → `sudo bash deploy/deploy.sh` ещё раз (создаст)

### Frontend отдаёт 502

```bash
make logs-frontend
# Или проверьте изнутри:
curl http://127.0.0.1:8080/gardenhouse/en
```

### Сайт открывается, но нет картинок

Проверьте media-директорию на хосте:

```bash
ls -la /var/www/gardenhouse/backend/media/
```

Если в контейнере поменялись права — восстановите: `sudo chown -R www-data:www-data /var/www/gardenhouse/backend/media`

### Закончилось место

```bash
docker system df           # сколько занимает Docker
make prune                 # агрессивная очистка
sudo journalctl --vacuum-size=100M   # очистить systemd-логи
```

---

## Часто задаваемые вопросы

### Чем Docker отличается от виртуальной машины?

ВМ эмулирует железо и запускает целую ОС с ядром (гигабайты). Docker-контейнер разделяет ядро хоста и изолирует только процессы/файловую систему. Контейнер стартует за секунды и ест мегабайты.

### Нужно ли знать Docker для управления?

Обычно достаточно команд `make ...`. Но понимание (образ, контейнер, том, compose) поможет при отладке.

### Можно ли запустить без Docker?

Да — на сервере это уже было сделано раньше через systemd (файлы в `deploy/systemd/`). Но Docker надёжнее: изолированная среда, лимиты памяти, авто-рестарт, лёгкий откат версий.

### Как обновить только backend?

```bash
docker compose up -d --build backend
```

### Почему entrypoint применяет миграции как root?

Контейнер запускается от root, потом entrypoint делает миграции и запускает Gunicorn. Отдельный непривилегированный пользователь в контейнере возможен, но для продакшн-простоты и прав на медиа-вольюм оставлен root. Docker-изоляция достаточна.

---

## Полезные ссылки

- [Docker Docs](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Play with Docker](https://labs.play-with-docker.com/) — песочница в браузере