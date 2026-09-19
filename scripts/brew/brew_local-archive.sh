#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SNAPSHOT="$REPO_DIR/linuxbrew-snapshot.tar.gz"

# Archiver tout le prefix
echo "Archivage de /home/linuxbrew..."
sudo tar czf "$SNAPSHOT" -C / home/linuxbrew

echo "Snapshot créé : $SNAPSHOT"
