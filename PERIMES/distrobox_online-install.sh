#!/usr/bin/env bash
set -euo pipefail

BOX_NAME="fedora-tools"

# Installer distrobox
curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/legacy/install | sh

# Création de la distrobox
if distrobox list | grep -q "^${BOX_NAME}\b"; then
    echo "La box '${BOX_NAME}' existe déjà, on continue."
else
    distrobox create --name "${BOX_NAME}" --image fedora:latest
fi

# Installation des paquets
distrobox enter "${BOX_NAME}" -- sudo dnf install -y "${PACKAGES[@]}"

# Export des binaires dans ~/.local/bin
mkdir -p ~/.local/bin
for bin in "${BINARIES[@]}"; do
    distrobox enter "${BOX_NAME}" -- distrobox-export --bin "/usr/bin/${bin}" --export-path "${HOME}/.local/bin"
done
