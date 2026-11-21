# Отчёт: аудит и обновление версий зависимостей (stage-1)

- Дата: 2026-11-21
- Ветка: `agent/stage-1-deps`
- Базовая фиксация: `0c93aa0`
- Worktree: `C:\Users\Andre\.local\share\opencode\worktree\7601ed\stage-1-deps`
- SHA серверного коммита: `466561ee6d7c7f93db8a785d4615ee4c3a9af191`

## 1. Сохранённый вывод `dart pub outdated` (server/)

```text
Showing outdated packages.
[*] indicates versions that are not the latest available.

Package Name       Current  Upgradable  Resolvable  Latest  

direct dependencies:
dart_jsonwebtoken  *3.1.1   *3.1.1      *3.1.1      3.4.1   

dev_dependencies: all up-to-date.

transitive dependencies:
pointycastle       *3.9.1   *3.9.1      *3.9.1      4.0.0   

transitive dev_dependencies:
cli_util           *0.6.0   0.6.1       0.6.1       0.6.1   
coverage           *1.16.0  1.16.1      1.16.1      1.16.1  

2 upgradable dependencies are locked (in pubspec.lock) to older versions.
To update these dependencies, use `dart pub upgrade`.
```

> Примечание: этот вывод — до применения обновлений (§5). После `dart pub upgrade cli_util coverage`
> `cli_util` и `coverage` в lock перешли на 0.6.1 / 1.16.1; `dart_jsonwebtoken` и `pointycastle`
> намеренно остались прежними (§6).

## 2. Сохранённый вывод `flutter pub outdated` (корень worktree)

