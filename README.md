# Digital Streamers — website

Публичный статический сайт закрытой технической платформы Digital Streamers:
лендинг, страница входа, контакты и юридические страницы. Раздаётся Nginx;
API-заглушки (`/api/login`, `/api/status`, `/api/ping`) остаются в конфигурации Nginx.

Сайт: https://www.digitalstreamers.xyz

## Структура каталогов

```
frontend/                 # публичные статические файлы
  index.html              # главная (лендинг)
  login/index.html        # форма входа
  contacts/index.html
  privacy/index.html
  terms/index.html
  404.html
  robots.txt
  sitemap.xml
  assets/
    config.js             # support email и origin (менять здесь)
    styles.css
    site.js               # навигация, год, email
    app.js                # логика формы входа
    logo.svg / favicon.svg
    fonts/                # локальные woff2 (без CDN)
nginx/                    # конфиги Nginx (Docker + Ansible)
deploy/ansible/           # деплой на узлы
monitoring/               # вспомогательные скрипты мониторинга
```

## Локальный запуск

Требуется Docker.

```bash
make up
# или: docker compose up --build -d
```

Сайт: http://localhost:8080

Остановка: `make down`

Логи: `make logs`

Полная пересборка: `make rebuild`

## Публичные URL

| URL | Описание |
|-----|----------|
| `/` | Лендинг |
| `/login/` | Вход (noindex) |
| `/contacts/` | Контакты |
| `/privacy/` | Privacy Policy |
| `/terms/` | Terms of Use |
| `/robots.txt` | Правила индексации |
| `/sitemap.xml` | Карта сайта |
| `/api/login` | Авторизация (JSON) |
| `/api/status` | Служебный статус узла |
| `/api/ping` | Healthcheck |

## Где менять тексты, email и метаданные

- **Email поддержки** — одно место: `frontend/assets/config.js` (`supportEmail`).
  Скрипт `site.js` подставляет его во все элементы `[data-support-email]`.
  В HTML оставлен fallback `support@digitalstreamers.xyz` на случай отключённого JS.
- **Тексты страниц** — соответствующие HTML-файлы в `frontend/`.
- **Стили и тема** — `frontend/assets/styles.css` (CSS-переменные в `:root`).
- **Метаданные / Open Graph** — секция `<head>` каждой страницы.
- **robots / sitemap** — `frontend/robots.txt`, `frontend/sitemap.xml`.

## Проверка через Docker Compose

```bash
make up
curl -sI http://localhost:8080/ | head -5
curl -sI http://localhost:8080/login/
curl -sI http://localhost:8080/contacts/
curl -sI http://localhost:8080/privacy/
curl -sI http://localhost:8080/terms/
curl -sI http://localhost:8080/no-such-page
curl -s http://localhost:8080/robots.txt
curl -s http://localhost:8080/sitemap.xml
curl -s -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"secret1"}'
```

## Развёртывание

Деплой Ansible на узлы из `deploy/ansible/inventory.ini`:

```bash
make deploy LIMIT=<host-or-group>
make deploy-check LIMIT=<host-or-group>   # dry-run
make status LIMIT=<host-or-group>
```

CI: GitHub Actions (`.github/workflows/build.yml`, `deploy.yml`).
Релиз-хелпер: `make release`.

Подробности по новым серверам: `docs/NEW_SERVER.md`.

## Технические замечания

- Без npm/React/Vue: только HTML, CSS и небольшой JS.
- Шрифты и иконки лежат в репозитории, CDN не используются.
- Красивые URL (`/login/`, `/contacts/`, …) обслуживаются через `try_files $uri $uri/ =404`
  и `index.html` в соответствующих каталогах.
- Кастомная страница 404 настроена в `nginx/server-includes/30-ds-web.conf`.
