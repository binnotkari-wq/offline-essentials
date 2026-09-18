#!/usr/bin/env bash
# Installe les flatpaks listés dans le fichier "flatpaks" (un id par ligne).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LIST_FILE="${LIST_FILE:-${SCRIPT_DIR}/flatpaks}"
REMOTE="${REMOTE:-flathub}"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

log() { printf '[online-install] %s\n' "$*"; }

main() {
	command -v flatpak >/dev/null 2>&1 || { echo "flatpak absent." >&2; exit 1; }
	[[ -f "${LIST_FILE}" ]] || { echo "Fichier introuvable : ${LIST_FILE}" >&2; exit 1; }

	log "début"

	flatpak remote-list | awk '{print $1}' | grep -qx "${REMOTE}" ||
		flatpak remote-add --if-not-exists "${REMOTE}" "${FLATHUB_URL}"

	local count=0
	while IFS= read -r app_id; do
		app_id="${app_id%%#*}"
		app_id="$(echo "${app_id}" | xargs)"
		[[ -z "${app_id}" ]] && continue

		if ! flatpak info "${app_id}" >/dev/null 2>&1; then
			log "installation : ${app_id}"
			flatpak install --noninteractive -y "${REMOTE}" "${app_id}"
		fi
		count=$((count + 1))
	done <"${LIST_FILE}"

	log "fin (${count} apps)"
}

main "$@"
