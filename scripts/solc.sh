#!/bin/sh

SOLC_PATH="$(command -v solc)"

if [ -z "$SOLC_PATH" ]; then
  echo "solc was not found on PATH" >&2
  exit 1
fi

exec "$SOLC_PATH" "$@"
