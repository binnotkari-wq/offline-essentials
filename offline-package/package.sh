#!/usr/bin/env bash
#
# package.sh
#
# Empaquette le kit offline-essentials (ressources/, flatpak-repo/,
# reading_tools/) en un unique fichier SquashFS : compressé, en lecture
# seule par construction (contrairement à un simple tar/dossier, un
# SquashFS ne peut pas être remonté en écriture), facile à copier ou
# transférer tel quel. Un fichier .sha256 est généré à côté pour
# vérifier l'intégrité après transfert (équivalent du MD5 de l'ISO).
#
# Idempotent : régénère systématiquement l'archive à partir du contenu
# courant du dépôt (-noappend), donc reproductible d'un run à l'autre
# si le contenu source n'a pas changé.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
OUTPUT_FILE="${OUTPUT_FILE:-${SCRIPT_DIR}/offline-essentials.sqfs}"
COMPRESSION="${COMPRESSION:-zstd}"
COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-3}"

# Contenu à empaqueter : tout le dépôt sauf le .git, le justfile et les
# scripts d'empaquetage/CI (le kit livré est un jeu de données, pas les
# outils qui l'ont produit).
SOURCE_DIRS=(flatpak-repo ressources reading_tools)

log()  { printf '[package] %s\n' "$*"; }
die()  { printf '[package] ERREUR: %s\n' "$*" >&2; exit 1; }

command -v mksquashfs >/dev/null 2>&1 || die "mksquashfs n'est pas installé (paquet squashfs-tools)."
command -v sha256sum  >/dev/null 2>&1 || die "sha256sum n'est pas installé."

cd "${SCRIPT_DIR}"

existing_dirs=()
for d in "${SOURCE_DIRS[@]}"; do
    if [[ -d "${d}" ]]; then
        existing_dirs+=("${d}")
    else
        log "AVERTISSEMENT: dossier absent, ignoré : ${d}"
    fi
done
[[ ${#existing_dirs[@]} -gt 0 ]] || die "Aucun dossier source trouvé (${SOURCE_DIRS[*]})."

log "Compression : ${COMPRESSION} (niveau ${COMPRESSION_LEVEL})"
log "Contenu     : ${existing_dirs[*]}"
log "Sortie      : ${OUTPUT_FILE}"

rm -f "${OUTPUT_FILE}"
mksquashfs "${existing_dirs[@]}" "${OUTPUT_FILE}" \
    -comp "${COMPRESSION}" -Xcompression-level "${COMPRESSION_LEVEL}" \
    -noappend

sha256sum "${OUTPUT_FILE}" > "${OUTPUT_FILE}.sha256"

SIZE_HUMAN="$(du -h "${OUTPUT_FILE}" | cut -f1)"
log "OK  Archive créée : ${OUTPUT_FILE} (${SIZE_HUMAN})"
log "OK  Somme de contrôle : ${OUTPUT_FILE}.sha256"
log ""
log "Vérification après transfert :"
log "  sha256sum -c $(basename "${OUTPUT_FILE}").sha256"
log ""
log "Montage en lecture seule (nécessite root ou un utilisateur avec accès aux loop devices) :"
log "  sudo mkdir -p /mnt/offline-essentials"
log "  sudo mount -o loop,ro $(basename "${OUTPUT_FILE}") /mnt/offline-essentials"
