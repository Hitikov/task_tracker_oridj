# Отчёт: этап 5 — релиз 2.0.x

- **Дата:** 22.11.2026
- **Ветки:** `release/v2.0.0`, `release/v2.0.1`, `release/v2.0.2`,
  `release/v2.0.3`, `feature/app-updates`, `feature/ui-polish`
- **PR:** [#29](https://github.com/Hitikov/task_tracker_oridj/pull/29),
  [#30](https://github.com/Hitikov/task_tracker_oridj/pull/30),
  [#31](https://github.com/Hitikov/task_tracker_oridj/pull/31),
  [#32](https://github.com/Hitikov/task_tracker_oridj/pull/32),
  [#33](https://github.com/Hitikov/task_tracker_oridj/pull/33),
  [#34](https://github.com/Hitikov/task_tracker_oridj/pull/34)
- **План:** [ROADMAP](../ROADMAP.md)
- **Статус:** завершён; релизы `v2.0.0`, `v2.0.1`, `v2.0.2`, `v2.0.3`
  опубликованы; `main` = `d5204a0`

## Цель

Воспроизводимый релиз, который можно установить и показать: APK/AAB для Android,
Windows-установщик, адрес API задаётся на сборке, приложение сообщает о новых
версиях, интерфейс адаптирован под разные размеры экрана.

## Выполнено

| Поток | Результат | Merge |
|---|---|---|
| База релиза 2.0.0 | версия `2.0.0+N`, подстановка `API_BASE_URL` через `--dart-define` | `15e134a`, PR #29 (`398ca32`) |
| 2.0.1 | Windows-установщик и Android APK, INTERNET в release-манифесте | `16f900d`, `4ff5b67`, PR #30 (`7666bfe`) |
| 2.0.2 | исправлены пути Inno Setup | `2ca50b1`, PR #31 (`a74743f`) |
| 2.0.3 | убран неверный флаг Inno Setup, выровнена версия, публикация установщика в релизе, уточнён параметр сборки | `5315124`, `85a6bd4`, `fedba32`, `2b4effd`, PR #32 (`7fcc7e0`) |
| Обновления приложения | проверка релизов GitHub, удаление демо-вкладки, `const String.fromEnvironment` для `API_BASE_URL` | `ee2690a`, `6a72039`, PR #33 (`ac81ff5`) |
| UI-полировка | адаптивная вёрстка, ресайз бокового меню (200–440), ограничение масштаба шрифта 0.9–1.25 | `7359e6d`, PR #34 (`d5204a0`) |

## Контракт

- REST API без изменений; контракт по-прежнему фиксирован в
  [OpenAPI](../api/openapi.yaml).
- `API_BASE_URL` и `DEMO_MODE` — build-time константы
  (`const String.fromEnvironment`), адрес по умолчанию `http://localhost:8080`.
- Артефакты релиза: `*.apk`, `*.aab`, Windows zip и `ArijSetup-<version>-x64.exe`,
  общий `SHA256SUMS.txt`. Теги `v2.0.0` … `v2.0.3` совпадают с версией
  `pubspec.yaml` (`2.0.3+0` на текущем `main`).
- Демо-вход `12345/12345` и вкладка «Демо работы с БД» удалены из основного UI;
  демо-режим доступен только с `--dart-define=DEMO_MODE=true`.

## Живые проверки

Релизы опубликованы по тегам `v2.0.0` … `v2.0.3`; workflow **Release**
(`lint → test → build-android + build-windows → deploy`) сформировал артефакты
и GitHub Release со ссылкой на установщик Windows. Локальный прогон проверок
на `d5204a0` приведён в [stage-4.md](stage-4.md) (84 клиентских и 279 серверных
тестов, analyze и format без замечаний).

## Ограничения

- Web-сборки нет: job `build-web` в workflow отсутствует, хотя точка входа
  для него есть в коде (build-time `API_BASE_URL`).
- Прод-развёртывание основано на Caddy ([deploy/](../../deploy)), а не на Nginx,
  как зафиксировано в N-06 и [architecture.md](../architecture.md).
- Legacy-слой Drift (`AppDatabase`, `PersonRepository`, `PersonController`)
  остаётся в `main.dart` как локальный кэш/демо и не используется основным UI.
- Релизная подпись Android требует секретов `ANDROID_KEYSTORE_*`; без них
  собирается debug-подпись (см. [ci-cd.md](../ci-cd.md)).

## Следующий шаг

Синхронизация документации с фактическим состоянием (этапы 4–5), затем
закрытие M-07 — экран управления участниками проекта в клиенте.
