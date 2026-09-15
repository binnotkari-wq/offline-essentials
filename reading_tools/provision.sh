#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="${SCRIPT_DIR}/llama"
KIWIX_DIR="${SCRIPT_DIR}/kiwix"
GLOW_DIR="${SCRIPT_DIR}/glow"
MDCAT_DIR="${SCRIPT_DIR}/mdcat"

echo "Provisionnement de llama depuis Github (version vulkan, standalone)"
mkdir -p "${LLAMA_DIR}"
curl -L "https://github.com/ggml-org/llama.cpp/releases/download/b10969/llama-b10969-bin-ubuntu-vulkan-x64.tar.gz" | tar -xz -C "${LLAMA_DIR}" --strip-components=1
echo "✅ llama provisionné avec succès."
echo "Exemple d'utilisation : ./llama-server -t 4 -c 4096 -m ../../ressources/llm/Qwen3.5-4B-Q4_K_M.gguf et ouvrir le navigateur : http://127.0.0.1:8080"

echo ""
echo "================================================="
echo ""

echo "Provisionnement de kiwix depuis Github (version standalone)"
mkdir -p "${KIWIX_DIR}"
curl -L "https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64.tar.gz" | tar -xz -C "${KIWIX_DIR}" --strip-components=1
echo "✅ kiwix provisionné avec succès."
echo "Exemple d'utilisation : ./kiwix-serve -p 8081 ../../ressources/zims/devdocs_en_man_2026-07.zim et ouvrir le navigateur : http://127.0.0.1:8081"

echo ""
echo "================================================="
echo ""

echo "Provisionnement de glow depuis Github (version standalone)"
mkdir -p "${GLOW_DIR}"
curl -L "https://github.com/charmbracelet/glow/releases/download/v2.1.2/glow_2.1.2_Linux_x86_64.tar.gz" | tar -xz -C "${GLOW_DIR}" --strip-components=1
echo "✅ glow provisionné avec succès."
echo "Exemple d'utilisation : ./glow chemin/vers/fichier.md"

echo ""
echo "================================================="
echo ""

echo "Provisionnement de mdcat depuis Github (version standalone)"
mkdir -p "${MDCAT_DIR}"
curl -L "https://github.com/swsnr/mdcat/releases/download/mdcat-2.1.1/mdcat-2.1.1-x86_64-unknown-linux-musl.tar.gz" | tar -xz -C "${MDCAT_DIR}" --strip-components=1
echo "✅ mdcat provisionné avec succès."
echo "Exemple d'utilisation : ./mdcat-2.1.1-x86_64-unknown-linux-musl/mdcat chemin/vers/fichier.md"
