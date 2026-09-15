#!/usr/bin/env bash
#
# provision.sh
#
# Télécharge et déploie des binaires standalone (llama.cpp, kiwix-tools,
# glow, mdcat) depuis leurs releases GitHub, pour consultation offline
# des ressources du dossier ../ressources (modèles LLM, archives ZIM,
# Markdown).
#
# Idempotent au sens "réexécutable sans casser l'existant" : chaque outil
# est réextrait dans son propre dossier (écrase l'installation précédente),
# aucune donnée utilisateur n'est touchée.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LLAMA_DIR="${SCRIPT_DIR}/llama"
KIWIX_DIR="${SCRIPT_DIR}/kiwix"
GLOW_DIR="${SCRIPT_DIR}/glow"
MDCAT_DIR="${SCRIPT_DIR}/mdcat"

log()  { printf '[provision] %s\n' "$*"; }
die()  { printf '[provision] ERREUR: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl n'est pas installé."
command -v tar  >/dev/null 2>&1 || die "tar n'est pas installé."

# --- llama.cpp (build Vulkan, standalone) -----------------------------------
log "Provisionnement de llama.cpp (version Vulkan, standalone)..."
mkdir -p "${LLAMA_DIR}"
if curl -fL "https://github.com/ggml-org/llama.cpp/releases/download/b10969/llama-b10969-bin-ubuntu-vulkan-x64.tar.gz" \
    | tar -xz -C "${LLAMA_DIR}" --strip-components=1; then
    log "OK  llama.cpp provisionné."
    log "    Usage : ./llama-server -t 4 -c 4096 -m ../../ressources/llm/Qwen3.5-4B-Q4_K_M.gguf"
    log "            puis ouvrir http://127.0.0.1:8080"
else
    log "ÉCHEC provisionnement de llama.cpp."
fi

# --- kiwix-tools (standalone) ------------------------------------------------
log "Provisionnement de kiwix-tools (version standalone)..."
mkdir -p "${KIWIX_DIR}"
if curl -fL "https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64.tar.gz" \
    | tar -xz -C "${KIWIX_DIR}" --strip-components=1; then
    log "OK  kiwix-tools provisionné."
    log "    Usage : ./kiwix-serve -p 8081 ../../ressources/zims/devdocs_en_man_2026-07.zim"
    log "            puis ouvrir http://127.0.0.1:8081"
else
    log "ÉCHEC provisionnement de kiwix-tools."
fi

# --- glow (standalone) -------------------------------------------------------
log "Provisionnement de glow (version standalone)..."
mkdir -p "${GLOW_DIR}"
if curl -fL "https://github.com/charmbracelet/glow/releases/download/v2.1.2/glow_2.1.2_Linux_x86_64.tar.gz" \
    | tar -xz -C "${GLOW_DIR}" --strip-components=1; then
    log "OK  glow provisionné."
    log "    Usage : ./glow chemin/vers/fichier.md"
else
    log "ÉCHEC provisionnement de glow."
fi

# --- mdcat (standalone) -------------------------------------------------------
log "Provisionnement de mdcat (version standalone)..."
mkdir -p "${MDCAT_DIR}"
if curl -fL "https://github.com/swsnr/mdcat/releases/download/mdcat-2.1.1/mdcat-2.1.1-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C "${MDCAT_DIR}" --strip-components=1; then
    log "OK  mdcat provisionné."
    log "    Usage : ./mdcat-2.1.1-x86_64-unknown-linux-musl/mdcat chemin/vers/fichier.md"
else
    log "ÉCHEC provisionnement de mdcat."
fi

log "Terminé."