```text
Showing outdated packages.
[*] indicates versions that are not the latest available.

Package Name                      Current  Upgradable  Resolvable  Latest   

direct dependencies:             
cupertino_icons                   -        *1.0.9      2.0.0       2.0.0    
drift                             -        2.35.4      2.35.4      2.35.4   
flutter                           -        (sdk)       (sdk)       (sdk)    
path                              -        1.9.1       1.9.1       1.9.1    
path_provider                     -        2.1.6       2.1.6       2.1.6    
uuid                              -        4.6.0       4.6.0       4.6.0    

dev_dependencies:                
build_runner                      -        2.17.1      2.17.1      2.17.1   
drift_dev                         -        2.35.3      2.35.3      2.35.3   
flutter_lints                     -        6.0.0       6.0.0       6.0.0    
flutter_test                      -        (sdk)       (sdk)       (sdk)    

transitive dependencies:         
args                              -        2.7.0       2.7.0       2.7.0    
async                             -        2.13.1      2.13.1      2.13.1   
characters                        -        1.4.1       1.4.1       1.4.1    
code_assets                       -        2.2.0       2.2.0       2.2.0    
collection                        -        1.19.1      1.19.1      1.19.1   
convert                           -        3.1.2       3.1.2       3.1.2    
crypto                            -        3.0.8       3.0.8       3.0.8    
ffi                               -        2.2.0       2.2.0       2.2.0    
file                              -        7.0.1       7.0.1       7.0.1    
fixnum                            -        1.1.1       1.1.1       1.1.1    
glob                              -        2.2.0       2.2.0       2.2.0    
hooks                             -        2.2.0       2.2.0       2.2.0    
jni                               -        1.2.1       1.2.1       1.2.1    
jni_flutter                       -        1.1.0       1.1.0       1.1.0    
jni_util                          -        1.0.0       1.0.0       1.0.0    
logging                           -        1.3.0       1.3.0       1.3.0    
material_color_utilities          -        *0.13.0     *0.13.0     0.13.1   
meta                              -        1.19.0      1.19.0      1.19.0   
native_toolchain_c                -        0.19.6      0.19.6      0.19.6   
objective_c                       -        9.6.4       9.6.4       9.6.4    
package_config                    -        3.0.0       3.0.0       3.0.0    
path_provider_android             -        2.3.1       2.3.1       2.3.1    
path_provider_foundation          -        2.6.0       2.6.0       2.6.0    
path_provider_linux               -        2.2.2       2.2.2       2.2.2    
path_provider_platform_interface  -        2.1.3       2.1.3       2.1.3    
path_provider_windows             -        2.3.0       2.3.0       2.3.0    
platform                          -        3.2.0       3.2.0       3.2.0    
plugin_platform_interface         -        2.1.8       2.1.8       2.1.8    
process                           -        5.0.6       5.0.6       5.0.6    
pub_semver                        -        2.2.1       2.2.1       2.2.1    
record_use                        -        1.1.1       1.1.1       1.1.1    
sky_engine                        -        (sdk)       (sdk)       (sdk)    
source_span                       -        1.10.2      1.10.2      1.10.2   
sqlite3                           -        3.9.1       3.9.1       3.9.1    
stack_trace                       -        1.12.2      1.12.2      1.12.2   
stream_channel                    -        2.1.4       2.1.4       2.1.4    
string_scanner                    -        1.4.1       1.4.1       1.4.1    
term_glyph                        -        1.2.2       1.2.2       1.2.2    
typed_data                        -        1.4.0       1.4.0       1.4.0    
vector_math                       -        2.4.4       2.4.4       2.4.4    
web                               -        1.1.2       1.1.2       1.1.2    
xdg_directories                   -        1.1.0       1.1.0       1.1.0    
yaml                              -        3.1.4       3.1.4       3.1.4    

transitive dev_dependencies:     
_fe_analyzer_shared               -        111.0.0     111.0.0     111.0.0  
analyzer                          -        14.7.0      14.7.0      14.7.0   
boolean_selector                  -        2.1.2       2.1.2       2.1.2    
build                             -        5.0.0       5.0.0       5.0.0    
build_config                      -        1.4.0       1.4.0       1.4.0    
build_daemon                      -        4.1.7       4.1.7       4.1.7    
built_collection                  -        *5.1.2      *5.1.2      6.0.0    
built_value                       -        8.13.0      8.13.0      8.13.0   
charcode                          -        1.4.0       1.4.0       1.4.0    
checked_yaml                      -        2.0.4       2.0.4       2.0.4    
cli_util                          -        0.6.1       0.6.1       0.6.1    
clock                             -        1.1.3       1.1.3       1.1.3    
dart_style                        -        3.1.14      3.1.14      3.1.14   
fake_async                        -        1.3.3       1.3.3       1.3.3    
graphs                            -        2.3.2       2.3.2       2.3.2    
http_multi_server                 -        3.2.3       3.2.3       3.2.3    
http_parser                       -        4.1.2       4.1.2       4.1.2    
io                                -        1.1.0       1.1.0       1.1.0    
json_annotation                   -        4.12.0      4.12.0      4.12.0   
leak_tracker                      -        11.0.2      11.0.2      11.0.2   
leak_tracker_flutter_testing      -        3.0.10      3.0.10      3.0.10   
leak_tracker_testing              -        3.0.2       3.0.2       3.0.2    
lints                             -        6.1.0       6.1.0       6.1.0    
matcher                           -        0.12.20     0.12.20     0.12.20  
mime                              -        2.1.0       2.1.0       2.1.0    
pool                              -        1.5.3       1.5.3       1.5.3    
pubspec_parse                     -        1.7.0       1.7.0       1.7.0    
recase                            -        4.1.0       4.1.0       4.1.0    
shelf                             -        1.4.3       1.4.3       1.4.3    
shelf_web_socket                  -        3.0.0       3.0.0       3.0.0    
source_gen                        -        4.3.1       4.3.1       4.3.1    
sqlparser                         -        0.45.1      0.45.1      0.45.1   
stream_transform                  -        2.1.2       2.1.2       2.1.2    
test_api                          -        *0.7.12     *0.7.12     0.7.15   
vm_service                        -        15.4.0      15.4.0      15.4.0   
watcher                           -        1.2.1       1.2.1       1.2.1    
web_socket                        -        1.0.1       1.0.1       1.0.1    
web_socket_channel                -        3.0.3       3.0.3       3.0.3    
yaml_edit                         -        2.2.4       2.2.4       2.2.4    

No pubspec.lock found. There are no Current versions.
Run `flutter pub get` to create a pubspec.lock with versions matching your pubspec.yaml.

1 dependency is constrained to a version that is older than a resolvable version.
To update it, edit pubspec.yaml, or run `flutter pub upgrade --major-versions`.
```

> Примечание: в корне worktree нет `pubspec.lock` — таблица клиента выше показывает
> *доступные* версии (Upgradable/Latest). «Текущая» для клиента — из `pubspec.lock`
> main-копии `C:\Users\Andre\StudioProjects\task_tracker_oridj\pubspec.lock` (§4).

