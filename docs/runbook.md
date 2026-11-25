# Эксплуатационный runbook Arij

Типовые операции с прод-контуром, который поднимается скриптами
[`deploy/deploy.sh`](../deploy/deploy.sh) и [`deploy/install.sh`](../deploy/install.sh).
Контур описан в [`deploy/docker-compose.prod.yml`](../deploy/docker-compose.prod.yml):
`postgres` (данные в volume `arij_pgdata`), `server` (Dart/Shelf, endpoint
`/health`) и `caddy` (HTTP:80; для домена дополнительно HTTPS:443 через
`docker-compose.tls.yml`). Логи сервисов ограничены ротацией `json-file`
10 MiB × 3 файла, чтобы не заполнять диск.

Команды выполняются из корня репозитория на сервере. Один раз загрузите `.env`
в окружение и задайте массив Compose:

```bash
set -a; . ./.env; set +a
API_BASE="$API_BASE_URL"
COMPOSE=(docker compose --env-file .env -f deploy/docker-compose.prod.yml)
```

Если деплой сделан по домену, добавьте в конец массива
`-f deploy/docker-compose.tls.yml` — так же, как это делает `deploy.sh`.
`API_BASE` ниже — значение `API_BASE_URL` из `.env` (`https://<домен>` или
`http://<IP>`).

## Мониторинг и проверки здоровья

```bash
"${COMPOSE[@]}" ps
curl -fsS "$API_BASE/health"
"${COMPOSE[@]}" exec server curl --fail --silent http://127.0.0.1:8080/health
"${COMPOSE[@]}" exec postgres pg_isready -U "$DB_USER" -d "$DB_NAME"
"${COMPOSE[@]}" logs --tail=100 server
docker stats --no-stream
df -h
```

`docker compose ps` показывает статус `healthy`, `starting` или `unhealthy` —
healthcheck есть у `postgres` и `server`. Первый признак проблемы —
`unhealthy` дольше 1–2 минут или рост использования диска. Порядок разбора:

1. `"${COMPOSE[@]}" logs --tail=200 <сервис>` (`postgres`, `server`, `caddy`).
2. Проверить `.env`: `JWT_SECRET`, `DB_PASSWORD`, `SITE_ADDR`, доступность БД.
3. Проверить сеть и порты: `curl` на `/health` через Caddy и напрямую из
   контейнера `server` (команды выше).
4. Мягкий перезапуск сервиса: `"${COMPOSE[@]}" restart server`. Для применения
   изменений `.env` используйте `"${COMPOSE[@]}" up -d --force-recreate server`.
5. Проверить свободное место и ротацию логов (`df -h`, `docker system df`).

## Резервное копирование и восстановление PostgreSQL

### Бэкап

`deploy.sh` печатает готовую команду бэкапа в конце каждого развёртывания.
Формат `-Fc` (custom) предназначен для `pg_restore` и сжимает дамп:

```bash
"${COMPOSE[@]}" exec -T postgres pg_dump -Fc -U "$DB_USER" -d "$DB_NAME" > "arij-$(date +%F).dump"
```

Плоский SQL-дамп (если нужен `psql`, а не `pg_restore`):

```bash
"${COMPOSE[@]}" exec -T postgres pg_dump -U "$DB_USER" -d "$DB_NAME" > "arij-$(date +%F).sql"
```

Храните копии вне сервера (отдельный диск/облако), шифруйте их, держите
несколько точек во времени и периодически проверяйте восстановление в тестовую
БД. Один дамп на том же хосте не защищает от его поломки.

### Проверка дампа без трогания боевых данных

```bash
"${COMPOSE[@]}" exec -T postgres psql -U "$DB_USER" -d postgres -c "CREATE DATABASE arij_restore_check;"
"${COMPOSE[@]}" exec -T postgres pg_restore -U "$DB_USER" -d arij_restore_check < "arij-2026-11-25.dump"
"${COMPOSE[@]}" exec -T postgres psql -U "$DB_USER" -d arij_restore_check -c "SELECT count(*) FROM users;"
"${COMPOSE[@]}" exec -T postgres psql -U "$DB_USER" -d arij_restore_check -c "SELECT count(*) FROM tasks;"
```

### Полное восстановление

Делайте только в окне недоступности и только после свежего бэкапа текущего
состояния: `--clean --if-exists` удаляет существующие объекты БД.

```bash
"${COMPOSE[@]}" exec -T postgres pg_dump -Fc -U "$DB_USER" -d "$DB_NAME" > "arij-before-restore-$(date +%F).dump"
"${COMPOSE[@]}" stop server
"${COMPOSE[@]}" exec -T postgres pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists --no-owner < "arij-2026-11-25.dump"
"${COMPOSE[@]}" start server
curl -fsS "$API_BASE/health"
```

`server` останавливается, чтобы во время восстановления в БД не попадали новые
записи. Дамп вместе с таблицей миграций должен соответствовать версии кода,
которая будет запущена после восстановления.

## Откат релиза

1. Выберите предыдущую версию:

   ```bash
   git tag --sort=-creatordate | head -20
   git log --oneline -10
   ```

2. На сервере, клонированном с `--depth 1`, тег может отсутствовать — получите
   его явно:

   ```bash
   git fetch --depth 1 origin tag v2.0.4
   ```

