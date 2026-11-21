# Отчёт: этап 3 — Kanban

- **Дата:** 21.11.2026
- **Ветка:** `feature/stage-3-kanban`
- **PR:** [#26](https://github.com/Hitikov/task_tracker_oridj/pull/26)
- **План:** [ROADMAP](../ROADMAP.md)
- **Статус:** завершён, влит в `main` (`cb8ea1f`, PR #26)

## Цель

Наглядная работа со статусами: задача проходит `To Do → In Progress → Done`,
статус сохраняется и виден после перезагрузки.

## Выполнено

| Поток | Результат | Merge |
|---|---|---|
| Kanban API | `PATCH /api/v1/tasks/{id}/status`, `GET /api/v1/projects/{id}/board`, адаптер над `TaskRepository`, OpenAPI | `cc0645f` |
| Клиент | `BoardColumn`, API-методы, `boardProvider` с оптимистичным move/rollback, `KanbanPage` с drag & drop, навигация | `1d2d0cc` |
| Подключение | роуты доски в `app.dart` | `b84426e` |

## Контракт

- `PATCH /api/v1/tasks/{id}/status`, тело `{statusId}` → 200 Task.
- `GET /api/v1/projects/{id}/board` → `[{status, tasks}]`, колонки по `position`,
  задачи по `number`, пустые колонки сохраняются.
- Чужой/неизвестный `statusId` → 400 `validation_error` (`details.field=statusId`).
- Оптимистичное перемещение в клиенте откатывается при ошибке; после успеха
  синхронизируется `tasksProvider` (Backlog).

## Живые проверки Docker

```text
GET /projects/{id}/board                 200  (3 колонки, пустые сохранены)
PATCH /tasks/S2-1/status → In Progress   200
PATCH /tasks/S2-1/status → Done          200
PATCH /tasks/S2-1/status → unknown id    400 validation_error/statusId
GET /projects/{id}/board                 200  (задача в колонке Done)
compose restart server → GET board       S2-1 остался в Done
GET /health                              200
```

## Проверки кода

- `dart format` / `dart analyze` / `dart test` в `server/`: **279 тестов**, 1 skipped.
- `flutter pub get` / `dart format` / `flutter analyze` / `flutter test`: **67 тестов**.
- `python yaml.safe_load` OpenAPI: 14 путей, 19 схем, все `$ref` резолвятся.

## Ограничение

История переходов статусов не реализована: добавление миграции `0007` потребовало
бы переписывать тест миграций этапа 2. В репозитории оставлен TODO. На DoD этапа 3
она не влияет.

## Следующий шаг

Этап 4 — полировка MVP: валидация, роли, тесты, документация.
