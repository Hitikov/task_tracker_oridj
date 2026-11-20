# Отчёт: этап 0 — фундамент

- **Дата:** 21.11.2026
- **Ветка:** `feature/stage-0-foundation`
- **PR:** [#19](https://github.com/Hitikov/task_tracker_oridj/pull/19)
- **План:** [ROADMAP](../ROADMAP.md)
- **Статус:** завершён, влит в `main` (`cdd8cc2`, PR #19)

## Итог

Этап 0 закрыт: репозиторий очищен, зафиксированы архитектура и REST-контракт,
появился собираемый серверный пакет `server/`, локальное окружение Docker Compose
с PostgreSQL 16 и backend-job в CI. Продуктовой логики (auth, проекты, задачи)
пока нет — она начинается на этапе 1.

## Что сделано по потокам

| № | Поток | Ветка | HEAD | Результат |
|---|---|---|---|---|
| 1 | Гигиена репозитория | `agent/stage-0-repo-hygiene` | `9ef8a35` | `.env`, `.idea/`, `*.iml` вне индекса; README, CONTRIBUTING, шаблоны issue/PR |
| 2 | ADR + OpenAPI | `agent/stage-0-adr-api` | `64e377c` | ADR-0001, OpenAPI 3.1.0, `docs/architecture.md` |
| 3 | Каркас сервера | `agent/stage-0-server-skeleton` | `e68b2a2` | пакет `arij_server`, `/health`, конфиг, CORS, логирование, тесты, `Dockerfile` |
| 4 | Docker + PostgreSQL | `agent/stage-0-docker` | `8954053` | `docker-compose.yml`, `.env.example`, `scripts/*.ps1`, `docs/local-dev.md` |
| 5 | Backend CI | `agent/stage-0-ci` | `47bcb98` | job `backend` (format/analyze/test) в CI и Release |

Все ветки проверены и влиты merge-коммитами в `feature/stage-0-foundation`:

```text
4789d30 merge: Docker Compose, PostgreSQL и локальные скрипты (поток 4)
d093217 merge: каркас сервера arij_server (поток 3)
07de7b9 merge: ADR, OpenAPI-контракт и архитектура (поток 2)
951dbc5 merge: repo hygiene and docs (поток 1)
1ce88a4 merge: backend CI (поток 5)
0b19f4f chore: убрать серверные зависимости из клиента
```

## Ключевые артефакты

- `docs/adr/0001-backend-stack.md` — `shelf` + `shelf_router` + `postgres` +
  SQL-миграции; Drift только локальный кэш клиента; пароли Argon2id/bcrypt.
- `docs/api/openapi.yaml` — OpenAPI 3.1.0: 8 путей, 12 схем, `bearerAuth`,
  единый конверт ошибок `{"error":{"code","message","details"}}`.
- `docs/architecture.md` — контекст системы, слои `routes → services →
  repositories → db`, схема БД этапа 1, разделение `task_kind`/`task_type`.
- `server/` — `arij_server` 0.1.0: строгая валидация env, requestId, CORS,
  логирование, `GET /health`, 19 тестов, multi-stage `Dockerfile`.
- `docker-compose.yml` — PostgreSQL 16 + сервер, healthcheck'и, named volume,
  `depends_on: service_healthy`, секреты только из `.env`.
- `.github/workflows/ci.yml` — job `backend`: `dart format` / `dart analyze` /
  `dart test` для `server/`.

## Проверки

| Проверка | Результат |
|---|---|
| `dart format --set-exit-if-changed .` в `server/` | 0 изменений |
| `dart analyze` в `server/` | No issues found |
| `dart test` в `server/` | 19 тестов, все зелёные |
| `flutter analyze` | No issues found |
| `flutter test` | 26 тестов, все зелёные |
| `GET /health` живым запуском | 200, `application/json; charset=utf-8`, поля по контракту |
| 404 / 405 / OPTIONS preflight | единый формат ошибок, 204 + CORS-заголовки |
| YAML (OpenAPI, compose, workflows, issue templates) | 6 файлов, парсятся |
| PowerShell-скрипты | 5 файлов, разбор `Parser::ParseFile` без ошибок |
| `git diff --check` | чисто |

## Отклонения и ограничения

1. **Docker локально не установлен.** `docker compose config`, сборка образа и
   реальный `docker compose up` не выполнялись. Compose проверен парсером YAML и
   структурными assert'ами; Dockerfile проверен вручную. Первый реальный запуск
   нужно сделать на машине с Docker.
2. **`actionlint` локально отсутствует.** Workflows проверены парсером YAML и
   зелёным прогоном CI в GitHub.
3. **Build context сервера — `./server`.** `server/Dockerfile` копирует
   `pubspec.yaml`, `bin/` и `lib/` относительно контекста, поэтому compose
   использует `context: ./server`, а не корень репозитория.
4. **`.env` остаётся в истории git.** Файл убран из индекса и игнорируется, но
   старые коммиты его содержат (там были placeholder-значения). Перед публичным
   релизом нужна ротация секретов и, при необходимости, очистка истории.
5. **Сроки сдвинуты на 4 дня.** Этап 0 завершён 21.11 вместо 17.11; новые даты
   этапов 1–5 зафиксированы в [ROADMAP](../ROADMAP.md).
6. **CI падал на анализе корня.** `flutter analyze` в корневом пакете подхватывал
   файлы `server/` без их пакетного контекста (154 ошибки). Исправлено исключением
   `server/**` в корневом `analysis_options.yaml`; пакет проверяется job'ом
   `backend`.

## Следующий шаг

Этап 1 — `feature/stage-1-auth-projects` (22–28 ноября):

- миграции `users`, `projects`, `project_members`;
- регистрация, вход, `GET /api/v1/auth/me`, JWT;
- CRUD проектов и участников;
- `ApiClient` на `dio`, хранение токена, экраны входа и проектов;
- интеграционные тесты с PostgreSQL в CI.
