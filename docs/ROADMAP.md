# Arij — план развития

> Актуально на 21.11.2026. Этот файл — единая точка входа для любой сессии.
> Статусы этапов и журнал обновляются по мере выполнения.

## 1. Где проект сейчас

| Область | Состояние |
|---|---|
| Репозиторий | `Hitikov/task_tracker_oridj`, `main` = `5606cfc` |
| Релизы | `v1.1.0` — APK + AAB + Windows zip + `SHA256SUMS.txt`; `v1.0.0` — Windows |
| CI/CD | `lint → test + backend (PostgreSQL service) → build-android + build-windows`; Release по тегу `v*` |
| Тесты | 140 серверных + 48 клиентских, зелёные |
| Клиент | `ApiClient` (dio), `flutter_secure_storage`, Riverpod, экраны входа/регистрации/проектов; демо-вход за флагом `DEMO_MODE` |
| Backend | `arij_server`: `/health`, миграции, JWT/Argon2id auth, CRUD проектов и участников; единый формат ошибок |
| Docker | `docker-compose.yml` с PostgreSQL 16 + сервер, скрипты `scripts/dev-*.ps1`, `docs/local-dev.md` |
| Issues | 10 открытых, размечены labels и milestones |
| Документы | `docs/MVP.md`, `docs/ROADMAP.md`, `docs/architecture.md`, ADR-0001, OpenAPI 3.1, отчёты `docs/reports/stage-0.md`, `stage-1.md` |

**Главный разрыв:** этап 1 завершён — реальная авторизация и проекты работают
через REST API и PostgreSQL. Следующий критический путь — задачи, иерархия
Epic/Task/Subtask и Backlog (этап 2).

## 2. Принципы

1. **Вертикальные срезы.** Каждый этап даёт демонстрируемый сценарий, а не слой
   «сначала весь backend, потом весь frontend».
2. **Contract-first.** OpenAPI и схема БД фиксируются до параллельной работы.
3. **Один этап — одна ветка.** Ветка этапа создаётся от актуального `main`.
4. **PR + зелёный CI.** В `main` попадает только проверенный код.
5. **Scope freeze.** AI/MCP, Reports, Calendar, Timeline, real-time — только post-MVP.
6. **Секреты — только в env.** `.env` не коммитится; в репозитории лежит `.env.example`.

## 3. Ветки и этапы

| Этап | Ветка | Срок | Результат | Статус |
|---|---|---|---|---|
| 0. Фундамент | `feature/stage-0-foundation` | 16–21 ноября | чистый репозиторий, ADR, OpenAPI, `server/`, Docker, backend CI | завершён |
| 1. Auth → проекты | `feature/stage-1-auth-projects` | 22–28 ноября | регистрация → вход → создание проекта → данные в PostgreSQL | завершён |
| 2. Задачи → Backlog | `feature/stage-2-tasks-backlog` | 29 ноября – 5 декабря | Epic/Task/Subtask, номер, исполнитель, дедлайн, Backlog | в работе |
| 3. Kanban | `feature/stage-3-kanban` | 6–12 декабря | колонки, drag & drop, смена статуса | в работе |
| 4. Полировка MVP | `feature/stage-4-mvp-polish` | 13–19 декабря | роли, валидация, тесты, документация | запланирован |
| 5. Релиз 2.0.0 | `feature/stage-5-release-2.0.0` | 20–26 декабря | APK/AAB/Windows/Web, подпись, GitHub Release | запланирован |

Буфер: 27–31 декабря — исправление ошибок по итогам демо, без новых функций.
Сроки сдвинуты на 4 дня относительно первой версии плана: этап 0 завершён 21.11.

## 4. Этап 0 — фундамент

### Цель

Подготовить репозиторий и каркас серверной части так, чтобы этап 1 начинался
с готового контракта, пакета `server/`, локального PostgreSQL и CI.

### Пять параллельных потоков

