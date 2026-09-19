#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="toolbox"
EXPORT_PATH="${HOME}/.local/bin"

distrobox create --image toolbox:latest --name "$CONTAINER_NAME" --yes

# Binaires à exporter du conteneur vers l'hôte. Si une commande du même nom
# est déjà trouvable sur l'hôte (/usr/bin ou ~/.local/bin), on ne l'écrase
# pas : l'hôte a la priorité sur ce qu'offre le conteneur.
binaries=(
    aria2c
    bat
    btop
    cliphist
    createrepo_c
    dialog
    duf
    fd
    fzf
    glow
    groff
    checkisomd5
    implantisomd5
    jq
    kiwix-manage
    kiwix-search
    kiwix-serve
    av1encode
    avcenc
    avcstreamoutdemo
    h264encode
    hevcencode
    jpegenc
    loadjpeg
    magick
    mpeg2vaenc
    mpeg2vldemo
    putsurface
    putsurface_wayland
    sfcsample
    vacopy
    vainfo
    vavpp
    vp8enc
    vp9enc
    vpp3dlut
    vppblending
    vppchromasitting
    vppdenoise
    vpphdr_tm
    vppscaling_csc
    vppscaling_n_out_usrptr
    vppsharpness
    sensors
    sensors-detect
    man2html
    mc
    msedit
    pandoc
    powertop
    s-tui
    shellcheck
    shfmt
    smartctl
    smartd
    stress-ng
    tldr
    tmux
    yt-dlp
    zoxide
)

mkdir -p "$EXPORT_PATH"

for bin in "${binaries[@]}"; do
    if command -v "$bin" >/dev/null 2>&1; then
        echo "Skip $bin : déjà présent sur l'hôte"
        continue
    fi

    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin "/usr/bin/${bin}" --export-path "${HOME}/.local/bin"
    echo "Exporté : $bin"
done
