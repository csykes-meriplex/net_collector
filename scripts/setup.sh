#!/usr/bin/env bash
# Bootstrap script — generates secrets and creates .env on first run.
# Safe to re-run; existing values are never overwritten.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
ENV_EXAMPLE="$ROOT/.env.example"

echo "=== net-collector setup ==="

if ! command -v openssl &>/dev/null; then
  echo "ERROR: openssl is required but not found." >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Created .env"
fi

set_secret() {
  local key="$1"
  local length="${2:-32}"
  local current
  current=$(grep "^${key}=" "$ENV_FILE" | cut -d'=' -f2-)
  if [ "$current" = "CHANGE_ME" ]; then
    local value
    value=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "$length")
    sed -i "s|^${key}=CHANGE_ME|${key}=${value}|" "$ENV_FILE"
    echo "  Generated: ${key}"
  else
    echo "  Exists:    ${key} (skipped)"
  fi
}

echo ""
echo "Generating secrets..."
set_secret DB_PASSWORD 32
set_secret DB_ROOT_PASSWORD 32
set_secret INFLUXDB_ADMIN_PASSWORD 32
set_secret INFLUXDB_ADMIN_TOKEN 64
set_secret GRAFANA_ADMIN_PASSWORD 24

HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_HOST_IP")
GRAFANA_PASS=$(grep "^GRAFANA_ADMIN_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2-)

echo ""
echo "=== Setup complete ==="
echo ""
echo "Start the stack:"
echo "  docker compose up -d"
echo ""
echo "Service URLs (allow ~90s for first-time DB/ClickHouse init):"
echo "  LibreNMS  → https://${HOST_IP}/"
echo "  Grafana   → https://${HOST_IP}:3000/"
echo "  Akvorado  → https://${HOST_IP}:8080/"
echo "  Oxidized  → https://${HOST_IP}:8888/"
echo ""
echo "Flow collectors (send device sFlow/NetFlow here):"
echo "  sFlow     → ${HOST_IP}:6343/udp"
echo "  NetFlow   → ${HOST_IP}:2055/udp"
echo ""
echo "Credentials:"
echo "  LibreNMS  admin / admin  (change immediately)"
echo "  Grafana   admin / ${GRAFANA_PASS}"
echo ""
echo "──────────────────────────────────────────────────────"
echo "POST-STARTUP STEPS:"
echo ""
echo "After 'docker compose up -d', run:"
echo "  bash scripts/init-oxidized.sh"
echo ""
echo "That script waits for LibreNMS to be ready, generates"
echo "an API token, injects it into Oxidized, and restarts it."
echo ""
echo "Grafana → Connections → Akvorado datasource"
echo "  URL: https://${HOST_IP}:8080/"
echo "  (akvorado-datasource plugin is auto-installed)"
echo "──────────────────────────────────────────────────────"
