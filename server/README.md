# Arij Server

Серверная часть Arij на Dart и [shelf](https://pub.dev/packages/shelf).
На этапе 0 пакет содержит только фундамент: конфигурацию, HTTP-конвейер
(логирование, CORS, единый формат ошибок), `GET /health` и graceful shutdown.
PostgreSQL на этом этапе не подключается — соединение и миграции появятся на
этапе 1.

## Требования

- Dart SDK `>=3.9.0 <4.0.0`.
- Docker — только для сборки образа; для локального запуска не нужен.

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

Остановка — `Ctrl+C` (SIGINT); на Linux/macOS обрабатывается и SIGTERM.

## Переменные окружения

Сервер читает `./.env`, затем `../.env` (удобно при запуске из корня
репозитория). Переменные процесса имеют приоритет над файлами. `.env` не
коммитится.

| Переменная | Обязательна | По умолчанию | Назначение |
|---|---|---|---|
| `SERVER_HOST` | нет | `0.0.0.0` | адрес, который слушает сервер |
| `SERVER_PORT` | нет | `8080` | порт сервера (1–65535) |
| `DB_HOST` | да | — | хост PostgreSQL (на этапе 0 не используется для подключения) |
| `DB_PORT` | да | — | порт PostgreSQL (1–65535) |
| `DB_NAME` | да | — | имя базы |
| `DB_USER` | да | — | пользователь базы |
| `DB_PASSWORD` | да | — | пароль пользователя базы |
| `JWT_SECRET` | да | — | секрет подписи JWT, не короче 32 символов |

Все переменные валидируются при старте. При ошибке сервер печатает список
проблем и завершается с кодом `78` (EX_CONFIG), не раскрывая значения секретов.

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

Тесты не требуют сети и PostgreSQL: handler вызывается напрямую через
`shelf.Request`.

## Docker

```powershell
docker build -t arij-server ./server

docker run --rm -p 8080:8080 --env-file .env arij-server
```

Образ multi-stage: `dart:stable` собирает AOT-исполняемый файл, runtime —
`debian:bookworm-slim` с `curl` для `HEALTHCHECK` на `/health`. Процесс
запускается от непривилегированного пользователя `arij`.

## Структура

```text
server/
├── bin/server.dart              # точка входа: env, запуск, graceful shutdown
├── lib/
│   ├── arij_server.dart         # публичный экспорт buildHandler/AppConfig
│   └── src/
│       ├── app.dart             # Router + Pipeline
│       ├── config/app_config.dart
│       ├── http/                # JSON, ошибки, CORS, request id, логирование
│       ├── routes/health_routes.dart
│       └── version.dart
├── test/                        # тесты конфигурации и HTTP-конвейера
├── Dockerfile
└── pubspec.yaml
```
