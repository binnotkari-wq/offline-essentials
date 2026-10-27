#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMULAS_FILE="$SCRIPT_DIR/brew.list"

# 1. Installer brew (si pas déjà présent)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

# Ajout du path dans .bashrc, une seule fois
if ! grep -q 'linuxbrew/.linuxbrew/bin/brew shellenv' ~/.bashrc 2>/dev/null; then
    cp -f "$HOME/.bashrc" "$HOME/.bashrc.backup"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
fi

echo "✅ Brew installé avec succès."

# 2. Installer toutes les formules en une seule commande (résolution unique des dépendances)
mapfile -t formulas < <(grep -vE '^\s*(#|$)' "$FORMULAS_FILE")

if [ "${#formulas[@]}" -eq 0 ]; then
    echo "Aucune formule à installer."
else
    echo "Installation groupée : ${formulas[*]}"
    brew install "${formulas[@]}"
fi
