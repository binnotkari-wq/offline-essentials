#!/usr/bin/env bash
set -euo pipefail

echo "Archivage de la distrobox fedora-tools..."
podman commit fedora-tools fedora-tools:backup
podman save -o fedora-tools.tar fedora-tools:backup
echo "Snapshot créé : fedora-tools.tar"
