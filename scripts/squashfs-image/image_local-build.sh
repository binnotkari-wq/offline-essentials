#!/usr/bin/env bash
#
# image_local-build.sh
#
# Empaquette le dataset en un unique fichier SquashFS.
# Un fichier .sha256 est généré à côté pour vérifier l'intégrité. 

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../" && pwd)"
ARCHIVES=(
  "${ROOT_DIR}/dataset"
  "${ROOT_DIR}/scripts"
  "${ROOT_DIR}/justfile"
  "${ROOT_DIR}/README.md"
)

OUTPUT_DIR="$(cd "$(dirname "$0")/../../squashfs-image" && pwd)"
OUTPUT_FILE="${OUTPUT_DIR}/offline-essentials.sqfs"

log()  { printf '[image] %s\n' "$*"; }
die()  { printf '[image] ERREUR: %s\n' "$*" >&2; exit 1; }

command -v mksquashfs >/dev/null 2>&1 || die "mksquashfs n'est pas installé (paquet squashfs-tools)."
command -v sha256sum  >/dev/null 2>&1 || die "sha256sum n'est pas installé."

log "Contenu     : ${ARCHIVES[*]}"
log "Sortie      : ${OUTPUT_FILE}"

mkdir -p "$OUTPUT_DIR"
rm -f "${OUTPUT_FILE}"

mksquashfs "${ARCHIVES[@]}" "${OUTPUT_FILE}" \
    -comp zstd -Xcompression-level 3 \
    -noappend

cd "$OUTPUT_DIR"
sha256sum "offline-essentials.sqfs" > "offline-essentials.sqfs.sha256"

SIZE_HUMAN="$(du -h "${OUTPUT_FILE}" | cut -f1)"
log "OK  Archive créée : ${OUTPUT_FILE} (${SIZE_HUMAN})"
log "OK  Somme de contrôle : ${OUTPUT_FILE}.sha256"

cat > "${OUTPUT_DIR}/image_initial-mount.sh" << EOF
#!/usr/bin/env bash
set -euo pipefail
sudo systemctl daemon-reload
sha256sum -c "offline-essentials.sqfs.sha256"
sudo mkdir -p "/mnt/offline-essentials"
sudo mount -o loop,ro "offline-essentials.sqfs" "/mnt/offline-essentials"
xdg-open /mnt/offline-essentials
EOF

chmod +x "${OUTPUT_DIR}/image_initial-mount.sh"
log "OK  Script de montage initial squashfs créé dans $OUTPUT_DIR"
