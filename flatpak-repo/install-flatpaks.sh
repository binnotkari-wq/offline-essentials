#!/usr/bin/env bash
#
# install-flatpaks.sh
#
# Installe (ou met à jour) les flatpaks listés dans le JSON en utilisant
# le dépôt OSTree local (REPO_DIR/.ostree/repo, généré par
# download-flatpaks.sh via `flatpak create-usb`) comme source de sideload.
# Fonctionne entièrement hors-ligne une fois REPO_DIR copié sur la machine
# cible, à condition que le remote d'origine (ex: flathub) y soit déjà
# configuré AVEC le même collection-id que sur la machine source.
#
# Idempotent : le collection-id n'est reconfiguré que s'il diffère, et
# flatpak lui-même ne réinstalle pas une app déjà à jour.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
JSON_FILE="${JSON_FILE:-${SCRIPT_DIR}/flatpaks.json}"
REPO_DIR="${REPO_DIR:-${SCRIPT_DIR}/flatpak-repo}"
SIDELOAD_REPO="${REPO_DIR}/.ostree/repo"
DEFAULT_REMOTE="${DEFAULT_REMOTE:-flathub}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-stable}"
FLATHUB_URL="${FLATHUB_URL:-https://dl.flathub.org/repo/flathub.flatpakrepo}"
FLATHUB_COLLECTION_ID="${FLATHUB_COLLECTION_ID:-org.flathub.Stable}"

log()  { printf '[install-flatpaks] %s\n' "$*"; }
die()  { printf '[install-flatpaks] ERREUR: %s\n' "$*" >&2; exit 1; }

command -v flatpak >/dev/null 2>&1 || die "flatpak n'est pas installé."
command -v jq      >/dev/null 2>&1 || die "jq n'est pas installé."
[[ -d "${SIDELOAD_REPO}" ]] || die "Dépôt OSTree introuvable : ${SIDELOAD_REPO} (copiez le dossier ${REPO_DIR} généré par download-flatpaks.sh)."
[[ -f "${JSON_FILE}" ]] || die "Fichier JSON introuvable : ${JSON_FILE}"

# --- Remote d'origine + collection-id (nécessaire même hors-ligne, pour --
# --- que flatpak sache faire correspondre le contenu du dépôt sideloadé ----
if ! flatpak remote-list | awk '{print $1}' | grep -qx "${DEFAULT_REMOTE}"; then
    log "Ajout du remote '${DEFAULT_REMOTE}' (métadonnées seules, pas de contact réseau nécessaire au install --sideload-repo)..."
    flatpak remote-add --if-not-exists "${DEFAULT_REMOTE}" "${FLATHUB_URL}" || \
        die "Impossible d'ajouter le remote '${DEFAULT_REMOTE}'. Ajoutez-le manuellement avant de relancer ce script."
else
    log "Remote '${DEFAULT_REMOTE}' déjà présent."
fi

current_cid="$(flatpak remotes -d | awk -v r="${DEFAULT_REMOTE}" '$1==r{print $NF}')"
if [[ "${current_cid}" != "${FLATHUB_COLLECTION_ID}" ]]; then
    log "Configuration du collection-id '${FLATHUB_COLLECTION_ID}' sur '${DEFAULT_REMOTE}' (requis pour le sideload)..."
    flatpak remote-modify --collection-id="${FLATHUB_COLLECTION_ID}" "${DEFAULT_REMOTE}"
else
    log "Collection-id déjà configuré sur '${DEFAULT_REMOTE}'."
fi

# --- Installation de chaque app listée dans le JSON, via sideload ----------
count_total=0
count_installed=0
count_failed=0

while IFS= read -r entry; do
    count_total=$((count_total + 1))

    app_id=$(jq -r '.id' <<<"${entry}")
    remote=$(jq -r '.remote // empty' <<<"${entry}")
    branch=$(jq -r '.branch // empty' <<<"${entry}")
    remote="${remote:-${DEFAULT_REMOTE}}"
    branch="${branch:-${DEFAULT_BRANCH}}"

    if [[ -z "${app_id}" || "${app_id}" == "null" ]]; then
        log "Entrée ignorée (id manquant) : ${entry}"
        continue
    fi

    log "-> ${app_id} : installation/mise à jour depuis le dépôt sideloadé (${SIDELOAD_REPO})..."
    if flatpak install --noninteractive -y --or-update \
        --sideload-repo="${SIDELOAD_REPO}" "${remote}" "${app_id}//${branch}"; then
        log "OK  ${app_id} installé/à jour."
        count_installed=$((count_installed + 1))
    else
        log "ÉCHEC installation de ${app_id}."
        count_failed=$((count_failed + 1))
    fi
done < <(jq -c '.[]' "${JSON_FILE}")

log "Terminé. Total: ${count_total} | Installés/à jour: ${count_installed} | Échecs: ${count_failed}"

[[ "${count_failed}" -eq 0 ]] || exit 1
