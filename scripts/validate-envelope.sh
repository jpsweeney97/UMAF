#!/usr/bin/env bash
set -euo pipefail

SCHEMA="spec/umaf-envelope-v0.5.0.json"

if [ $# -lt 1 ]; then
  echo "Usage: $0 path/to/envelope.json" >&2
  exit 1
fi

ENVELOPE="$1"

npx ajv validate \
  -s "$SCHEMA" \
  -d "$ENVELOPE"
