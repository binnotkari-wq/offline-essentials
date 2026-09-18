#!/usr/bin/env bash
set -euo pipefail

DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$DEST"

# URLs figées manuellement — dernières versions repérées au 18/09/2026
# À revérifier/mettre à jour manuellement en cas de besoin (pas de résolution "latest" automatique)

declare -A TOOLS=(
  [glow]="https://github.com/charmbracelet/glow/releases/download/v2.1.2/glow_2.1.2_Linux_x86_64.tar.gz"
  [mdcat]="https://github.com/swsnr/mdcat/releases/download/mdcat-2.1.1/mdcat-2.1.1-x86_64-unknown-linux-musl.tar.gz"
  [just]="https://github.com/casey/just/releases/download/1.36.0/just-1.36.0-x86_64-unknown-linux-musl.tar.gz"
  [llama.cpp]="https://github.com/ggml-org/llama.cpp/releases/download/b10969/llama-b10969-bin-ubuntu-vulkan-x64.tar.gz"
)

# Outils dont l'archive encapsule son contenu dans un sous-dossier versionné
STRIP_TOOLS=("glow" "mdcat" "llama.cpp")

for name in "${!TOOLS[@]}"; do
  echo "==> $name"
  mkdir -p "$DEST/$name"
  curl -sL "${TOOLS[$name]}" -o "$DEST/$name/archive.tar.gz"
  if [[ " ${STRIP_TOOLS[*]} " == *" $name "* ]]; then
    tar -xzf "$DEST/$name/archive.tar.gz" -C "$DEST/$name" --strip-components=1
  else
    tar -xzf "$DEST/$name/archive.tar.gz" -C "$DEST/$name"
  fi
  rm "$DEST/$name/archive.tar.gz"
done

# kiwix-tools : URL stable, archive encapsulée dans un sous-dossier versionné
mkdir -p "$DEST/kiwix-tools"
curl -sL https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64.tar.gz \
  -o "$DEST/kiwix-tools/archive.tar.gz"
tar -xzf "$DEST/kiwix-tools/archive.tar.gz" -C "$DEST/kiwix-tools" --strip-components=1
rm "$DEST/kiwix-tools/archive.tar.gz"

# distrobox : script d'install, prefix dédié — chemin ABSOLU requis (le script change de cwd en interne)
mkdir -p "$DEST/distrobox"
curl -sL https://raw.githubusercontent.com/89luca89/distrobox/main/install -o /tmp/distrobox-install.sh
chmod +x /tmp/distrobox-install.sh
/tmp/distrobox-install.sh --prefix "$DEST/distrobox"
