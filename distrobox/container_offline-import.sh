#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="${SCRIPT_DIR}/toolbox.tar"

podman load -i "$INPUT_FILE"

echo "Image importée dans le registre local"
