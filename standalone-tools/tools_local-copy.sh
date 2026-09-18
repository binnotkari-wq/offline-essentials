#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$HOME/.local/bin"
SHARE_DEST="$HOME/.local/share"
mkdir -p "$BIN_DEST" "$SHARE_DEST"

already_present() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "-- $1 déjà présent sur le système, groupe ignoré"
    return 0
  fi
  return 1
}

# glow / just / mdcat : binaires indépendants, un test chacun
for name in glow just mdcat; do
  already_present "$name" && continue
  cp -rf "$SRC/$name" "$SHARE_DEST/$name"
  ln -sf "$SHARE_DEST/$name/$name" "$BIN_DEST/$name"
  echo "==> $name installé"
done

# kiwix-tools : groupe, test sur kiwix-serve
if ! already_present "kiwix-serve"; then
  cp -rf "$SRC/kiwix-tools" "$SHARE_DEST/kiwix-tools"
  for bin in "$SHARE_DEST"/kiwix-tools/*; do
    cp -f "$bin" "$BIN_DEST/$(basename "$bin")"
  done
  echo "==> kiwix-tools installé"
fi

# distrobox : groupe, test sur distrobox
if ! already_present "distrobox"; then
  cp -rf "$SRC/distrobox" "$SHARE_DEST/distrobox"
  for bin in "$SHARE_DEST"/distrobox/bin/*; do
    cp -f "$bin" "$BIN_DEST/$(basename "$bin")"
  done
  cp -rf "$SHARE_DEST/distrobox/share/." "$SHARE_DEST/"
  echo "==> distrobox installé"
fi

# llama.cpp : groupe, test sur llama-server
if ! already_present "llama-server"; then
  cp -rf "$SRC/llama.cpp" "$SHARE_DEST/llama.cpp"
  for name in llama-cli llama-server llama-quantize llama-bench; do
    cat > "$BIN_DEST/$name" <<EOF
#!/usr/bin/env bash
export LD_LIBRARY_PATH="$SHARE_DEST/llama.cpp:\${LD_LIBRARY_PATH:-}"
exec "$SHARE_DEST/llama.cpp/$name" "\$@"
EOF
    chmod +x "$BIN_DEST/$name"
  done
  echo "==> llama.cpp installé"
fi
