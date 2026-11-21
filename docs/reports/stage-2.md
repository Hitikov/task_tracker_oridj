# Отчёт: этап 2 — задачи и Backlog

- **Дата:** 21.11.2026
- **Ветка:** `feature/stage-2-tasks-backlog`
- **PR:** [#23](https://github.com/Hitikov/task_tracker_oridj/pull/23)
- **План:** [ROADMAP](../ROADMAP.md)
- **Статус:** завершён, влит в `main` (`a213ef2`, PR #23)

## Цель

Сквозной сценарий: создать Epic → Task → Subtask, получить уникальный номер
задачи в проекте, увидеть задачи в Backlog и сохранить изменения.

## Выполнено

| Поток | Результат | Merge |
|---|---|---|
| БД и контракт | миграции `0004–0006`, enum'ы, `task_types`, `statuses`, `tasks`, OpenAPI-схемы и пути | `1879cde` |
| Серверный API | модели, репозиторий с нумерацией, сервис с проверкой иерархии и прав, 7 хендлеров | `8b2fd31`, роуты `a5d1107` |
| Клиент | модели задач, API-методы, Riverpod-провайдеры, `BacklogPage` с фильтрами и формами | `ec07886` |
| Исправления интеграции | согласование SQL со схемой, ключ `S2-1` в ответах | `793fe2c`, `847c473` |

## Контракт

- `GET/POST /api/v1/projects/{id}/tasks`
- `GET/PATCH/DELETE /api/v1/tasks/{id}`
- `GET /api/v1/projects/{id}/task-types`, `GET /api/v1/projects/{id}/statuses`
- Задача: `id, projectId, number, key, kind, typeId, statusId, title,
  description, priority, assigneeId, reporterId, parentId, dueDate,
  createdAt, updatedAt`
- `kind` (`epic`/`task`/`subtask`) — иерархия; `typeId` — настраиваемая
  классификация. Это разные измерения.
- Номер уникален в проекте, ключ выводится как `<KEY>-<number>`.

## живые проверки Docker

```text
POST /auth/login                          200
GET  /projects                            200
GET  /projects/{id}/task-types            200  (bug/feature/custom)
GET  /projects/{id}/statuses              200  (to_do/in_progress/done)
POST /projects/{id}/tasks  (epic)         201  number=1, key=S2-1
POST /projects/{id}/tasks  (task)         201  number=2, key=S2-2, parent=epic
POST /projects/{id}/tasks  (subtask)      201  number=3, key=S2-3, parent=task
POST /projects/{id}/tasks  (subtask→epic) 400  validation_error/parentId
PATCH /tasks/{id}                         200
DELETE /tasks/{id}                        204
GET  /projects/{id}/tasks                 200  ключи S2-1...
GET  /health                              200
```

## Проверки кода

- `dart format` / `dart analyze` / `dart test` в `server/`: **250 тестов**, 1 skipped без БД.
- `flutter pub get` / `dart format` / `flutter analyze` / `flutter test`: **64 теста**.
- `python yaml.safe_load` + проверка `$ref` OpenAPI: 114 ссылок, все резолвятся.
- Живые миграции: 7 записей в `schema_migrations`, enum'ы, индексы и CHECK-и
  проверены в PostgreSQL 16.

## Ограничения

- `user_role` создан enum'ом, но `project_members.role` остался `TEXT` + CHECK
  из этапа 1 — сознательно, чтобы не переписывать применённую миграцию.
- История переходов статусов (этап 3) не реализована.

## Следующий шаг

Этап 3 — Kanban: колонки по статусам, drag & drop, синхронизация с Backlog.
