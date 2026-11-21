# Демо-сценарий MVP

Документ описывает полный сценарий демонстрации Arij после этапов 0–3.
Все шаги выполняются локально; сервер и база поднимаются через Docker Compose.

## 1. Подготовка

Требования: Flutter 3.47.6, Dart 3.13.5, Docker Desktop с Compose v2.

```powershell
# 1. Конфигурация сервера
Copy-Item .env.example .env
# Задайте JWT_SECRET (случайная строка не короче 32 символов)

# 2. Backend + PostgreSQL
./scripts/dev-up.ps1
# Ожидается: сервисы arij-postgres и arij-server healthy

# 3. Проверка API
curl http://localhost:8080/health
# {"status":"ok","service":"arij-server","version":"0.1.0",...}

# 4. Клиент
flutter pub get
flutter run -d windows
```

Если порты 8080/5432 заняты, используйте `--dart-define=API_BASE_URL=http://localhost:8081`
и переменные `SERVER_PORT`/`DB_PORT` в `.env` (подробности — [local-dev.md](local-dev.md)).

> Старый демо-вход `12345/12345` включается только флагом
> `--dart-define=DEMO_MODE=true`. Основной сценарий ниже использует реальный API.

## 2. Регистрация и вход

1. Откройте экран регистрации.
2. Введите логин (имя) от 1 до 100 символов, email и пароль **не короче 8 символов**.
3. Нажмите «Зарегистрироваться» — появится диалог «Вы зарегистрированы».
4. Нажмите «Перейти ко входу», введите тот же email и пароль.
5. После входа откроется главная оболочка приложения; токен хранится в secure storage.

Ошибки: неверный email/короткий пароль — валидация на клиенте; занятый email —
`409 email_taken`; неверные данные входа — `401 invalid_credentials`
(без уточнения, существует ли аккаунт).

## 3. Проект и участники

1. Создайте проект: key `DEMO` (шаблон `^[A-Z][A-Z0-9]{1,9}$`), название и описание.
2. Зарегистрируйте второго пользователя и добавьте его в проект как `member`.
3. Проверьте: владелец видит проект и может управлять участниками, участник видит проект,
   но не может его изменить (`403 forbidden`).

## 4. Задачи и Backlog

1. Создайте **Epic** «Авторизация».
2. Внутри эпика создайте **Task** «Форма входа»; внутри задачи — **Subtask** «Валидация пароля».
3. Проверьте нумерацию: задачи получают номера 1, 2, 3 и ключи `DEMO-1`, `DEMO-2`, `DEMO-3`.
4. Откройте Backlog: проверьте список, сортировку по номеру/дедлайну/приоритету,
   поиск по названию и фильтры по статусу/исполнителю/kind.
5. Измените задачу (название, приоритет, исполнителя, дедлайн) и убедитесь, что
   изменения сохраняются.

Попытка сделать `subtask` родителем `epic` отклоняется (`400 validation_error/parentId`).

## 5. Kanban

1. Откройте доску проекта: колонки `To Do`, `In Progress`, `Done`.
2. Перетащите карточку из `To Do` в `In Progress`, затем в `Done`.
3. Убедитесь, что статус обновился оптимистично и не откатился.
4. Вернитесь в Backlog — статус задачи там тоже обновился.
5. Перезапустите сервер (`docker compose restart server`) и обновите страницу:
   задача остаётся в `Done`.

## 6. Проверка целостности

```powershell
$dk = 'C:\Users\Andre\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe'
& $dk compose exec -T postgres psql -U arij -d arij -c '\dt'
& $dk compose exec -T postgres psql -U arij -d arij -c 'select * from schema_migrations;'
& $dk compose exec -T postgres psql -U arij -d arij -c 'select number, key, kind from tasks order by number;'
```

Ожидается: таблицы `users`, `projects`, `project_members`, `task_types`, `statuses`,
`tasks`, `schema_migrations`; 7 применённых миграций; задачи с уникальными номерами.

## 7. Завершение

```powershell
./scripts/dev-down.ps1          # остановить, данные сохранить
./scripts/dev-down.ps1 -Volumes # остановить и удалить данные
```

## Известные ограничения

- История переходов статусов не реализована (TODO в `board_repository.dart`).
- Расширенные роли (admin/viewer) — post-MVP; в MVP есть `owner` и `member`.
- AI/MCP, Reports, Calendar, Timeline и real-time — вне объёма MVP.
