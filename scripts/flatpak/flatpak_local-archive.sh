#!/usr/bin/env bash
# Construit/actualise un dépôt OSTree sideload (offline) à partir de la
# liste "flatpaks.list". S'exécute sur une machine où flatpak_online-install.sh
# a déjà tourné (remote configuré, apps déjà installées).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LIST_FILE="${LIST_FILE:-${SCRIPT_DIR}/flatpak.list}"
REPO_DIR="$(cd "$(dirname "$0")/../../dataset/flatpak" && pwd)"
REMOTE="${REMOTE:-flathub}"
COLLECTION_ID="${COLLECTION_ID:-org.flathub.Stable}"

log() { printf '[local-archive] %s\n' "$*"; }

main() {
	command -v flatpak >/dev/null 2>&1 || { echo "flatpak absent." >&2; exit 1; }
	flatpak create-usb --help >/dev/null 2>&1 || { echo "create-usb non supporté par cette version de flatpak." >&2; exit 1; }
	[[ -f "${LIST_FILE}" ]] || { echo "Fichier introuvable : ${LIST_FILE}" >&2; exit 1; }

	log "début"
	mkdir -p "${REPO_DIR}"

	local current_cid
	current_cid="$(flatpak remotes -d | awk -v r="${REMOTE}" '$1==r{print $NF}')"
	[[ "${current_cid}" == "${COLLECTION_ID}" ]] ||
		flatpak remote-modify --collection-id="${COLLECTION_ID}" "${REMOTE}"

	local refs=()
	while IFS= read -r app_id; do
		app_id="${app_id%%#*}"
		app_id="$(echo "${app_id}" | xargs)"
		[[ -n "${app_id}" ]] && refs+=("${app_id}")
	done <"${LIST_FILE}"

	[[ ${#refs[@]} -gt 0 ]] || { echo "Aucune application à archiver." >&2; exit 1; }
	flatpak create-usb "${REPO_DIR}" "${refs[@]}"
	log "fin : dépôt prêt dans ${REPO_DIR}/.ostree/repo (${#refs[@]} apps)"
}

main "$@"
