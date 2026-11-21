# Контрольная точка: этап 1 (21.11.2026)

> Текущее состояние этапа 1. Работа возобновлена после паузы; приложение
> запускается на Windows для демонстрации сделанного.

## Состояние репозитория

| Объект | Значение |
|---|---|
| `main` | `04cf9a3` — этап 0 полностью влит (PR #19, PR #20), CI зелёный |
| Ветка этапа | `feature/stage-1-auth-projects`, head `dd0bb21`, запушена |
| Draft PR | [#21](https://github.com/Hitikov/task_tracker_oridj/pull/21) |
| Локальная копия | `feature/stage-1-auth-projects`, чистая |
| Рабочие модели | `opencode/tidepool-alpha-free#max` (DeepSeek Free — лимит исчерпан) |

## Влитые потоки

| Поток | Ветка | Merge | Результат |
|---|---|---|---|
| БД и миграции | `agent/stage-1-db` | `d92e8a0` | 4 миграции, пул, раннер, живая проверка в Docker |
| CI | `agent/stage-1-ci` | `2552bc0` | PostgreSQL service в job `backend`, env для интеграционного теста |
| Auth | `agent/stage-1-auth` | `1911591` | register/login/me, Argon2id + JWT, middleware, 65 тестов |
| Исправление конфига | — | `dd0bb21` | `AppConfig` явно передаётся в `buildHandler()` |

Отчёты: [поток БД](stage-1-db.md), [этап 0](stage-0.md), [план](ROADMAP.md).

## Что проверено

- `dart format` / `dart analyze` / `dart test` в `server/`: 65 тестов, 1 skipped
  (интеграционный тест без БД), ошибок нет.
- `flutter analyze` / `flutter test`: 26 тестов, ошибок нет.
- Docker Desktop 29.9.3 + Compose v5.7.0:
  `compose up -d --build`, `/health` = 200, все 4 миграции применены,
  ограничения БД отклоняют некорректные данные, рестарт идемпотентен,
  `compose down -v` выполнен.
- Auth через реальный PostgreSQL: register → 201, дубликат → 409 `email_taken`,
  login → 200, неверные данные → 401 `invalid_credentials`,
  `/me` с Bearer → 200, без токена → 401 `unauthorized`.
- В CI на `f4cf373` зелёный прогон. Проверка integration-теста с новым
  PostgreSQL service (после `2552bc0`) ещё не подтверждена логами.

## Осталось в этапе 1

1. Поток проектов/участников (`agent/stage-1-projects`) — ещё не запущен.
2. Клиентский слой: `ApiClient` на `dio`, secure storage, Riverpod/Bloc,
   экраны входа и проектов (`agent/stage-1-client`) — ещё не запущен.
3. Подтвердить в логах CI, что тест миграций не `skip`.
4. Финальный прогон и мерж PR #21 в `main`.
5. Верификация Demo-входа `12345/12345` пока сохраняется (реальный auth
   подключится к клиенту на этапе 1).

## Запуск приложения на Windows

```powershell
flutter run -d windows
```

Демо-вход: `12345` / `12345`. Сервер и PostgreSQL для демонстрации пока
не нужны — клиент работает с локальным Drift в демо-режиме; реальный API
появится после подключения клиентского слоя.
