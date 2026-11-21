#!/usr/bin/env bash
# Arij — развёртывание прод-контура одной командой.
#   ./deploy/deploy.sh arij.example.com   # HTTPS через Let's Encrypt
#   ./deploy/deploy.sh 144.31.170.81      # HTTP по IP (без TLS)
#
# Требования: Docker + Compose v2. Для домена нужны A-запись и порты 80/443,
# для IP — достаточно порта 80. Flutter нужен только для сборки Web.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-${DOMAIN:-${TARGET:-}}}"
if [[ -z "$TARGET" ]]; then
  echo "Использование: $0 <домен или IP>" >&2
  exit 1
fi

# IP-адрес не может получить сертификат Let's Encrypt — работаем по HTTP.
if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  SCHEME="http"
  SITE_ADDR="http://$TARGET"
else
  SCHEME="https"
  SITE_ADDR="$TARGET"
fi
API_BASE="$SCHEME://$TARGET"

set_env() {
  local key="$1" value="$2"
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${value}|" .env
  else
    echo "${key}=${value}" >> .env
  fi
}

# 1. Конфигурация: создаём .env и генерируем секреты, если его ещё нет.
if [[ ! -f .env ]]; then
  cp .env.example .env
  sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -hex 32)|" .env
  sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -hex 24)|" .env
  echo "Создан .env со сгенерированными JWT_SECRET и DB_PASSWORD"
fi
set_env TARGET "$TARGET"
set_env SITE_ADDR "$SITE_ADDR"
set_env API_BASE_URL "$API_BASE"

# 2. Веб-клиент: собираем, если доступен Flutter и сборки ещё нет.
mkdir -p deploy/www
if [[ -f pubspec.yaml ]] && command -v flutter >/dev/null 2>&1 && [[ ! -f deploy/www/index.html ]]; then
  echo "Сборка Flutter Web с API_BASE_URL=$API_BASE"
  flutter build web --release \
    --dart-define="API_BASE_URL=$API_BASE" \
    -o deploy/www
fi

# 3. Docker CLI.
if command -v docker >/dev/null 2>&1; then
  DK=docker
elif [[ -x "/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]]; then
  DK="/c/Program Files/Docker/Docker/resources/bin/docker.exe"
else
  echo "Docker CLI не найден" >&2
  exit 1
fi

# 4. Поднимаем postgres + server + Caddy.
# Для домена добавляем порт 443 (HTTPS), для IP остаётся только 80.
COMPOSE_ARGS=(--env-file .env -f deploy/docker-compose.prod.yml)
if [[ "$SCHEME" == "https" ]]; then
  COMPOSE_ARGS+=(-f deploy/docker-compose.tls.yml)
fi
"$DK" compose "${COMPOSE_ARGS[@]}" up -d --build

echo ""
echo "Готово:"
echo "  API:   $API_BASE/health"
echo "  Web:   $API_BASE/  (если собран deploy/www)"
echo "  Логи:  $DK compose ${COMPOSE_ARGS[*]} logs -f"
