#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="$(cd "$(dirname "$0")/../../dataset/brew" && pwd)"
SNAPSHOT="$DATA_DIR/linuxbrew-snapshot.tar.gz"

sudo tar xzf "$SNAPSHOT" -C /

# Ajout du path dans .bashrc, une seule fois
if ! grep -q 'linuxbrew/.linuxbrew/bin/brew shellenv' ~/.bashrc 2>/dev/null; then
    cp -f "$HOME/.bashrc" "$HOME/.bashrc.backup"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
fi

if ! grep -q 'HOMEBREW_NO_AUTO_UPDATE' ~/.bashrc 2>/dev/null; then
    echo 'export HOMEBREW_NO_AUTO_UPDATE=1' >> ~/.bashrc
fi

echo "Linuxbrew restauré. Redémarre ton shell ou fais : source ~/.bashrc"