## 3. Таблица server (`dart pub outdated` + `server/pubspec.lock`)

| Пакет | Текущая (lock) | Доступна | Можно ли обновить и почему |
|---|---|---|---|
| argon2 | 1.0.1 | 1.0.1 | Да, уже на последней |
| dart_jsonwebtoken | 3.1.1 | 3.4.1 | **Нельзя** — обоснование: §6 |
| dotenv | 4.2.0 | 4.2.0 | Да, актуальна |
| logging | 1.3.0 | 1.3.0 | Да, актуальна |
| postgres | 3.6.0 | 3.6.0 | Да, актуальна |
| shelf | 1.4.3 | 1.4.3 | Да, актуальна |
| shelf_router | 1.1.5 | 1.1.5 | Да, актуальна |
| lints (dev) | 6.1.0 | 6.1.0 | Да, актуальна |
| test (dev) | 1.33.0 | 1.33.0 | Да, актуальна |
| pointycastle (транзитивный) | 3.9.1 | 4.0.0 | **Нельзя** — `dart_jsonwebtoken 3.1.1` требует `^3.7.3` (проверено в кэше pub), `argon2` требует `^3.1.2` → версия <4.0.0 недоступна в пределах совместимости |
| cli_util (транзитивный dev) | 0.6.0 | 0.6.1 | Да — патч; **применено** в lock |
| coverage (транзитивный dev) | 1.16.0 | 1.16.1 | Да — патч; **применено** в lock |

## 4. Таблица client (`flutter pub outdated`; текущая — lock main-копии)

| Пакет | Текущая | Доступна (Upgradable/Latest) | Можно ли обновить и почему |
|---|---|---|---|
| cupertino_icons | 1.0.9 | 2.0.0 (Latest) | Можно до 2.0.0 после этапа — требует смены constraint `^1.0.2` → `^2.0.0` (major); по ченджлогу 2.0.0: минимум Flutter 3.44/Dart 3.12 + миграция внутри пакета на `cupertino_ui` |
| drift | 2.35.2 | 2.35.4 | Можно до 2.35.4 — минор; при подъёме нужен синхронный подъём `drift_dev` + перегенерация `app_database.g.dart` |
| drift_dev | 2.35.1 | 2.35.3 | Можно до 2.35.3 — минор |
| path | 1.9.1 | 1.9.1 | Актуальна |
| path_provider | 2.1.6 | 2.1.6 | Актуальна |
| uuid | 4.6.0 | 4.6.0 | Актуальна |
| build_runner | 2.16.2 | 2.17.1 | Можно до 2.17.1 — минор |
| flutter_lints | 6.0.0 | 6.0.0 | Актуальна |
| flutter_test, flutter | (sdk) | (sdk) | Не трогать (условие этапа) |
| транзитивные, lock-only (не в pubspec.yaml) | material_color_utilities 0.13.0; test_api 0.7.12; crypto 3.0.7 | 0.13.1; 0.7.15; 3.0.8 | Подъём lock-only возможен после проверки использования |

## 5. Реально обновлённые версии (server)

- `server/pubspec.yaml` — изменений нет (все внутренние зависимости в рамках совместимых
  диапазонов к текущим версиям; `dart_jsonwebtoken` и `pointycastle` заблокированы, §6).
- `server/pubspec.lock` — `cli_util 0.6.0 → 0.6.1`; `coverage 1.16.0 → 1.16.1`
  (diff: 4 строки в `server/pubspec.lock`).

## 6. Обоснование `dart_jsonwebtoken` ≤ 3.1.x

- Инструкция этапа: `argon2 1.0.1` требует `pointycastle ^3.1.2`, а `dart_jsonwebtoken >=3.2.0`
  требует `^4.0.0` — несовместимо.
- Проверено через pub.dev API (`https://pub.dev/api/packages/dart_jsonwebtoken`):
  `3.4.1` (latest) → `pointycastle ^4.0.0`; `3.1.1` → `pointycastle ^3.7.3`.
  В кэше pub: `argon2 1.0.1` → `pointycastle ^3.1.2` (argon2 намеренно остаётся на 1.0.1 —
  внутри диапазона `^1.0.1` фактически последняя).
