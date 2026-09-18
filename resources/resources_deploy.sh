#!/usr/bin/env bash
# deploy.sh - copie le dossier resources/ vers ~/resources (copie incrémentale via cp -au)
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TARGET="${HOME}/resources"

log() { printf '[deploy] %s\n' "$*"; }

log "Copie de ${DIR} vers ${TARGET}..."
mkdir -p "${TARGET}"
cp -au "${DIR}/." "${TARGET}/"
log "Terminé sans erreur."