Для этапа 0 запускаются 5 агентов на модели
**DeepSeek V4.1 Flash Free Max** (`opencode/deepseek-v4.1-flash-free#max`).
Каждый агент работает в отдельном worktree и отдельной ветке, затем изменения
ревьюятся и вливаются в `feature/stage-0-foundation`.

| № | Поток | Ветка агента | Зона ответственности | Результат |
|---|---|---|---|---|
| 1 | Гигиена репозитория | `agent/stage-0-repo-hygiene` | `.env`, `.idea`, `*.iml`, `.gitignore`, README, CONTRIBUTING, шаблоны issue/PR | репозиторий без секретов и мусора, понятный quick start |
| 2 | ADR + OpenAPI | `agent/stage-0-adr-api` | `docs/adr/0001-backend-stack.md`, `docs/api/openapi.yaml`, `docs/architecture.md` | зафиксированы стек, схема БД, REST-контракт, формат ошибок |
| 3 | Каркас сервера | `agent/stage-0-server-skeleton` | `server/`: `pubspec.yaml`, `bin/server.dart`, конфиг, логирование, CORS, `/health`, тесты, `Dockerfile` | сервер собирается и отвечает на `/health` |
| 4 | Docker + PostgreSQL | `agent/stage-0-docker` | `docker-compose.yml`, `.env.example`, `scripts/dev-*.ps1`, `docs/local-dev.md` | `docker compose up` поднимает PostgreSQL и сервер |
| 5 | Backend CI | `agent/stage-0-ci` | `.github/workflows/ci.yml` (job `backend`), при необходимости отдельный workflow | CI проверяет format/analyze/test серверного пакета |

### Общий контракт этапа 0

**Серверный пакет:** `server/`, имя пакета `arij_server`, Dart 3.x.

**Стек:** `shelf`, `shelf_router`, `postgres`, `dotenv`, `logging`, `test`.
Клиентский Drift остаётся только локальным кэшем; сервер работает с PostgreSQL
через `postgres` и SQL-миграции.

**Переменные окружения:**

| Переменная | Назначение | Пример |
|---|---|---|
| `SERVER_HOST` | адрес сервера | `0.0.0.0` |
| `SERVER_PORT` | порт сервера | `8080` |
| `DB_HOST` | хост PostgreSQL | `localhost` |
| `DB_PORT` | порт PostgreSQL | `5432` |
| `DB_NAME` | имя БД | `arij` |
| `DB_USER` | пользователь БД | `arij` |
| `DB_PASSWORD` | пароль БД | `arij_dev_password` |
| `JWT_SECRET` | секрет подписи JWT | случайная строка ≥ 32 символов |

**Health-check:** `GET /health` → `200 OK`

```json
{
  "status": "ok",
  "service": "arij-server",
  "version": "0.1.0",
  "time": "2026-11-15T12:00:00.000Z"
}
```

**Формат ошибок:**

```json
{
  "error": {
    "code": "validation_error",
    "message": "Некорректные данные запроса",
    "details": {
      "field": "email"
    }
  }
}
```

