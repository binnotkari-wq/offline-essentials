#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="$(cd "$(dirname "$0")/../../dataset/distrobox" && pwd)"
INPUT_FILE="${DATA_DIR}/toolbox.tar"

podman load -i "$INPUT_FILE"

echo "Image importée dans le registre local"
