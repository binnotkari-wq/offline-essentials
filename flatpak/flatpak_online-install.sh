#!/usr/bin/env bash
#
# flatpak_online-install.sh
#
# Installe une liste de flatpaks (fichier JSON) sur la machine courante,
# EN LIGNE : ajoute le remote flathub si besoin, puis installe chaque
# application listée si elle n'est pas déjà présente.
#
# Ce script sert deux usages :
#   1. Exécuté directement : installe simplement les flatpaks sur une
#      machine online, sans rien construire d'autre.
#   2. Sourcé par flatpak_local-archive.sh : fournit la fonction
#      `install_apps_from_json`, réutilisée pour peupler un dépôt OSTree
#      offline (create-usb exige que les apps soient déjà installées
#      localement avant de pouvoir les copier dans le dépôt).
# Un script sourcé n'exécute pas `main` automatiquement (voir la garde
# en bas de fichier) : seule l'exécution directe le fait.
#
# Idempotent : les apps déjà installées ne sont pas réinstallées, le
# remote flathub n'est ajouté que s'il est absent.
#
# Format attendu du JSON (voir flatpaks.json) :
# [
#   { "id": "io.github.kolunmi.Bazaar", "remote": "flathub", "branch": "stable" }
# ]
# "remote" et "branch" sont optionnels (par défaut : flathub / stable).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
JSON_FILE="${JSON_FILE:-${SCRIPT_DIR}/flatpaks.json}"
DEFAULT_REMOTE="${DEFAULT_REMOTE:-flathub}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-stable}"
FLATHUB_URL="${FLATHUB_URL:-https://dl.flathub.org/repo/flathub.flatpakrepo}"

log()  { printf '[online-install] %s\n' "$*"; }
die()  { printf '[online-install] ERREUR: %s\n' "$*" >&2; exit 1; }

check_dependencies() {
    command -v flatpak >/dev/null 2>&1 || die "flatpak n'est pas installé."
    command -v jq      >/dev/null 2>&1 || die "jq n'est pas installé."
    [[ -f "${JSON_FILE}" ]] || die "Fichier JSON introuvable : ${JSON_FILE}"
    jq -e . "${JSON_FILE}" >/dev/null 2>&1 || die "JSON invalide : ${JSON_FILE}"
}

# Ajoute le remote flathub s'il est absent. Idempotent.
ensure_remote() {
    if ! flatpak remote-list | awk '{print $1}' | grep -qx "${DEFAULT_REMOTE}"; then
        log "Ajout du remote '${DEFAULT_REMOTE}'..."
        flatpak remote-add --if-not-exists "${DEFAULT_REMOTE}" "${FLATHUB_URL}"
    else
        log "Remote '${DEFAULT_REMOTE}' déjà présent."
    fi
}

# Installe chaque application listée dans JSON_FILE si elle est absente.
# Renseigne les variables globales : INSTALLED_REFS (refs installés,
# avec branche explicite si précisée dans le JSON), INSTALL_TOTAL et
# INSTALL_FAILED (compteurs).
install_apps_from_json() {
    local ARCH entry app_id remote json_branch branch
    ARCH="$(flatpak --default-arch)"

    INSTALLED_REFS=()
    INSTALL_TOTAL=0
    INSTALL_FAILED=0

    while IFS= read -r entry; do
        INSTALL_TOTAL=$((INSTALL_TOTAL + 1))

        app_id=$(jq -r '.id' <<<"${entry}")
        remote=$(jq -r '.remote // empty' <<<"${entry}")
        json_branch=$(jq -r '.branch // empty' <<<"${entry}")
        remote="${remote:-${DEFAULT_REMOTE}}"
        branch="${json_branch:-${DEFAULT_BRANCH}}"

        if [[ -z "${app_id}" || "${app_id}" == "null" ]]; then
            log "Entrée ignorée (id manquant) : ${entry}"
            continue
        fi

        if flatpak info "${app_id}//${branch}" >/dev/null 2>&1; then
            log "OK  ${app_id}//${branch} : déjà installé."
        else
            log "-> ${app_id} : installation depuis '${remote}' (branche ${branch})..."
            if ! flatpak install --noninteractive -y "${remote}" "${app_id}//${branch}"; then
                log "ÉCHEC install de ${app_id}."
                INSTALL_FAILED=$((INSTALL_FAILED + 1))
                continue
            fi
            log "OK  ${app_id}//${branch} : installé."
        fi

        # Un ref à 3 segments (id/arch/branche) est nécessaire quand
        # plusieurs entrées du JSON partagent le même id avec des
        # branches différentes (ex: deux versions d'un même VulkanLayer) ;
        # l'id seul suffit sinon (branche déduite de l'install existante).
        if [[ -n "${json_branch}" ]]; then
            INSTALLED_REFS+=("${app_id}/${ARCH}/${json_branch}")
        else
            INSTALLED_REFS+=("${app_id}")
        fi
    done < <(jq -c '.[]' "${JSON_FILE}")
}

main() {
    check_dependencies
    ensure_remote
    install_apps_from_json

    log "Terminé. Total JSON : ${INSTALL_TOTAL} | Installés/déjà présents : ${#INSTALLED_REFS[@]} | Échecs : ${INSTALL_FAILED}"

    [[ "${INSTALL_FAILED}" -eq 0 ]] || exit 1
}

# N'exécute `main` que si le script est appelé directement, pas sourcé
# (permet à flatpak_local-archive.sh de réutiliser install_apps_from_json
# sans déclencher un second résumé/exit).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
