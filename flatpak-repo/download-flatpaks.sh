#!/usr/bin/env bash
#
# download-flatpaks.sh
#
# Lit une liste de flatpaks depuis un fichier JSON, s'assure qu'ils sont
# installés localement (prérequis technique de `flatpak create-usb`),
# configure un collection-id sur les remotes utilisés (requis pour le
# sideload offline), puis construit/actualise un dépôt OSTree autonome
# dans REPO_DIR/.ostree/repo via `flatpak create-usb`.
#
# Idempotent : les apps déjà installées ne sont pas réinstallées, un
# collection-id déjà configuré n'est pas retouché, et `create-usb` ne
# copie que les objets manquants.
#
# Format attendu du JSON (voir flatpaks.json) :
# [
#   { "id": "io.github.kolunmi.Bazaar", "remote": "flathub", "branch": "stable" }
# ]
# "remote" et "branch" sont optionnels (par défaut : flathub / stable).

set -euo pipefail

# --- Configuration ---------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
JSON_FILE="${JSON_FILE:-${SCRIPT_DIR}/flatpaks.json}"
REPO_DIR="${REPO_DIR:-${SCRIPT_DIR}}"
DEFAULT_REMOTE="${DEFAULT_REMOTE:-flathub}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-stable}"
FLATHUB_URL="${FLATHUB_URL:-https://dl.flathub.org/repo/flathub.flatpakrepo}"
FLATHUB_COLLECTION_ID="${FLATHUB_COLLECTION_ID:-org.flathub.Stable}"

log()  { printf '[download-flatpaks] %s\n' "$*"; }
die()  { printf '[download-flatpaks] ERREUR: %s\n' "$*" >&2; exit 1; }

# --- Vérification des dépendances ------------------------------------------
command -v flatpak >/dev/null 2>&1 || die "flatpak n'est pas installé."
command -v jq      >/dev/null 2>&1 || die "jq n'est pas installé."
flatpak create-usb --help >/dev/null 2>&1 || die "Cette version de flatpak ne supporte pas 'create-usb'."

[[ -f "${JSON_FILE}" ]] || die "Fichier JSON introuvable : ${JSON_FILE}"
jq -e . "${JSON_FILE}" >/dev/null 2>&1 || die "JSON invalide : ${JSON_FILE}"

mkdir -p "${REPO_DIR}"

# --- Remote flathub + collection-id (idempotent) ----------------------------
if ! flatpak remote-list | awk '{print $1}' | grep -qx "${DEFAULT_REMOTE}"; then
    log "Ajout du remote '${DEFAULT_REMOTE}'..."
    flatpak remote-add --if-not-exists "${DEFAULT_REMOTE}" "${FLATHUB_URL}"
else
    log "Remote '${DEFAULT_REMOTE}' déjà présent."
fi

current_cid="$(flatpak remotes -d | awk -v r="${DEFAULT_REMOTE}" '$1==r{print $NF}')"
if [[ "${current_cid}" != "${FLATHUB_COLLECTION_ID}" ]]; then
    log "Configuration du collection-id '${FLATHUB_COLLECTION_ID}' sur '${DEFAULT_REMOTE}'..."
    flatpak remote-modify --collection-id="${FLATHUB_COLLECTION_ID}" "${DEFAULT_REMOTE}"
else
    log "Collection-id déjà configuré sur '${DEFAULT_REMOTE}'."
fi

# --- Étape 1 : s'assurer que chaque app est installée localement -----------
# (prérequis obligatoire : `flatpak create-usb` ne copie que des refs déjà
# installés, il ne télécharge rien lui-même depuis un remote distant)
ARCH="$(flatpak --default-arch)"
refs=()
count_total=0
count_failed=0

while IFS= read -r entry; do
    count_total=$((count_total + 1))

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
        log "OK  ${app_id}//${branch} : déjà installé localement."
    else
        log "-> ${app_id} : installation depuis '${remote}' (branche ${branch})..."
        if ! flatpak install --noninteractive -y "${remote}" "${app_id}//${branch}"; then
            log "ÉCHEC install de ${app_id}, il ne sera pas ajouté au dépôt."
            count_failed=$((count_failed + 1))
            continue
        fi
    fi

    # `flatpak create-usb` accepte soit l'ID seul (branche déjà installée
    # déduite automatiquement), soit un ref complet à 3 segments
    # (id/arch/branche). Quand plusieurs entrées du JSON partagent le même
    # id avec des branches différentes (ex: deux versions d'un même
    # VulkanLayer), il faut absolument le ref complet pour ne pas les
    # confondre : create-usb ne saurait sinon laquelle choisir.
    if [[ -n "${json_branch}" ]]; then
        refs+=("${app_id}/${ARCH}/${json_branch}")
    else
        refs+=("${app_id}")
    fi
done < <(jq -c '.[]' "${JSON_FILE}")

[[ ${#refs[@]} -gt 0 ]] || die "Aucune application valide à ajouter au dépôt."

# --- Étape 2 : construire/actualiser le dépôt OSTree offline ---------------
# create-usb écrit par défaut dans REPO_DIR/.ostree/repo.
log "Construction/mise à jour du dépôt local (${REPO_DIR}/.ostree/repo)..."
log "Applications concernées : ${refs[*]}"

flatpak create-usb "${REPO_DIR}" "${refs[@]}"

log "Terminé. Total JSON: ${count_total} | Ajoutés/à jour dans le dépôt: ${#refs[@]} | Échecs install: ${count_failed}"
log "Dépôt prêt : ${REPO_DIR}/.ostree/repo (à copier tel quel, avec le dossier ${REPO_DIR}, vers la machine cible)."

[[ "${count_failed}" -eq 0 ]] || exit 1
