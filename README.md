# Arij — трекер задач для командной работы

> **Статус:** этапы 0–6 завершены, опубликованы релизы `v2.0.0`–`v2.1.0`. Arij умеет
> регистрировать и авторизовать пользователей, управлять проектами и участниками,
> создавать Epic/Task/Subtask, показывать задачи в Backlog и Kanban, искать и
> фильтровать задачи, отслеживать историю статусов и автоматически обновляться из
> GitHub Releases. Данные хранятся в PostgreSQL, клиент общается с сервером через
> REST API (`dio` + JWT).
>
> План развития — [docs/ROADMAP.md](docs/ROADMAP.md), демо-сценарий —
> [docs/demo-scenario.md](docs/demo-scenario.md), итоги этапов — в
> [docs/reports/](docs/reports).

## Описание проекта

**Arij** — кроссплатформенное приложение для управления проектами и задачами,
предназначенное для командной работы. Оно позволяет создавать проекты,
распределять задачи между участниками, назначать исполнителей, устанавливать
приоритеты и сроки, а также отслеживать ход выполнения работы.

В Arij предусмотрена иерархия задач «Эпик → Задача → Подзадача» и два основных
представления: Backlog (список с фильтрами и сортировкой) и Kanban-доска
(колонки по статусам с переносом карточек).

## Цель проекта

Цель — разработать удобный инструмент для организации командной работы,
планирования задач и контроля прогресса. Arij помогает участникам команды
координировать работу, распределять ответственность и видеть общее состояние
проекта.

## Команда проекта

Все участники выполняют основную роль разработчика (Developer) и дополнительно
отвечают за отдельные направления работы.

| ФИО | Основная роль | Дополнительные роли | Обязанности в рамках проекта |
|---|---|---|---|
| Алапанова Аиша Алексеевна | Developer | Scrum Master, Аналитик, Тимлид | Организация командной работы, требования, координация и согласование решений |
| Смирнов Андрей Сергеевич | Developer | Аналитик, Тестировщик | Пользовательские сценарии, CRUD проектов и участников, тестовые сценарии и E2E |
| Швецов Артем Владимирович | Developer | DevOps-инженер, Аналитик | Окружение разработки, сервер, PostgreSQL, Docker Compose, CI/CD |
| Молодцов Иван Александрович | Developer | Аналитик, Тестировщик | Требования к интерфейсу, клиентский API-слой, экраны, widget-тесты |

## Репозиторий проекта