3. Переключитесь на тег или коммит и пересоберите образ сервера:

   ```bash
   git checkout v2.0.4
   git rev-parse --short HEAD
   bash deploy/deploy.sh "$TARGET"
   ```

4. Проверьте результат:

   ```bash
   "${COMPOSE[@]}" ps
   curl -fsS "$API_BASE/health"
   "${COMPOSE[@]}" logs --tail=100 server
   ```

Volume `arij_pgdata` при откате не трогается: пересобирается только `server`.
Откат кода **не откатывает схему БД** — миграции, применённые новой версией,
остаются. Если старый код несовместим с новой схемой, сначала восстановите БД
из бэкапа (раздел «Полное восстановление») и только затем запускайте старую
версию. Возврат на актуальную версию — через процедуру обновления ниже.

## Обновление бэкенда на сервере, клонированном с `--depth 1`

`install.sh` получает исходники через `git clone --depth 1`. В поверхностном
клоне нет полной истории, поэтому обычный `git pull --ff-only origin main`
ненадёжен: удалённый ref `origin/main` может не обновиться. Используйте явный
fetch в remote-tracking ref и затем переключение ветки:

```bash
git fetch --depth 1 origin +refs/heads/main:refs/remotes/origin/main
git checkout -B main origin/main
git rev-parse --short HEAD
bash deploy/deploy.sh "$TARGET"
curl -fsS "$API_BASE/health"
```

Именно так обновление делается в `deploy/install.sh`. Если используется другая
ветка, замените `main` на её имя (`BRANCH`). Префикс `+` в refspec разрешает
обновление `origin/main` даже после перезаписи истории на удалённой стороне.
Перед `checkout -B` рабочая копия должна быть чистой: локальные правки
конфигурации хранятся в `.env`, а не в файлах репозитория.

## Ротация секретов

Секреты живут только в `.env` на сервере (и в GitHub Secrets для Android) и не
попадают в git. Перед любой ротацией сохраните текущий `.env` и сделайте бэкап
БД. После изменения секретов контейнеры нужно пересоздать: просто `restart`
не подхватит новые значения из `env_file`.

### JWT_SECRET

Новый секрет аннулирует все выданные токены — пользователям придётся войти
заново. Проведите ротацию в объявленное окно.

```bash
NEW_JWT="$(openssl rand -hex 32)"
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$NEW_JWT|" .env
"${COMPOSE[@]}" up -d --force-recreate server
curl -fsS "$API_BASE/health"
```

### DB_PASSWORD

`POSTGRES_PASSWORD` из compose применяется только при первой инициализации
volume, поэтому одного изменения `.env` недостаточно — пароль роли нужно
обновить и внутри PostgreSQL.

```bash
"${COMPOSE[@]}" exec -T postgres pg_dump -Fc -U "$DB_USER" -d "$DB_NAME" > "arij-before-rotation-$(date +%F).dump"
read -rs NEW_DB_PASSWORD
"${COMPOSE[@]}" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" \
  -v db_user="$DB_USER" -v new_password="$NEW_DB_PASSWORD" <<'SQL'
ALTER ROLE :"db_user" WITH PASSWORD :'new_password';
SQL
grep -v '^DB_PASSWORD=' .env > .env.new
printf 'DB_PASSWORD=%s\n' "$NEW_DB_PASSWORD" >> .env.new
mv .env.new .env
"${COMPOSE[@]}" up -d --force-recreate postgres server
curl -fsS "$API_BASE/health"
```

`read -rs` не оставляет пароль в истории оболочки; значение всё равно передаётся
аргументом `psql`, поэтому запускайте команду из доверенного терминала. Пароль в
`.env` и пароль роли должны совпадать, иначе `server` не подключится к БД.

### ANDROID_KEYSTORE_*

Это четыре секрета GitHub Actions (`ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`),
описанные в [ci-cd.md](ci-cd.md). Меняйте все четыре одновременно и сохраните
старый keystore во внешнем надёжном хранилище: потеря ключа означает потерю
возможности подписывать обновления.

```bash
keytool -genkeypair -v -keystore android/app/release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias release
base64 -w0 android/app/release.jks > release.jks.b64
```

Обновите значения в **Settings → Secrets and variables → Actions**, затем
увеличьте версию и build number в `pubspec.yaml` и выпустите новый тег.
Смена ключа меняет подпись APK: Android откажется ставить его поверх прежней
версии (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), поэтому потребуется однократная
переустановка — как при переходе с debug-подписи (см.
[auto-update.md](auto-update.md)). Проверьте подпись нового артефакта:

```bash
apksigner verify --print-certs task_tracker_oridj-<version>-android.apk
```

## Развёртывание по IP: оговорка HTTP

`deploy.sh` определяет IP-адрес по шаблону и поднимает контур **только по HTTP
на порту 80**: файл `docker-compose.tls.yml` с портом 443 не подключается,
Let's Encrypt-сертификат для IP не выдаётся. Логин, пароль и JWT передаются
открытым текстом. Release-клиент допускает такой адрес с предупреждением и
cleartext-исключением Android только для этого IP (см.
[ROADMAP.md](ROADMAP.md)).

Рекомендация: для боевого контура используйте домен с A-записью и Let's Encrypt
(достаточно 80/443). Если IP-развёртывание неизбежно, ограничьте доступ к порту
80 брандмауэром, не используйте пароли из других систем и следите за логами.
`deploy.sh` выводит это предупреждение после каждого HTTP-деплоя.
