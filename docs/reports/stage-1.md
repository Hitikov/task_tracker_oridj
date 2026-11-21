# Отчёт: этап 1 — Auth → проекты

- **Дата:** 21.11.2026
- **Ветка:** `feature/stage-1-auth-projects`
- **PR:** [#21](https://github.com/Hitikov/task_tracker_oridj/pull/21) (draft)
- **План:** [ROADMAP](../ROADMAP.md)
- **Статус:** серверная часть готова; клиентский слой завершается

## Цель этапа

Сквозной сценарий: регистрация → вход → создание проекта → данные сохраняются
в PostgreSQL после перезапуска, при этом клиент работает через REST API.

## Выполнено

| Поток | Результат | Merge |
|---|---|---|
| БД и миграции | `users`, `projects`, `project_members`, `schema_migrations`; пул, раннер миграций, идемпотентность | `d92e8a0` |
| Auth | register/login/me, Argon2id, JWT HS256, bearer middleware, unit-тесты | `1911591` |
| Проекты | CRUD проектов и участников, роли owner/member, 8 хендлеров, 75 тестов | `a0b20c2`, роуты `cde3d76` |
| CI | PostgreSQL 16 service в job `backend`, интеграционный тест миграций реально выполняется | `2552bc0` |
| Зависимости | аудит версий, `cli_util 0.6.1`, `coverage 1.16.1`, отчёт | `d8055c4` |
| Клиент | `dio` + `ApiClient`, secure storage, Riverpod, экраны — завершается | ожидается |

## Контракты API

- `POST /api/v1/auth/register` → 201 `{token, tokenType, expiresIn, user}`
- `POST /api/v1/auth/login` → 200; неверные данные — всегда 401 `invalid_credentials`
- `GET /api/v1/auth/me` → 200 User; без токена — 401 `unauthorized`
- `GET/POST /api/v1/projects` → 200 / 201
- `GET/PATCH/DELETE /api/v1/projects/{id}` → 200 / 200 / 204
- `/members` → 201 при добавлении, 204 при удалении, 403 для не-owner
- дубликат key → 409 `project_key_taken`
- Единый формат ошибок: `{"error":{"code","message","details"}}`

## Проверки

| Проверка | Результат |
|---|---|
| `dart format` / `dart analyze` / `dart test` в `server/` | 140 тестов, 1 skipped локально без БД |
| `flutter analyze` / `flutter test` | 26 тестов (до подключения клиентского слоя) |
| CI на `6344967` | все job зелёные; тест миграций с живой БД без `Skip` |
| Docker e2e | register 201 → project 201 → list/get 200 → member 201 → 403 → 409 → 204 → `/health` 200 |
| `git diff --check` | чисто |

## Ограничения

- `dart_jsonwebtoken` остался на 3.1.x: `argon2 1.0.1` требует `pointycastle ^3.1.2`,
  а версии ≥3.2 требуют `^4.0.0`. Обоснование — в
  [отчёте по зависимостям](stage-1-dependencies.md).
- Клиент пока работает в демо-режиме (`12345/12345`) до завершения потока `client`.
- `.env` остаётся в истории git (placeholder-значения) — ротация секретов перед релизом.
- Демо-вход должен оставаться доступным только за флагом `DEMO_MODE`.

## Следующий шаг

1. Проверить и влить `agent/stage-1-client`.
2. Финальный прогон `flutter analyze/test` + `dart format/analyze/test` + CI.
3. Снять draft с PR #21 и влить в `main`.
4. Перейти к этапу 2 — задачи и Backlog (`feature/stage-2-tasks-backlog`).
