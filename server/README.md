# Arij Server

Серверная часть Arij на Dart и [shelf](https://pub.dev/packages/shelf).
Сервер подключается к PostgreSQL и применяет SQL-миграции при старте
(`APPLY_MIGRATIONS=true` по умолчанию). `GET /health` не требует аутентификации
и не обращается к БД.

## Требования

- Dart SDK `>=3.9.0 <4.0.0`.
- Docker — только для сборки образа; для локального запуска не нужен.
- PostgreSQL — требуется при запуске по умолчанию;
  `APPLY_MIGRATIONS=false` отключает БД.

## Быстрый старт

```powershell
cd server
dart pub get
dart run bin/server.dart
```

Проверка:

```powershell
curl http://localhost:8080/health
```

```json
{
  "status": "ok",
  "service": "arij-server",
  "version": "0.1.0",
  "time": "2026-11-21T12:00:00.000Z"
}
```

При первом запуске сервер применяет миграции — создаёт таблицы `users`,
`projects`, `project_members` (и `schema_migrations`).

Остановка — `Ctrl+C` (SIGINT).

## Миграции

Файлы `migrations/NNNN_name.sql` — единственный способ менять схему БД.
Они лежат вне `lib/`, чтобы их можно было монтировать/копировать в Docker
и применять отдельной командой в CI.

- Имена соответствуют формату `NNNN_name.sql`; номера без пропусков и
  дублей (проверяется при каждом запуске сервера).
- Применяются только вперёд; идемпотентно — повторный запуск сервера
  безопасен.
- Уже применённые записываются в таблице `schema_migrations`.
- Ручное применение: перезапустите сервер — он применит только
  неприменённые миграции.

## Переменные окружения

Сервер читает `./.env`, затем `../.env` (удобно при запуске из корня
репозитория). Переменные процесса имеют приоритет над файлами. `.env` не
коммитится.

| Переменная | Обязательна | По умолчанию | Назначение |
|---|---|---|---|
| `SERVER_HOST` | нет | `0.0.0.0` | адрес, который слушает сервер |
| `SERVER_PORT` | нет | `8080` | порт сервера (1–65535) |
| `DB_HOST` | да | — | хост PostgreSQL |
| `DB_PORT` | да | — | порт PostgreSQL |
| `DB_NAME` | да | — | имя базы |
| `DB_USER` | да | — | пользователь базы |
| `DB_PASSWORD` | да | — | пароль пользователя базы |
| `JWT_SECRET` | да | — | секрет подписи JWT, не короче 32 символов |
| `MIGRATIONS_DIR` | нет | каталог `migrations` рядом с исполняемым файлом | каталог с SQL-миграциями |
| `APPLY_MIGRATIONS` | нет | `true` | применять миграции при старте (`false` — без БД) |

При ошибке конфигурации сервер печатает список проблем и завершается с
кодом `78` (EX_CONFIG); при ошибке подключения к БД или применения
миграций — с кодом `1`.

Пример `server/.env`:

```dotenv
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
DB_HOST=localhost
DB_PORT=5432
DB_NAME=arij
DB_USER=arij
DB_PASSWORD=arij_dev_password
JWT_SECRET=change-me-to-a-random-string-of-at-least-32-chars
```

## Проверки

```powershell
cd server
dart format --set-exit-if-changed .
dart analyze
dart test
```

Юнит-тесты не требуют PostgreSQL. Интеграционный тест применения миграций
к живой БД (`test/db/migrations_integration_test.dart`) пропускается без
доступной БД.

## Docker

```powershell
docker build -t arij-server ./server

docker run --rm -p 8080:8080 --env-file .env arij-server
```

Образ multi-stage: `dart:stable` собирает AOT-исполняемый файл, runtime —
`debian:bookworm-slim` с `curl` для `HEALTHCHECK` на `/health`. Процесс
запускается от непривилегированного пользователя `arij`. В runtime
пробрасываются `migrations/` (`ENV MIGRATIONS_DIR=/app/migrations`) — сервер
применяет их при старте.

## Структура

```text
server/
├── migrations/
│   ├── 0000_schema_migrations.sql
│   ├── 0001_users.sql
│   ├── 0002_projects.sql
│   └── 0003_project_members.sql
├── bin/server.dart                 # точка входа: env, пул, миграции, запуск
├── lib/
│   ├── arij_server.dart
│   └── src/
│       ├── app.dart
│       ├── config/app_config.dart
│       ├── db/
│       │   ├── database.dart
│       │   └── migration_runner.dart
│       ├── http/
│       ├── routes/health_routes.dart
│       └── version.dart
├── test/                            # тесты конфигурации, пула и миграций
├── Dockerfile
└── pubspec.yaml
```
