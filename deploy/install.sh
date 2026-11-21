#!/usr/bin/env bash
# Arij — установка и запуск на Debian/Ubuntu одной командой.
#   curl -fsSL <raw-install.sh> | sudo bash -s -- arij.example.com
set -euo pipefail

DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
  echo "Использование: $0 <домен>  (например: $0 arij.example.com)" >&2
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

echo "==> Установка системных пакетов"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg git openssl >/dev/null

echo "==> Установка Docker и Compose v2"
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
systemctl enable --now docker

echo "==> Получение исходников Arij"
if [[ ! -d task_tracker_oridj/.git ]]; then
  git clone --depth 1 -b feature/stage-4-mvp-polish \
    https://github.com/Hitikov/task_tracker_oridj.git
fi
cd task_tracker_oridj

echo "==> Запуск прод-контура (postgres + server + caddy)"
bash deploy/deploy.sh "$DOMAIN"

echo ""
echo "Установка завершена:"
echo "  https://$DOMAIN/health"
echo "  https://$DOMAIN/   (если собран Web)"
