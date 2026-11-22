# Локальный запуск Arij

`docker compose up` поднимает PostgreSQL 16 и Dart-сервер Arij. Сервер ждёт
готовности БД и применяет миграции при старте; клиент обращается к API напрямую
на `http://localhost:8080`. Nginx в локальный контур не входит: прод-развёртывание
использует Caddy (`deploy/`).

- План этапов: [ROADMAP.md](ROADMAP.md)
- Архитектура и структура `server/`: [architecture.md](architecture.md)
- Серверный пакет: [server/README.md](../server/README.md)
- Выбор стека: [ADR-0001](adr/0001-backend-stack.md)

## Что запускается

| Сервис | Образ / сборка | Контейнер | Порт на хосте | Данные |
|---|---|---|---|---|
| `postgres` | `postgres:16-alpine` | `arij-postgres` | `5432` (`DB_PORT`) | volume `arij_pgdata` |
| `server` | `./server/Dockerfile` | `arij-server` | `8080` (`SERVER_PORT`) | — |

- Проект Compose называется `arij`, сеть — `arij_network`.
- Сервер стартует только после того, как PostgreSQL пройдёт healthcheck
  (`pg_isready`), и отвечает на `GET /health`.
- Сервер открывает соединение с БД и применяет миграции при старте; переменные
  `DB_*` валидируются до подключения.

## Требования

- **Docker Desktop** для Windows/macOS или **Docker Engine + Compose v2** для Linux.
  Проверка:

  ```powershell
  docker version
  docker compose version
  ```

- **PowerShell 7+** для скриптов из `scripts/` (Windows, macOS, Linux).
  В Windows можно запускать из `pwsh`, в Linux/macOS — `pwsh ./scripts/dev-up.ps1`.
- Свободные порты `8080` и `5432` (или другие значения в `.env`).
- **Dart SDK 3.9+** (актуальный стабильный, например 3.13+; ограничение пакета —
  `^3.9.0` в `server/pubspec.yaml`) — только для запуска сервера без Docker.
- Python 3 с PyYAML — только для дополнительной проверки YAML, не обязателен.

## Быстрый старт

Из корня репозитория:

1. Создайте `.env` из шаблона:

   ```powershell
   Copy-Item .env.example .env
   ```

2. Замените `JWT_SECRET` на случайную строку не короче 32 символов:

   ```powershell
   openssl rand -hex 32
   # или только для локальной разработки:
   -join (1..32 | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
   ```

   Вставьте результат в строку `JWT_SECRET=` в `.env`. Placeholder
   `CHANGE_ME_...` из `.env.example` подходит для запуска, но не является секретом.

3. Поднимите окружение:

   ```powershell
   ./scripts/dev-up.ps1
   ```

   Скрипт проверит Docker и Compose, при отсутствии создаст `.env` из
   `.env.example` с предупреждением, соберёт образ сервера, запустит контейнеры
   и подождёт `/health` до 60 секунд.

4. Проверьте health:

   ```powershell
   curl.exe http://localhost:8080/health   # Linux/macOS: curl
   ```

   Ожидаемый ответ:

   ```json
   {
     "status": "ok",
     "service": "arij-server",
     "version": "0.1.0",
     "time": "2026-11-15T12:00:00.000Z"
   }
   ```

5. Логи и остановка:

   ```powershell
   ./scripts/logs.ps1              # все сервисы
   ./scripts/logs.ps1 server       # только сервер
   ./scripts/logs.ps1 -Service postgres
   ./scripts/dev-down.ps1          # остановить, данные БД сохранить
   ```

Если Windows блокирует выполнение скриптов:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Альтернатива без скриптов:

```powershell
Copy-Item .env.example .env
docker compose up -d --build
docker compose ps
```

## Переменные окружения

Все переменные перечислены в `.env.example`; `docker compose` читает `.env`
автоматически и требует его наличия (`env_file: .env` у сервера).

