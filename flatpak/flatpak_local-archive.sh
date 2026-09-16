#!/usr/bin/env bash
#
# flatpak_local-archive.sh
#
# Construit/actualise un dépôt OSTree autonome (sideload offline) dans
# REPO_DIR/.ostree/repo, à partir de la liste de flatpaks du JSON.
#
# Réutilise flatpak_online-install.sh (sourcé, pas exécuté) pour la
# partie "s'assurer que chaque app est installée localement" : c'est un
# prérequis technique de `flatpak create-usb`, qui ne copie que des refs
# déjà présents sur la machine, il ne télécharge rien lui-même. Ce
# script ajoute ce que l'installation simple n'a pas besoin de faire :
# configurer un collection-id sur le remote (requis pour le sideload) et
# appeler `create-usb`.
#
# Idempotent : un collection-id déjà configuré n'est pas retouché, et
# `create-usb` ne copie que les objets manquants.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="${REPO_DIR:-${SCRIPT_DIR}}"
FLATHUB_COLLECTION_ID="${FLATHUB_COLLECTION_ID:-org.flathub.Stable}"

# Réutilise check_dependencies, ensure_remote, install_apps_from_json,
# ainsi que JSON_FILE/DEFAULT_REMOTE/DEFAULT_BRANCH/log/die.
# shellcheck source=./flatpak_online-install.sh
source "${SCRIPT_DIR}/flatpak_online-install.sh"

# log/die redéfinis avec un préfixe propre à ce script (les fonctions
# sourcées ci-dessus restent, elles, préfixées "[online-install]").
log()  { printf '[local-archive] %s\n' "$*"; }
die()  { printf '[local-archive] ERREUR: %s\n' "$*" >&2; exit 1; }

# Configure le collection-id sur le remote flathub, requis par
# `create-usb` pour que le contenu sideloadé soit reconnu par le client
# offline. Idempotent : ne retouche rien si déjà configuré.
configure_collection_id() {
    local current_cid
    current_cid="$(flatpak remotes -d | awk -v r="${DEFAULT_REMOTE}" '$1==r{print $NF}')"
    if [[ "${current_cid}" != "${FLATHUB_COLLECTION_ID}" ]]; then
        log "Configuration du collection-id '${FLATHUB_COLLECTION_ID}' sur '${DEFAULT_REMOTE}'..."
        flatpak remote-modify --collection-id="${FLATHUB_COLLECTION_ID}" "${DEFAULT_REMOTE}"
    else
        log "Collection-id déjà configuré sur '${DEFAULT_REMOTE}'."
    fi
}

main() {
    check_dependencies
    flatpak create-usb --help >/dev/null 2>&1 || die "Cette version de flatpak ne supporte pas 'create-usb'."
    mkdir -p "${REPO_DIR}"

    ensure_remote
    configure_collection_id

    # Renseigne INSTALLED_REFS / INSTALL_TOTAL / INSTALL_FAILED (voir
    # flatpak_online-install.sh) : s'assure que chaque app du JSON est
    # installée localement avant de pouvoir la copier dans le dépôt.
    install_apps_from_json

    [[ ${#INSTALLED_REFS[@]} -gt 0 ]] || die "Aucune application valide à ajouter au dépôt."

    log "Construction/mise à jour du dépôt local (${REPO_DIR}/.ostree/repo)..."
    log "Applications concernées : ${INSTALLED_REFS[*]}"
    flatpak create-usb "${REPO_DIR}" "${INSTALLED_REFS[@]}"

    log "Terminé. Total JSON: ${INSTALL_TOTAL} | Ajoutés/à jour dans le dépôt: ${#INSTALLED_REFS[@]} | Échecs install: ${INSTALL_FAILED}"
    log "Dépôt prêt : ${REPO_DIR}/.ostree/repo (à copier tel quel, avec le dossier ${REPO_DIR}, vers la machine cible)."

    [[ "${INSTALL_FAILED}" -eq 0 ]] || exit 1
}

main "$@"