- Разрешение: `argon2 1.0.1` требует `pointycastle <4.0.0` → `dart_jsonwebtoken 3.2.0+`
  (требующий `^4.0.0`) несовместим → максимальный допустимый `dart_jsonwebtoken` — **3.1.1**
  (текущий, соответствует constraint `^3.1.1`). `pointycastle` тем самым остаётся 3.9.1.
- Дополнительно: подъём `dart_jsonwebtoken` выше 3.1.x разблокирует бы только при смене и
  `argon2` (на версию с `pointycastle ^4.x`) — сейчас не реализовано целенаправленно;
  это требует миграции кода, использующего `argon2`/`dart_jsonwebtoken` API.

## 7. Рекомендации клиента (после завершения клиентского агента)

**Можно поднять (после правок root `pubspec.yaml`):**

1. `cupertino_icons 1.0.9 → 2.0.0` — major. Шаги: `cupertino_icons: ^1.0.2 → ^2.0.0`;
   после подъёма — `flutter pub get`, затем `flutter analyze` + `flutter test`;
   проверить, нет ли в коде ссылок на удалённые/переименованные иконки (ченджлог 2.0.0:
   min SDK Flutter 3.44/Dart 3.12, миграция внутри пакета на `cupertino_ui`).
2. `drift 2.35.2 → 2.35.4` — минор. Шаги: поднять `drift_dev` (см. ниже) и
   `drift` одновременно, `flutter pub get`, затем перегенерировать код:
   `flutter pub run build_runner build --delete-conflicting-outputs`
   (или `dart run build_runner build`); затем `flutter analyze` + `flutter test`.
3. `drift_dev 2.35.1 → 2.35.3` — минор (требуется для синхронизации с drift).
4. `build_runner 2.16.2 → 2.17.1` — минор (`build_runner: ^2.4.8` — целевой уровень 2.17.1
   уже доступен в outdated).
5. Транзитивные lock-only: `material_color_utilities 0.13.1`, `test_api 0.7.15`,
   `crypto 3.0.8` — можно поднять после проверки использования; правки `pubspec.yaml`
   не требуются.

**Нельзя / пока не стоит:**

1. SDK — Flutter/Dart не обновлять (условие этапа; CI фиксирует `FLUTTER_VERSION: '3.47.6'`,
   backend — `sdk: '3.13.5'`). Пакеты с требованием Dart ≥3.14 недоступны, пока не поднимут
   Flutter/Dart — обновление SDK — отдельный этап.
2. Drift-совместимость: подъём `drift` без синхронного подъёма `drift_dev` и перегенерации
   кода — генерируемый `lib/database/app_database.g.dart` не будет соответствовать версии drift.
   Порядок шагов: `flutter pub get` → `flutter pub run build_runner build --delete-conflicting-outputs`
   → `flutter analyze` → `flutter test`.
3. `cupertino_icons 2.0.0` — без правки constraint невозможен (§7.1); без правок кода хорошей
   идеи нет, т.к. подъём может сломать иконки.

## 8. Проверки server (все зелёные)

- `dart pub get` — OK: «Got dependencies!», dart_jsonwebtoken 3.1.1, pointycastle 3.9.1
  (lock содержит обновлённые cli_util 0.6.1 / coverage 1.16.1).
- `dart format --set-exit-if-changed .` — «Formatted 27 files (0 changed)», exit 0.
- `dart analyze` — «No issues found!».
- `dart test` — «All tests passed!» — 65 тестов, 1 пропущен
  (`test\db\migrations_integration_test.dart`: «База недоступна: запустите PostgreSQL») — без БД,
  как и ожидалось.
- `git diff --check` — exit 0.
- `git status` — только разрешённые файлы: `server/pubspec.lock` (M), `docs/reports/stage-1-dependencies.md` (new).

## 9. Коммиты

- `466561ee6d7c7f93db8a785d4615ee4c3a9af191` — `server: обновить cli_util до 0.6.1 и coverage до 1.16.1 (server/pubspec.lock)` — `server/pubspec.lock`
- SHA отчёта — коммит 2 ветки `agent/stage-1-deps`: `docs: отчёт по аудиту версий зависимостей (stage-1)` — `docs/reports/stage-1-dependencies.md`

Push: `git push -u origin agent/stage-1-deps`.
