#!/usr/bin/env bash
# Generates a LibreNMS API token and wires it into the Oxidized config.
# Run once after: docker compose up -d
# Safe to re-run — exits early if a token is already set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OXIDIZED_CONFIG="$ROOT/config/oxidized/config"

if ! grep -q "LIBRENMS_API_TOKEN_PLACEHOLDER" "$OXIDIZED_CONFIG"; then
  echo "Oxidized already has a token configured. Nothing to do."
  exit 0
fi

# Load secrets from .env
if [ -f "$ROOT/.env" ]; then
  set -a; source "$ROOT/.env"; set +a
else
  echo "ERROR: .env not found. Run scripts/setup.sh first." >&2
  exit 1
fi

cd "$ROOT"

echo "Waiting for LibreNMS to be healthy..."
until docker compose exec -T librenms curl -sf http://localhost:8000/api/v0/system > /dev/null 2>&1; do
  printf "."
  sleep 5
done
echo " ready."

# Generate a 40-hex-char token and insert directly into LibreNMS DB.
# LibreNMS stores tokens as plain text in api_tokens.token_hash —
# the X-Auth-Token header value is matched directly against this column.
TOKEN=$(openssl rand -hex 20)

docker compose exec -T mariadb mysql \
  -ulibrenms \
  -p"${DB_PASSWORD}" \
  librenms \
  -e "INSERT INTO api_tokens (user_id, token_hash, description, disabled)
      VALUES (1, '${TOKEN}', 'oxidized-auto', 0);" 2>/dev/null

echo "Token inserted into LibreNMS."

# Patch the Oxidized config
sed -i "s|LIBRENMS_API_TOKEN_PLACEHOLDER|${TOKEN}|g" "$OXIDIZED_CONFIG"
echo "Token written to config/oxidized/config"

docker compose restart oxidized
echo "Oxidized restarted."
echo ""
echo "Tail logs to confirm it's pulling devices:"
echo "  docker compose logs -f oxidized"