**Будущий API (фиксируется в OpenAPI на этапе 0, реализуется на этапе 1):**

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/projects`
- `POST /api/v1/projects`
- `GET /api/v1/projects/{id}`
- `PATCH /api/v1/projects/{id}`
- `DELETE /api/v1/projects/{id}`
- `GET /api/v1/projects/{id}/members`
- `POST /api/v1/projects/{id}/members`
- `DELETE /api/v1/projects/{id}/members/{userId}`

**Аутентификация:** `Authorization: Bearer <JWT>`. Пароли — Argon2id или bcrypt,
не SHA-256.

**Схема БД этапа 1:** `users`, `projects`, `project_members`.
На этапе 2 добавляются `task_types`, `statuses`, `tasks`.

### Definition of Done этапа 0

- `.env`, `.idea/`, `*.iml` не отслеживаются; есть `.env.example`.
- README содержит быстрый старт и структуру проекта.
- ADR-001 и OpenAPI лежат в `docs/`.
- `server/` собирается, `/health` отвечает, есть тест.
- `docker compose up` поднимает PostgreSQL и сервер.
- В CI есть job `backend` с format/analyze/test.
- Все пять веток проверены и влиты в `feature/stage-0-foundation`.
- Написан отчёт `docs/reports/stage-0.md`.

## 5. Этап 1 — Auth → проекты

### Цель

Первый сквозной сценарий: регистрация → вход → создание проекта → проект
сохраняется в PostgreSQL после перезапуска.

### Backend

- Миграции `users`, `projects`, `project_members`.
- Регистрация, вход, `GET /auth/me`; Argon2id/bcrypt, JWT.
- CRUD проектов и участников.
- Валидация, единый формат ошибок, тесты.
- Интеграционные тесты с PostgreSQL в CI.

### Клиент

- `ApiClient` на `dio`, базовый URL через `--dart-define=API_BASE_URL`.
- `flutter_secure_storage` для токена.
- Riverpod (или Bloc — выбрать одно) для состояния сессии.
- Реальные экраны входа и регистрации.
- Экран списка проектов и создание проекта.
- Состояния loading/empty/error.

### Definition of Done

- Пользователь регистрируется, входит и выходит.
- Создаёт проект и видит его после перезапуска приложения.
- Токен хранится безопасно, запросы идут через REST.
- CI зелёный, есть API- и widget-тесты.

## 6. Этап 2 — Задачи → Backlog

### Цель

Создание и просмотр задач в Backlog.

### Backend

- Схема `task_types`, `statuses`, `tasks`.
- Enums `task_priority`, `user_role`, `task_kind`.
- `task_kind` (epic/task/subtask) отдельно от `task_type` (bug/feature/custom).
- Нумерация задач в проекте, иерархия, исполнитель, дедлайн.
- CRUD задач, статусы, типы, валидация, тесты.

### Клиент

- Форма создания/редактирования задачи.
- Backlog с сортировкой и базовой фильтрацией.
- Карточка задачи, удаление, смена полей.
- Тесты.

### Definition of Done

- Можно создать Epic → Task → Subtask.
- Задача получает уникальный номер в проекте.
- Backlog показывает задачи и сохраняет изменения.

## 7. Этап 3 — Kanban

### Цель

Наглядная работа со статусами.

### Backend

- Смена статуса задачи, история переходов (если успеваем).
- API для получения доски.

### Клиент

- Колонки Kanban по статусам.
- Drag & drop, оптимистичное обновление и откат при ошибке.
- Синхронизация с Backlog.

### Definition of Done

- Задача проходит To Do → In Progress → Done.
- Статус сохраняется и виден после перезагрузки.

## 8. Этап 4 — Полировка MVP

### Цель

Довести основной сценарий до стабильного состояния.

### Работы

- Участники и базовые роли (owner/member; расширенные роли — при наличии времени).
- Валидация, состояния loading/empty/error, поиск и фильтры.
- E2E-сценарии, API-тесты, рост покрытия.
- Документация: README, API, архитектура, сценарий демо.
- Фикс `RenderFlex` на 1500×800 и тест на это разрешение.

### Definition of Done

- Основные сценарии MVP проходят без ручных правок.
- Документация готова к защите.
- Критические ошибки исправлены.

## 9. Этап 5 — Релиз 2.0.0

### Цель

Воспроизводимый релиз, который можно показать и установить.

### Работы

- Уникальный `applicationId` вместо `com.example.*`.
- Release-подпись Android через секреты.
- Версия `2.0.0+N`, сборка Web в CI.
- Smoke-тест APK/Windows/Web.
- GitHub Release `v2.0.0` с APK, AAB, Windows zip, Web-архивом и checksums.
- Release notes и сценарий демо.

### Definition of Done

- Релиз опубликован, файлы скачиваются, checksums сходятся.
- APK устанавливается, Windows-архив запускается.
- Демо проходит по сценарию MVP.

## 10. Управление issues

| Сейчас | Действие |
|---|---|
| #3 Backend Infrastructure | оставить эпиком, добавить checklist и labels |
| #5 + #9 | объединить в «Backend skeleton + `/health`» |
| #12 (closed) | переоткрыть как «PostgreSQL в docker-compose для dev/CI» |
| #13 + #14 | объединить в «Подключение к PostgreSQL + env» |
| #6 | оставить как ADR-спайк на 1 день |
| #7 + #8 | объединить в «Миграции: создание и применение» |
| #11 | сделать umbrella/milestone, разбить на конкретные схемы |
| #15 | оставить, разделить `task_kind` и `task_type` |
| Новые | JWT-auth, projects/members, tasks, Kanban, OpenAPI, Docker/Nginx, backend CI, клиентский API-слой, реальный auth, экраны проектов и задач, release signing, RenderFlex, repo hygiene |

Milestones: **MVP: backend**, **MVP: client**, **v2.0.0**.
Labels: `epic`, `backend`, `db`, `api`, `frontend`, `ci`, `docs`, `bug`, `p1`, `p2`.

## 11. Риски

| Риск | Что делать |
|---|---|
| 6 недель, backend с нуля | вертикальные срезы, contract-first, scope freeze |
| Расползание scope | AI/MCP, Reports, Calendar, Timeline, real-time — только post-MVP |
| Безопасность | `.env` вне индекса, Argon2id/bcrypt, демо-вход за флагом |
| Рассогласование команды | labels, milestones, assignees, ежедневная синхронизация, PR-ревью |
| Релизные долги | `applicationId` и release-подпись — до `v2.0.0` |
| Мало тестов на API | PostgreSQL service в CI + интеграционные тесты с этапа 1 |

## 12. Журнал

| Дата | Этап | Что сделано | Ветка/PR |
|---|---|---|---|
| 15.11.2026 | 0 | создан план, запущены 5 агентов | `feature/stage-0-foundation` |
| 21.11.2026 | 0 | влиты все 5 потоков: гигиена, ADR/OpenAPI, `server/`, Docker, CI; проверки зелёные | `feature/stage-0-foundation`, PR #19 |
| 21.11.2026 | 0 | этап 0 влит в `main`; архитектура дополнена картой текущего кода и целевым клиентским слоем | `main` (`cdd8cc2`), PR #19 |
| 21.11.2026 | 1 | создана ветка `feature/stage-1-auth-projects`, начаты миграции и слой БД | `feature/stage-1-auth-projects` |
| 21.11.2026 | 1 | миграции и слой PostgreSQL проверены на живом Docker, влиты в ветку этапа; отчёт `docs/reports/stage-1-db.md` | `d92e8a0` |
| 21.11.2026 | 1 | влиты auth (Argon2id + JWT) и PostgreSQL service в CI; обновлена контрольная точка `docs/reports/stage-1-checkpoint.md` | `dd0bb21` |
| 21.11.2026 | 1 | влиты проекты/участники и аудит зависимостей; роуты подключены; e2e через Docker пройден, CI зелёный | `6344967` |
| 21.11.2026 | 1 | влит клиентский слой (dio, secure storage, Riverpod, экраны); все проверки зелёные | `a18edf8` |
| 21.11.2026 | 1 | этап 1 влит в `main` после зелёного CI (`ebff6de`), PR #21 | `5606cfc` |
| 21.11.2026 | 2 | создана ветка `feature/stage-2-tasks-backlog`, начата работа над задачами | `feature/stage-2-tasks-backlog` |
| 21.11.2026 | 2 | влиты миграции, серверный API и клиентский Backlog; e2e Epic→Task→Subtask пройден; отчёт `docs/reports/stage-2.md` | `847c473` |
| 21.11.2026 | 3 | создана ветка `feature/stage-3-kanban`, начата работа над доской | `feature/stage-3-kanban` |
