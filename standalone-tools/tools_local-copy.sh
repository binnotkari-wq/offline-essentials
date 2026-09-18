#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$HOME/.local/bin"
SHARE_DEST="$HOME/.local/share"
mkdir -p "$BIN_DEST" "$SHARE_DEST"

link_if_absent() {
  local target="$1" linkname="$2"
  if command -v "$linkname" >/dev/null 2>&1; then
    echo "-- $linkname déjà présent sur le système, ignoré"
    return
  fi
  ln -sf "$target" "$BIN_DEST/$linkname"
  echo "==> $linkname -> $target"
}

# glow / just / mdcat : binaire unique, dossier conservé pour les fichiers annexes (.md, completions...)
link_if_absent "$SRC/glow/glow" "glow"
link_if_absent "$SRC/just/just" "just"
link_if_absent "$SRC/mdcat/mdcat" "mdcat"

# kiwix-tools : uniquement des exécutables -> copie dans ~/.local/bin
for bin in "$SRC"/kiwix-tools/*; do
  name="$(basename "$bin")"
  if command -v "$name" >/dev/null 2>&1; then
    echo "-- $name déjà présent sur le système, ignoré"
    continue
  fi
  cp -f "$bin" "$BIN_DEST/$name"
  echo "==> $name copié"
done

# distrobox : bin/ contient uniquement des exécutables -> copie dans ~/.local/bin
#             share/ contient des assets (man, completions...) -> copie dans ~/.local/share
for bin in "$SRC"/distrobox/bin/*; do
  name="$(basename "$bin")"
  if command -v "$name" >/dev/null 2>&1; then
    echo "-- $name déjà présent sur le système, ignoré"
    continue
  fi
  cp -f "$bin" "$BIN_DEST/$name"
  echo "==> $name copié"
done
cp -rf "$SRC/distrobox/share/." "$SHARE_DEST/"

# llama.cpp : binaires + .so interdépendants -> wrapper shell exportant LD_LIBRARY_PATH
LLAMA_BINS=("llama-cli" "llama-server" "llama-quantize" "llama-bench")
for name in "${LLAMA_BINS[@]}"; do
  if command -v "$name" >/dev/null 2>&1; then
    echo "-- $name déjà présent sur le système, ignoré"
    continue
  fi
  cat > "$BIN_DEST/$name" <<EOF
#!/usr/bin/env bash
export LD_LIBRARY_PATH="$SRC/llama.cpp:\${LD_LIBRARY_PATH:-}"
exec "$SRC/llama.cpp/$name" "\$@"
EOF
  chmod +x "$BIN_DEST/$name"
  echo "==> wrapper $name créé"
done
