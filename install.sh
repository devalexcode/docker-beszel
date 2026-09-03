#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
ENV_EXAMPLE="$PROJECT_DIR/.env.example"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

[[ -f "$ENV_EXAMPLE" ]] || fail 'No se encontró .env.example.'
[[ -f "$PROJECT_DIR/docker-compose.yml" ]] || fail 'No se encontró docker-compose.yml.'

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  printf 'Se creó .env a partir de .env.example.\n'
else
  printf 'Se conservará el archivo .env existente.\n'
fi

mkdir -p \
  "$PROJECT_DIR/beszel_data" \
  "$PROJECT_DIR/beszel_agent_data" \
  "$PROJECT_DIR/beszel_socket"

cd "$PROJECT_DIR"
docker compose up -d

printf '\nBeszel está en marcha.\n'
printf 'Configura BESZEL_APP_URL en .env y publica el Hub con tu proxy HTTPS.\n'
printf 'Después de crear el sistema en Beszel, añade BESZEL_AGENT_TOKEN y BESZEL_AGENT_KEY a .env y ejecuta:\n'
printf '  docker compose up -d --force-recreate beszel-agent\n'