| Переменная | Пример | Назначение |
|---|---|---|
| `SERVER_HOST` | `0.0.0.0` | адрес, на котором слушает сервер |
| `SERVER_PORT` | `8080` | порт API на хосте |
| `DB_HOST` | `localhost` | хост PostgreSQL для запуска сервера вне Docker |
| `DB_PORT` | `5432` | порт PostgreSQL на хосте |
| `DB_NAME` | `arij` | имя базы |
| `DB_USER` | `arij` | пользователь базы |
| `DB_PASSWORD` | `arij_dev_password` | пароль базы (только для dev) |
| `JWT_SECRET` | случайная строка | секрет подписи JWT, не короче 32 символов |

Внутри Compose сервер принудительно получает `SERVER_HOST=0.0.0.0`,
`SERVER_PORT=8080`, `DB_HOST=postgres` и `DB_PORT=5432` — это адреса внутри
compose-сети, а не на хосте. Значения `DB_NAME`, `DB_USER`, `DB_PASSWORD` и
`JWT_SECRET` берутся из `.env`. Если обязательная переменная не задана, Compose
завершится с понятной ошибкой; секреты не имеют значений по умолчанию.

`.env` не коммитится (см. `.gitignore`); в репозитории хранится только
`.env.example`. Значения из примера — учебные и предназначены только для
локальной разработки. В production задайте стойкие пароли и секрет через
переменные окружения или секрет-менеджер.

## Запуск без Docker

Нужен локальный PostgreSQL 16 и Dart SDK.

1. Создайте пользователя и базу (значения должны совпадать с `.env`):

   ```powershell
   psql -U postgres -c "CREATE USER arij WITH PASSWORD 'arij_dev_password';"
   psql -U postgres -c "CREATE DATABASE arij OWNER arij;"
   ```

2. Создайте `.env` в корне и оставьте `DB_HOST=localhost`, `DB_PORT=5432`:

   ```powershell
   Copy-Item .env.example .env
   ```

3. Запустите сервер из каталога `server/`:

   ```powershell
   cd server
   dart pub get
   dart run bin/server.dart
   ```

   Сервер читает `./.env`, затем `../.env` (поэтому корневой `.env` подхватывается
   при запуске из `server/`). Переменные процесса имеют приоритет над файлами.

4. Проверка и остановка:

   ```powershell
   curl.exe http://localhost:8080/health
   # Ctrl+C — graceful shutdown
   ```

При `APPLY_MIGRATIONS=true` (по умолчанию) сервер подключается к PostgreSQL и
применяет миграции при старте; если БД недоступна, сервер завершается с ошибкой
до запуска HTTP. Сам `/health` к БД не обращается.

## Порты, сеть и том

| Что | Значение |
|---|---|
| Порт API на хосте | `SERVER_PORT` из `.env`, по умолчанию `8080` |
| Порт PostgreSQL на хосте | `DB_PORT` из `.env`, по умолчанию `5432` |
| Порт сервера внутри контейнера | `8080` (фиксирован) |
| Порт PostgreSQL внутри сети | `5432` (фиксирован) |
| Сеть Compose | `arij_network` |
| Volume с данными | `arij_pgdata` |

Меняйте в `.env` только порты на хосте, затем перезапускайте
`./scripts/dev-up.ps1`. После изменения переменных, которые попадают в контейнер,
Compose пересоздаёт контейнер; при сомнениях используйте
`docker compose up -d --force-recreate`.

Данные PostgreSQL хранятся в именованном volume `arij_pgdata` и переживают
`docker compose down` и `./scripts/dev-down.ps1`.

## Сброс базы данных

```powershell
./scripts/db-reset.ps1
```

Скрипт предупредит, что данные будут удалены, запросит подтверждение, выполнит
`docker compose down -v`, заново запустит PostgreSQL и дождётся статуса `healthy`.
Сервер при этом не запускается — после сброса выполните `./scripts/dev-up.ps1`.

Удалить данные можно и вручную:

```powershell
./scripts/dev-down.ps1 -Volumes
# или
docker compose down -v
```

**Внимание:** `-Volumes`, `down -v` и `db-reset.ps1` безвозвратно удаляют volume
`arij_pgdata` со всеми локальными данными.

