#!/usr/bin/env bash
# Generates a JWT signed with the dev HMAC key for local development.
# Reads jwt.secret-key and jwt.audience from application-dev.yaml (single source of truth).
# Requires: python3 with PyJWT
# Usage: ./scripts/generate-token.sh [subject]

set -euo pipefail

SUBJECT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../src/main/resources/application-dev.yaml"

SECRET=$(grep 'secret-key:' "$CONFIG_FILE" | head -1 | awk '{print $2}')
AUDIENCE=$(grep 'audience:' "$CONFIG_FILE" | head -1 | awk '{print $2}')

if [ -z "$SECRET" ]; then
    echo "Error: could not read jwt.secret-key from $CONFIG_FILE"
    exit 1
fi

if command -v python3 &>/dev/null && python3 -c "import jwt" 2>/dev/null; then
    TOKEN=$(JWT_SUBJECT="$SUBJECT" JWT_SECRET="$SECRET" JWT_AUDIENCE="${AUDIENCE:-}" python3 -c "
import jwt, time, os
payload = {
    'sub': os.environ['JWT_SUBJECT'],
    'iat': int(time.time()),
    'exp': int(time.time()) + 86400,
    'iss': 'dev'
}
audience = os.environ.get('JWT_AUDIENCE', '')
if audience:
    payload['aud'] = audience
print(jwt.encode(payload, os.environ['JWT_SECRET'], algorithm='HS256'))
")
    echo "JWT Token (valid 24h):"
    echo "$TOKEN"
    echo ""
    echo "Use it against any protected endpoint you add to the template, for example:"
    echo "  curl -H 'Authorization: Bearer $TOKEN' http://localhost:8080/api/your-endpoint"
else
    echo "Error: python3 with PyJWT is required."
    echo "Install: pip3 install PyJWT"
    exit 1
fi
