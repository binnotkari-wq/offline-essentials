#!/usr/bin/env bash
#
# image_mount.sh
#
# Vérifie l'intégrité puis monte le fichier SquashFS offline-essentials
# en lecture seule.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
IMAGE_FILE="${1:-${SCRIPT_DIR}/offline-essentials.sqfs}"
MOUNT_POINT="${2:-/mnt/offline-essentials}"

log()  { printf '[mount] %s\n' "$*"; }
die()  { printf '[mount] ERREUR: %s\n' "$*" >&2; exit 1; }

[[ -f "${IMAGE_FILE}" ]] || die "Fichier introuvable : ${IMAGE_FILE}"
[[ -f "${IMAGE_FILE}.sha256" ]] || die "Somme de contrôle introuvable : ${IMAGE_FILE}.sha256"

( cd "$(dirname -- "${IMAGE_FILE}")" && sha256sum -c "$(basename -- "${IMAGE_FILE}").sha256" ) \
    || die "Vérification sha256 échouée."

sudo mkdir -p "${MOUNT_POINT}"
sudo mount -o loop,ro "${IMAGE_FILE}" "${MOUNT_POINT}"

log "OK  Monté : ${IMAGE_FILE} -> ${MOUNT_POINT}"
