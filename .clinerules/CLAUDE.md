# Hardware E-Commerce Platform

## 🏗 Project Structure
A classic monorepo architecture:
* `./frontend/` — Next.js storefront for browsing and purchasing computer hardware.
* `./backend/` — Django REST API handling product catalog, inventory, users, and orders. PostgreSQL is the primary database. Redis may be used for caching or session management.

## 💻 Development Commands (Backend)
> **CRITICAL RULE:** All backend commands MUST be executed from the `./backend` directory. 
> To prevent terminal hangs in the AI agent environment, always append `--noinput` to migrations and shell commands.

* **Run Server:** `python manage.py runserver`
* **Make Migrations:** `python manage.py makemigrations --noinput`
* **Migrate:** `python manage.py migrate --noinput`
* **Create Superuser:** `python manage.py createsuperuser --noinput` (requires setting environment variables for credentials if used by AI).

## 💻 Development Commands (Frontend)
> **CRITICAL RULE:** All frontend commands MUST be executed from the `./frontend` directory using `npm`.

* **Install Dependencies:** `npm install <package-name>`
* **Run Dev Server:** `npm run dev`
* **Build Project:** `npm run build`

## 📜 Domain Conventions
1. **Catalog Complexity:** Computer hardware requires flexible specifications. When designing models, account for diverse attributes (e.g., RAM size vs. GPU architecture) without hardcoding every possible spec into direct database columns (consider JSONB or EAV patterns if necessary).
2. **Type Synchronization:** Any changes to Django Serializers MUST be immediately reflected in the corresponding TypeScript interfaces in the `./frontend/` directory.