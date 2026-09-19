#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="$(cd "$(dirname "$0")/../../dataset/brew" && pwd)"
SNAPSHOT="$DATA_DIR/linuxbrew-snapshot.tar.gz"

mkdir -p "$DATA_DIR"

# Archiver tout le prefix
echo "Archivage de /home/linuxbrew..."
sudo tar czf "$SNAPSHOT" -C / home/linuxbrew

echo "Snapshot créé : $SNAPSHOT"
