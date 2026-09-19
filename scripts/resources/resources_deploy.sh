#!/usr/bin/env bash
# deploy.sh - copie le dossier resources/ vers ~/resources (copie incrémentale via cp -au)
set -euo pipefail

DATA_DIR="$(cd "$(dirname "$0")/../../dataset/resources" && pwd)"
TARGET="${HOME}/resources"

log() { printf '[deploy] %s\n' "$*"; }

log "Copie de ${DATA_DIR} vers ${TARGET}..."
mkdir -p "${TARGET}"
cp -au "${DATA_DIR}/." "${TARGET}/"
log "Terminé sans erreur."