После сброса база пустая; при следующем запуске сервер заново применит все
миграции `0000–0006` (`users`, `projects`, `project_members`, `task_types`,
`statuses`, `tasks`, `schema_migrations`). См. [ROADMAP.md](ROADMAP.md).

## Типичные проблемы

### Порт уже занят

Симптом: `Bind for 0.0.0.0:5432 failed: port is already allocated` или
`address already in use`.

```powershell
Get-NetTCPConnection -LocalPort 5432 -State Listen |
    Select-Object LocalAddress, LocalPort, OwningProcess
netstat -ano | findstr :5432
```

Варианты:

1. Остановить процесс, занимающий порт (например, локальный PostgreSQL).
2. Изменить `DB_PORT` или `SERVER_PORT` в `.env` и выполнить
   `./scripts/dev-up.ps1`.
3. На Windows проверить зарезервированные Hyper-V диапазоны:
   `netsh interface ipv4 show excludedportrange protocol=tcp` — при пересечении
   выберите другой порт.

### Нет `.env`

Симптом: Compose сообщает, что env-файл не найден, или скрипт просит создать
`.env`.

```powershell
Copy-Item .env.example .env
```

`./scripts/dev-up.ps1` создаёт `.env` автоматически, но остальные скрипты
требуют его наличия и выдают понятное сообщение.

### Docker не запущен

Симптом: `Cannot connect to the Docker daemon` или ошибка `docker info`.

1. Запустите Docker Desktop и дождитесь статуса Engine running
   (Linux: `sudo systemctl start docker`).
2. Проверьте: `docker version` и `docker compose version`.
3. Перезапустите терминал, чтобы обновился `PATH`.

Скрипты `dev-up`, `dev-down`, `db-reset` и `logs` проверяют Docker и Compose v2
и выдают понятное сообщение.

### Сервер не стал healthy

```powershell
docker compose ps
./scripts/logs.ps1 server
./scripts/logs.ps1 postgres
```

Что проверить:

- PostgreSQL в статусе `healthy` (`docker compose ps`).
- В логах сервера нет ошибок конфигурации: `JWT_SECRET` задан и не короче
  32 символов, `DB_NAME`/`DB_USER`/`DB_PASSWORD` заполнены.
- Порт в URL совпадает с `SERVER_PORT` из `.env`.
- `curl.exe http://localhost:8080/health` отвечает вручную.

Контейнерный healthcheck сервера использует `curl` внутри runtime-образа
(`server/Dockerfile`); `dev-up.ps1` дополнительно проверяет `/health` с хоста.

### Пароль БД изменился, но вход не работает

Образ PostgreSQL применяет `POSTGRES_PASSWORD` только при создании пустого
volume. После изменения пароля выполните `./scripts/db-reset.ps1` (удалит
локальные данные) либо измените пароль в работающей БД вручную.

### Изменения в `.env` не применились

Пересоздайте контейнеры:

```powershell
docker compose up -d --force-recreate
```

или снова выполните `./scripts/dev-up.ps1`.

### Первая сборка идёт долго

Образ собирается multi-stage: `dart:stable` скачивает зависимости и компилирует
AOT-исполняемый файл. Первая сборка может занять несколько минут, последующие
используют кэш Docker.

## Проверка конфигурации без запуска

```powershell
docker compose config
```

Команда проверяет и нормализует Compose-файл, но **выводит раскрытые значения
переменных, включая `JWT_SECRET` и `DB_PASSWORD`**. Не публикуйте её вывод.

Проверка YAML парсером (без раскрытия секретов):

```powershell
python -c "import yaml; d=yaml.safe_load(open('docker-compose.yml', encoding='utf-8')); print(sorted(d['services']))"
```

## Ограничения локального контура

- Nginx и Flutter Web в `docker-compose.yml` не входят: прод использует Caddy
  (`deploy/`), Web-сборка отсутствует.
- Клиент ходит на `http://localhost:8080` напрямую; базовый URL задаётся на
  сборке через `--dart-define=API_BASE_URL`.
- История переходов статусов не реализована; расширенные роли — post-MVP.
