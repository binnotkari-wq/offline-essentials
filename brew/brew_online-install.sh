#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMULAS_FILE="$REPO_DIR/formulas.txt"

# 1. Installer brew (si pas déjà présent)
if ! command -v brew >/dev/null 2>&1 && [[ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Brew déjà installé, étape sautée."
fi

# Ajout du path dans .bashrc, une seule fois
if ! grep -q 'linuxbrew/.linuxbrew/bin/brew shellenv' ~/.bashrc 2>/dev/null; then
    cp -f "~/.bashrc" "~/.bashrc.backup"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
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
