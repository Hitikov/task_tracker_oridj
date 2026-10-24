# CI/CD

В репозитории два workflow GitHub Actions:

| Workflow | Файл | Когда запускается | Что делает |
|---|---|---|---|
| **CI** | `.github/workflows/ci.yml` | Pull request в любую ветку, push в `main`, вручную | Проверяет форматирование, запускает анализатор и тесты, собирает Windows-версию и прикладывает архив как artifact |
| **Release** | `.github/workflows/release.yml` | Push тега `v*`, вручную | Собирает Windows-релиз, считает SHA-256 и публикует GitHub Release |

Оба workflow используют Flutter `3.47.6` и кэшируют SDK и pub-зависимости.

## Что проверяет CI

1. `dart format --output=none --set-exit-if-changed lib test` — код должен быть отформатирован.
2. `flutter analyze` — без предупреждений и ошибок.
3. `flutter test` — все тесты должны проходить.
4. `flutter build windows --release` — приложение должно собираться под Windows.

Если хотя бы один шаг падает, PR нельзя считать готовым к merge.

## Локальные проверки перед push

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

`dart format lib test` не только проверяет, но и форматирует файлы. В CI используется
режим только проверки, поэтому неотформатированный код там упадёт.

## Как выпустить релиз

1. Обновите версию в `pubspec.yaml`:

   ```yaml
   version: 1.0.0+1
   ```

   Первые три числа — версия приложения, число после `+` — build number.

2. Закоммитьте изменение и влейте его в `main`.

3. Создайте и запушьте тег, совпадающий с версией:

   ```powershell
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. Workflow **Release** соберёт приложение и создаст GitHub Release с архивом
   `task_tracker_oridj-1.0.0-windows-x64.zip` и файлом `SHA256SUMS.txt`.

Тег должен указывать на коммит, в котором уже есть `.github/workflows/release.yml`.
Если тег не совпадает с `version` из `pubspec.yaml`, сборка остановится с ошибкой.

### Ручной запуск

В GitHub: **Actions → Release → Run workflow**. Укажите существующий тег
(например, `v1.0.0`) и при необходимости отметьте pre-release.

## Где скачать сборку

- **CI**: вкладка **Actions → нужный запуск → Artifacts**, архив хранится 14 дней.
- **Release**: раздел **Releases** репозитория, архив хранится бессрочно.

## Требования к репозиторию

- В **Settings → Actions → General** должны быть разрешены GitHub Actions.
- Для публикации релиза workflow запрашивает `contents: write`. Если в организации
  включён режим «Read repository contents permission» по умолчанию, явные
  `permissions` в workflow всё равно выдают токену нужный доступ.
- Секреты для сборки не требуются. `.env` с параметрами PostgreSQL в релизный
  архив не попадает.

## Self-hosted runner

По умолчанию используются GitHub-hosted runners (`ubuntu-latest` и `windows-latest`).
Если нужен собственный runner (см. `how-to_self-host-runner`), замените в workflow
`runs-on` на свои метки, например:

```yaml
runs-on: [self-hosted, "runner-${{ github.actor }}"]
```

Учтите, что для сборки Windows runner должен быть Windows-машиной с установленным
Visual Studio Build Tools (Desktop development with C++).
