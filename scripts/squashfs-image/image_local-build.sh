#!/usr/bin/env bash
#
# image_local-build.sh
#
# Empaquette le dataset en un unique fichier SquashFS.
# Un fichier .sha256 est généré à côté pour vérifier l'intégrité. 

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
OUTPUT_FILE="${OUTPUT_FILE:-${SCRIPT_DIR}/offline-essentials.sqfs}"
SOURCE_DIRS=(dataset scripts justfile README.md)

log()  { printf '[image] %s\n' "$*"; }
die()  { printf '[image] ERREUR: %s\n' "$*" >&2; exit 1; }

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

log "Contenu     : ${existing_dirs[*]}"
log "Sortie      : ${OUTPUT_FILE}"

rm -f "${OUTPUT_FILE}"
mksquashfs "${existing_dirs[@]}" "${OUTPUT_FILE}" \
    -comp zstd -Xcompression-level 3 \
    -noappend

sha256sum "${OUTPUT_FILE}" > "${OUTPUT_FILE}.sha256"

SIZE_HUMAN="$(du -h "${OUTPUT_FILE}" | cut -f1)"
log "OK  Archive créée : ${OUTPUT_FILE} (${SIZE_HUMAN})"
log "OK  Somme de contrôle : ${OUTPUT_FILE}.sha256"
