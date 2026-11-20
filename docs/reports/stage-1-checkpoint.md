# Контрольная точка: этап 1 (21.11.2026)

> Работа остановлена по просьбе пользователя. Файл фиксирует состояние на момент остановки.

## Состояние репозитория

| Объект | Значение |
|---|---|
| `main` | `04cf9a3` — этап 0 полностью влит (PR #19, PR #20), CI зелёный |
| Ветка этапа | `feature/stage-1-auth-projects`, head `6478db8`, запушена |
| Draft PR | [#21](https://github.com/Hitikov/task_tracker_oridj/pull/21) |
| Локальная копия | переключена на `feature/stage-1-auth-projects`, чистая |
| Worktrees | `stage-1-db`, `stage-1-auth`, `stage-1-projects`, `stage-1-client`, `stage-1-ci` (все от `6478db8`) |

## Что сделано

- Создана ветка этапа 1 и draft PR #21 с чек-листом DoD.
- В `docs/ROADMAP.md` этап 1 отмечен «в работе», добавлена запись в журнал.
- Подготовлены пять worktree для потоков этапа 1.
- Запущен поток «миграции + слой БД» в `agent/stage-1-db`.

## Модели

- `opencode/deepseek-v4.1-flash-free#max` — лимит исчерпан (`Free usage limit reached`), поток прервался до создания файлов.
- Перезапуск на `opencode/tidepool-alpha-free#max` — работает.

## Docker

- Docker Desktop установлен в `C:\Users\Andre\AppData\Local\Programs\DockerDesktop`; CLI не в PATH.
- Полный путь: `C:\Users\Andre\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe`.
- Демон запущен: server `29.9.3`, Compose `v5.7.0`.
- `docker compose config --quiet` проходит; сервисы `postgres`, `server`.
- Локальный `.env` создан из `.env.example` (игнорируется git).
- На момент остановки запущенных контейнеров нет.

## Незавершённый поток БД (`agent/stage-1-db`)

Worktree: `C:\Users\Andre\.local\share\opencode\worktree\7601ed\stage-1-db`
Ветка `agent/stage-1-db` ещё не имеет коммитов; все изменения **незакоммичены** в worktree.

Создано:

- `server/migrations/0000_schema_migrations.sql`
- `server/migrations/0001_users.sql`
- `server/migrations/0002_projects.sql`
- `server/migrations/0003_project_members.sql`
- `server/lib/src/db/database.dart`
- `server/lib/src/db/migration_runner.dart`
- `server/test/db/migrations_test.dart`
- `server/test/db/migration_runner_helpers_test.dart`
- `server/test/db/migrations_integration_test.dart`

Изменено: `server/Dockerfile`, `server/README.md`, `server/bin/server.dart`.

Агент случайно запустил `dart format` из корня worktree и переписал клиентские
файлы, но сразу выполнил `git restore lib test`. На момент остановки `git status`
показывает изменения **только в `server/`**, клиент не затронут.

Агент остановлен по команде, коммиты и пуш не выполнялись.

### Проверки, уже выполненные агентом

- `dart pub get` — OK
- `dart format --set-exit-if-changed .` в `server/` — 1 файл отформатирован
- `dart analyze` — без замечаний
- `dart test` — все тесты зелёные, 1 skipped (интеграционный тест без БД)
- `git diff --check` — exit 0

Не проверено: синтаксис SQL парсером, живые миграции в PostgreSQL, коммиты и пуш.

## Следующие шаги после возобновления

1. Проверить uncommitted-изменения в `stage-1-db` (только `server/`), закоммитить 2–3 коммита и запушить `agent/stage-1-db`.
2. На живой БД: `docker compose up -d --build`, `GET /health`, `psql` → `\dt`, `schema_migrations`, `\d users/projects/project_members`, проверка частичного уникального индекса owner, `compose restart server` на идемпотентность, затем `compose down -v`.
3. Проверить ветку в GitHub и влить в `feature/stage-1-auth-projects`.
4. Запустить потоки `auth` → `projects` → `client` → `ci` (PostgreSQL service в CI).
