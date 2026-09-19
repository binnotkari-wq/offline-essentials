#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

podman build -t toolbox:latest -f "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"
