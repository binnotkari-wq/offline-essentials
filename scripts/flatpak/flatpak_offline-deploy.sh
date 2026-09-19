#!/usr/bin/env bash
# Installe/actualise les flatpaks listés dans "flatpaks.list" à partir du dépôt
# OSTree sideload (REPO_DIR/.ostree/repo, généré par flatpak_local-archive.sh
# et copié sur cette machine). Le remote d'origine doit y être configuré
# avec le même collection-id que sur la machine source.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LIST_FILE="${LIST_FILE:-${SCRIPT_DIR}/flatpaks.list}"
REPO_DIR="${REPO_DIR:-${SCRIPT_DIR}}"
SIDELOAD_REPO="${REPO_DIR}/.ostree/repo"
REMOTE="${REMOTE:-flathub}"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
COLLECTION_ID="${COLLECTION_ID:-org.flathub.Stable}"

log() { printf '[offline-deploy] %s\n' "$*"; }

main() {
	command -v flatpak >/dev/null 2>&1 || { echo "flatpak absent." >&2; exit 1; }
	[[ -d "${SIDELOAD_REPO}" ]] || { echo "Dépôt introuvable : ${SIDELOAD_REPO}" >&2; exit 1; }
	[[ -f "${LIST_FILE}" ]] || { echo "Fichier introuvable : ${LIST_FILE}" >&2; exit 1; }

	log "début"

	flatpak remote-list | awk '{print $1}' | grep -qx "${REMOTE}" ||
		flatpak remote-add --if-not-exists "${REMOTE}" "${FLATHUB_URL}"

	local current_cid
	current_cid="$(flatpak remotes -d | awk -v r="${REMOTE}" '$1==r{print $NF}')"
	[[ "${current_cid}" == "${COLLECTION_ID}" ]] ||
		flatpak remote-modify --collection-id="${COLLECTION_ID}" "${REMOTE}"

	local count=0
	while IFS= read -r app_id; do
		app_id="${app_id%%#*}"
		app_id="$(echo "${app_id}" | xargs)"
		[[ -z "${app_id}" ]] && continue

		log "installation/mise à jour : ${app_id}"
		flatpak install --noninteractive -y --or-update \
			--sideload-repo="${SIDELOAD_REPO}" "${REMOTE}" "${app_id}"
		count=$((count + 1))
	done <"${LIST_FILE}"

	log "fin (${count} apps)"
}

main "$@"
