#!/usr/bin/env bash
set -euo pipefail

# Prérequis : distrobox_create.sh doit avoir été exécuté avant ce script,
# la distrobox doit déjà exister pour qu'on puisse y entrer et l'initialiser.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/toolbox.tar"
CONTAINER_NAME="toolbox"
IMAGE_NAME="toolbox:latest"

# Déclenche distrobox-init une première (et unique) fois, pendant qu'on est
# encore en ligne : cela pose un marqueur dans le conteneur qui lui évitera
# de rejouer ses vérifications réseau (dnf list...) une fois hors-ligne.
distrobox enter "$CONTAINER_NAME" -- true

# Fige le conteneur déjà initialisé (et pas juste l'image buildée) :
# le marqueur d'initialisation est inclus dans l'export.
podman commit "$CONTAINER_NAME" "$IMAGE_NAME"
podman save "$IMAGE_NAME" -o "$OUTPUT_FILE"

echo "Conteneur initialisé exporté : $OUTPUT_FILE"
