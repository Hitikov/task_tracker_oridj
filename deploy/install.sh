#!/usr/bin/env bash
# Arij — установка и запуск на Debian/Ubuntu одной командой.
#   curl -fsSL <raw-install.sh> | sudo bash -s -- <домен или IP>
set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Использование: $0 <домен или IP>" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Нужны root-права: запустите через sudo" >&2
  exit 1
fi

. /etc/os-release
case "$ID" in
  debian|ubuntu) ;;
  *) echo "Поддерживаются Debian и Ubuntu (получено: $ID)" >&2; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive

echo "==> Починка возможных незавершённых операций dpkg"
dpkg --configure -a || true
apt-get --fix-broken install -y || true

echo "==> Установка системных пакетов"
apt-get update
apt-get install -y ca-certificates curl gnupg git openssl

echo "==> Удаление конфликтующих пакетов Docker (если есть)"
apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

echo "==> Установка Docker и Compose v2"
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "==> Получение исходников Arij"
if [[ ! -d task_tracker_oridj/.git ]]; then
  git clone --depth 1 -b feature/stage-4-mvp-polish \
    https://github.com/Hitikov/task_tracker_oridj.git
fi
cd task_tracker_oridj

echo "==> Запуск прод-контура (postgres + server + caddy)"
bash deploy/deploy.sh "$TARGET"

API="$(grep '^API_BASE_URL=' .env | cut -d= -f2-)"
echo ""
echo "Установка завершена:"
echo "  $API/health"
echo "  $API/  (если собран Web)"