Исходный код, документация и материалы проекта размещаются в общем репозитории:
[Hitikov/task_tracker_oridj](https://github.com/Hitikov/task_tracker_oridj).

## Стек технологий

| Компонент | Технология |
|---|---|
| Клиент | Flutter (единая кодовая база: Android, Windows, Web) |
| Сервер | Dart + `shelf`, слои `routes → services → repositories → db` |
| API | REST/JSON `/api/v1`, контракт в OpenAPI 3.1 |
| База данных | PostgreSQL 16, forward-only SQL-миграции |
| Аутентификация | JWT HS256, Argon2id для паролей |
| Хранилище токена на клиенте | `flutter_secure_storage` |
| Состояние клиента | Riverpod |
| Локальный слой на клиенте | Drift (не используется в основном UI) |
| Инфраструктура | Docker Compose, Caddy, GitHub Actions |

> Web-сборка уже входит в CI и Release; прод разворачивается через Caddy.
> AI/MCP, Reports, Calendar и Timeline остаются post-MVP и в MVP не входят.

## Возможности

### Реализовано

- регистрация, вход, выход и получение текущего пользователя по JWT;
- проекты и участники с базовыми ролями `owner`/`member`;
- задачи Epic → Task → Subtask с уникальной нумерацией в проекте;
- исполнитель, приоритет, дедлайн, типы и статусы задачи;
- Backlog с поиском, фильтрами и сортировкой;
- Kanban с переносом карточек, историей смены статусов и синхронизацией с Backlog;
- экран управления участниками проекта;
- автообновление Windows/Android из GitHub Releases;
- адаптивная вёрстка и тесты клиента/сервера в CI.

### Планируется

- настраиваемые типы, статусы и рабочие процессы;
- обязательные/необязательные поля задачи;
- расширенная ролевая модель;
- Calendar, Timeline и Reports;
- агентские функции на базе MCP.

## Быстрый старт

### Требования

- Flutter 3.47.6 (stable) и Dart 3.13.5;
- для сборки Windows — Visual Studio 2022 с рабочей нагрузкой
  «Разработка классических приложений на C++»;
- для backend — Docker и Docker Compose v2.

### Клиент

```powershell
flutter --version
flutter pub get
flutter run -d windows
```

Адрес API задаётся на сборке:
`--dart-define=API_BASE_URL=http://localhost:8080`. Демо-режим включается только
через `--dart-define=DEMO_MODE=true`.

Готовые сборки публикуются в
[GitHub Releases](https://github.com/Hitikov/task_tracker_oridj/releases):
APK, AAB, Windows zip, `ArijSetup-<version>-x64.exe`, Web-архив и `SHA256SUMS.txt`.

### Backend и PostgreSQL

```powershell
Copy-Item .env.example .env   # затем задайте JWT_SECRET
./scripts/dev-up.ps1           # docker compose up -d --build + ожидание /health
```

Сервер отвечает на <http://localhost:8080/health> и применяет миграции при старте.
Подробности — в [docs/local-dev.md](docs/local-dev.md).

## Структура репозитория

```text
lib/                    Flutter-клиент: экраны, состояние, ApiClient, обновления
test/                   тесты клиента (unit, widget, UI)
server/                 Dart-сервер: routes/services/repositories/db, миграции, тесты
android/ ios/ web/      платформенные проекты Flutter
windows/ linux/ macos/  десктопные проекты Flutter
docs/                   документация, ADR, OpenAPI, схемы, отчёты этапов
deploy/                 прод-контур: Docker Compose + Caddy
scripts/                PowerShell-скрипты локального запуска и работы с БД
installer/windows/      Inno Setup для Windows-установщика
.github/workflows/      CI и Release
```

Корневые файлы: `pubspec.yaml` (версия и зависимости клиента),
`docker-compose.yml` (разработка), `.env.example` (шаблон переменных окружения),
`analysis_options.yaml` (линты), `CONTRIBUTING.md` (правила участия),
`instructions.md` (короткий индекс правил).

## Архитектура проекта

Arij построен по клиент-серверной схеме: Flutter-клиент обращается к серверу на
Dart (`shelf`) через REST API `/api/v1`, данные хранятся в PostgreSQL. Сервер
разделен на слои `routes → services → repositories → db`.

- полное описание — [docs/architecture.md](docs/architecture.md);
- редактируемая схема в draw.io — [docs/architecture.drawio](docs/architecture.drawio);
- тот же набор компонентов в UML/PlantUML — [docs/architecture.puml](docs/architecture.puml);
- решение по серверному стеку — [ADR-0001](docs/adr/0001-backend-stack.md).

## Документация

### Планирование и требования

- [ROADMAP: план развития](docs/ROADMAP.md)
- [MVP и MoSCoW](docs/MVP.md)
- [Пользовательские истории](docs/USER_STORY.md)
- [User Story для отчёта](docs/USER_STORY_FOR_REPORT.md)
- [Сценарии использования](docs/SCRIPT.md)
- [Материалы для отчёта по MVP](docs/MVP_FOR_REPORT.md)
- [Доска первого спринта](docs/sprint-1-board.md) и [её снимок](docs/sprint-1-board.png)

### Архитектура и контракты

- [Архитектура проекта](docs/architecture.md)
- [Схема в draw.io](docs/architecture.drawio) и [PlantUML-источник](docs/architecture.puml)
- [ADR-0001: серверный стек](docs/adr/0001-backend-stack.md)
- [OpenAPI 3.1](docs/api/openapi.yaml)

### Разработка, запуск и эксплуатация

- [Локальный запуск и Docker](docs/local-dev.md)
- [CI/CD и релизы](docs/ci-cd.md)
- [Автоматическое обновление](docs/auto-update.md)
- [Runbook: бэкап, откат, ротация секретов](docs/runbook.md)
- [Self-hosted runner](docs/self-hosted-runner.md)

### Демо и отчёты по этапам

- [Демо-сценарий MVP](docs/demo-scenario.md)
- [Этап 0 — фундамент](docs/reports/stage-0.md)
- [Этап 1 — Auth и проекты](docs/reports/stage-1.md),
  [База данных](docs/reports/stage-1-db.md),
  [Контрольная точка](docs/reports/stage-1-checkpoint.md),
  [Зависимости](docs/reports/stage-1-dependencies.md)
- [Этап 2 — задачи и Backlog](docs/reports/stage-2.md)
- [Этап 3 — Kanban](docs/reports/stage-3.md)
- [Этап 4 — полировка MVP](docs/reports/stage-4.md)
- [Этап 5 — релиз 2.0.x](docs/reports/stage-5.md)

### Участие в разработке

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [instructions.md](instructions.md)
