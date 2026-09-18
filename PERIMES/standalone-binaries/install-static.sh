#!/usr/bin/env bash
set -euo pipefail
DEST="${1:-$HOME/.local/bin}"
mkdir -p "$DEST"
cp "$(dirname "$0")/bin/"* "$DEST/"
echo "Ajoute $DEST à ton PATH si ce n'est pas déjà fait."
