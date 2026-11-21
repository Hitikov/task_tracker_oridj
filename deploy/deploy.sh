#!/usr/bin/env bash
# Arij — развёртывание прод-контура одной командой.
#   ./deploy/deploy.sh arij.example.com
#
# Требования: Docker + Compose v2, DNS A-запись домена на этот сервер,
# открытые порты 80/443. Flutter нужен только для сборки Web (опционально).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DOMAIN="${1:-${DOMAIN:-}}"
if [[ -z "$DOMAIN" ]]; then
  echo "Использование: $0 <домен>  (например: $0 arij.example.com)" >&2
  exit 1
fi

# 1. Конфигурация: создаём .env и генерируем секреты, если его ещё нет.
if [[ ! -f .env ]]; then
  cp .env.example .env
  sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -hex 32)|" .env
  sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -hex 24)|" .env
  echo "Создан .env со сгенерированными JWT_SECRET и DB_PASSWORD"
fi
if grep -q '^DOMAIN=' .env; then
  sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" .env
else
  echo "DOMAIN=$DOMAIN" >> .env
fi

# 2. Веб-клиент: собираем, если доступен Flutter и сборки ещё нет.
mkdir -p deploy/www
if [[ -f pubspec.yaml ]] && command -v flutter >/dev/null 2>&1 && [[ ! -f deploy/www/index.html ]]; then
  echo "Сборка Flutter Web с API_BASE_URL=https://$DOMAIN"
  flutter build web --release \
    --dart-define="API_BASE_URL=https://$DOMAIN" \
    -o deploy/www
fi

# 3. Docker CLI (на Windows может отсутствовать в PATH).
if command -v docker >/dev/null 2>&1; then
  DK=docker
elif [[ -x "/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]]; then
  DK="/c/Program Files/Docker/Docker/resources/bin/docker.exe"
else
  echo "Docker CLI не найден" >&2
  exit 1
fi

# 4. Поднимаем postgres + server + Caddy (Caddy сам выпустит TLS-сертификат).
"$DK" compose --env-file .env -f deploy/docker-compose.prod.yml up -d --build

echo ""
echo "Готово:"
echo "  API:   https://$DOMAIN/health"
echo "  Web:   https://$DOMAIN/  (если собран deploy/www)"
echo "  Логи:  $DK compose -f deploy/docker-compose.prod.yml logs -f"
