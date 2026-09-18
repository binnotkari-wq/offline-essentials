#!/usr/bin/env bash
set -euo pipefail
BIN_DIR="$(dirname "$0")/bin"
mkdir -p "$BIN_DIR"

# Exemple - à dupliquer par outil, en épinglant la version
curl -Lo "$BIN_DIR/just" \
  "https://github.com/casey/just/releases/download/1.36.0/just-1.36.0-x86_64-unknown-linux-musl.tar.gz"
# cosign a des binaires statiques officiels par plateforme sur ses releases GitHub
curl -Lo "$BIN_DIR/cosign" \
  "https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64"
chmod +x "$BIN_DIR"/*




just
jq
llama
kiwix
glow
mdcat
