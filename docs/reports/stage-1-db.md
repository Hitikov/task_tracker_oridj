# Отчёт: поток БД этапа 1

- **Дата:** 21.11.2026
- **Ветка агента:** `agent/stage-1-db` (head `d1d734e`)
- **Влито в этап:** `d92e8a0`, draft PR [#21](https://github.com/Hitikov/task_tracker_oridj/pull/21)
- **Модель:** `opencode/tidepool-alpha-free#max` (DeepSeek Free упёрся в лимит)

## Что сделано

- Миграции только вперёд: `0000_schema_migrations.sql`, `0001_users.sql`,
  `0002_projects.sql`, `0003_project_members.sql` — строго по `docs/architecture.md`.
- `server/lib/src/db/database.dart` — пул по `AppConfig`, `open()/close()`,
  `query()/transaction()`.
- `server/lib/src/db/migration_runner.dart` — поиск `NNNN_*.sql`, проверка
  нумерации (без пропусков и дублей), таблица `schema_migrations`, применение
  каждой миграции в транзакции, идемпотентность, разрешение каталога через
  `MIGRATIONS_DIR` / путь рядом с исполняемым файлом.
- `bin/server.dart` — пул → миграции → HTTP; `APPLY_MIGRATIONS=false` позволяет
  поднять сервер без БД; `/health` не обращается к PostgreSQL.
- `Dockerfile` — миграции копируются в образ, `MIGRATIONS_DIR=/app/migrations`.
- Тесты: `migrations_test.dart`, `migration_runner_helpers_test.dart`,
  `migrations_integration_test.dart` (skip без живой БД).

## Найденные и исправленные проблемы

1. `COPY --from=build /runtime/ /` падал при сборке: в Debian bookworm `/lib` —
   симлинк на `usr/lib`. Строка удалена — AOT-бинарнику хватает системных
   библиотек `debian:bookworm-slim`.
2. Драйвер `postgres` по умолчанию требует SSL. Локальный PostgreSQL в compose
   работает без TLS — добавлен `PoolSettings(sslMode: SslMode.disable)`.

## Проверки

### Локальные

```text
dart pub get                              OK
dart format --set-exit-if-changed .        20 файлов, 0 изменений
dart analyze                               No issues found
dart test                                  36 passed, 1 skipped (интеграционный)
git diff --check                           exit 0
```

### На живом Docker

Docker Desktop 29.9.3, Compose v5.7.0. Команды выполнялись в worktree потока.

```text
docker compose config --quiet              OK
docker compose up -d --build               образ собран, сервисы healthy
GET http://localhost:8080/health           200 {"status":"ok",...}
select * from schema_migrations            4 записи (0000..0003)
\dt                                        users, projects, project_members, schema_migrations
\d users                                   citext email, UNIQUE, CHECK name 1..100, gen_random_uuid()
pg_indexes(project_members)               pkey, idx_user_id, uq_project_members_owner (WHERE role='owner')
```

Проверки ограничений на данных:

- повторный owner проекта → `uq_project_members_owner` — ожидаемо;
- ключ проекта в нижнем регистре → `projects_key_check` — ожидаемо;
- email в другом регистре → `users_email_key` (citext) — ожидаемо.

Идемпотентность: `docker compose restart server` → сервер поднимается заново,
строк «Миграция применена» в логах нет, `/health` = 200.

Финал: `docker compose down -v` — контейнеры, сеть и том `arij_pgdata` удалены.

## Ограничения

- Интеграционный тест в CI ещё не подключён к PostgreSQL — этим занимается
  поток `agent/stage-1-ci`.
- Живая проверка выполнялась с dev-значениями из `.env.example`
  (`JWT_SECRET` — placeholder); для продакшена нужен настоящий секрет.
