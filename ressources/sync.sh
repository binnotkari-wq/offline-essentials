#!/usr/bin/env bash
#
# sync.sh
#
# Kit de survie Linux offline : synchronise en local la documentation
# (dépôts Git en mode "sparse", e-books, dépôts GitHub personnels),
# des modèles LLM GGUF, des archives ZIM (Kiwix), et exporte les pages
# man système en HTML.
#
# Idempotent : les dépôts de doc sont reclonés à chaque exécution (léger,
# --depth 1), les e-books/LLM/ZIM ne sont retéléchargés que si absents ou
# obsolètes (curl -z / -C -), les dépôts perso font un `git pull`.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/local/bin:${PATH}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOCS_DIR="${SCRIPT_DIR}/github_docs"
EBOOKS_DIR="${SCRIPT_DIR}/ebooks"
PUBLIC_REPOS_DIR="${SCRIPT_DIR}/git"
LLMS_DIR="${SCRIPT_DIR}/llm"
ZIMS_DIR="${SCRIPT_DIR}/zims"
MAN_DIR="${SCRIPT_DIR}/man"

log()  { printf '[sync] %s\n' "$*"; }
die()  { printf '[sync] ERREUR: %s\n' "$*" >&2; exit 1; }

mkdir -p "${DOCS_DIR}" "${EBOOKS_DIR}" "${PUBLIC_REPOS_DIR}" "${LLMS_DIR}" "${ZIMS_DIR}" "${MAN_DIR}"

# --- DECLARATION DES RESSOURCES ---------------------------------------------

# 1. Dépôts Git externes (documentation & exemples uniquement, mode "light")
declare -A REPOS=(
  ["tldr-pages"]="https://github.com/tldr-pages/tldr.git"
  ["pure-bash-bible"]="https://github.com/dylanaraps/pure-bash-bible.git"
  ["pure-sh-bible"]="https://github.com/dylanaraps/pure-sh-bible.git"
  ["just-docs"]="https://github.com/casey/just.git"
  ["podman-docs"]="https://github.com/containers/podman.git"
  ["buildah-docs"]="https://github.com/containers/buildah.git"
  ["bootc-docs"]="https://github.com/containers/bootc.git"
  ["flatpak-docs"]="https://github.com/flatpak/flatpak-docs.git"
  ["wine-docs"]="https://gitlab.winehq.org/wine/wine.git"
  ["btrfs-docs"]="https://github.com/kdave/btrfs-devel.git"
  ["cryptsetup-docs"]="https://gitlab.com/CRYPTSETUP/cryptsetup.git"
  ["progit2-book"]="https://github.com/progit/progit2.git"
  ["gnome-user-docs"]="https://gitlab.gnome.org/GNOME/gnome-user-docs.git"
  ["nixpkgs-manual"]="https://github.com/NixOS/nixpkgs.git"
  ["nixos-manual"]="https://github.com/NixOS/nixpkgs.git"
  ["ostree-docs"]="https://github.com/ostreedev/ostree.git"
)

# 2. E-books (PDF / EPUB / archives PDF)
declare -A EBOOKS=(
  ["The_Linux_Command_Line_19.01.pdf"]="https://sourceforge.net/projects/linuxcommand/files/TLCL/19.01/TLCL-19.01.pdf/download"
  ["The_Linux_Command_Line_25.12A.pdf"]="https://sourceforge.net/projects/linuxcommand/files/TLCL/25.12/TLCL-25.12A.pdf/download"
  ["Linux_Fundamentals_Cobbaut.pdf"]="https://linux-training.be/linuxtraining_20211003.pdf"
  ["Linux Fundamentals.pdf"]="http://linux-training.be/linuxfun.pdf"
  ["System Administration.pdf"]="http://linux-training.be/linuxsys.pdf"
  ["Linux Servers.pdf"]="http://linux-training.be/linuxsrv.pdf"
  ["Linux Storage.pdf"]="http://linux-training.be/linuxsto.pdf"
  ["Linux Security.pdf"]="http://linux-training.be/linuxsec.pdf"
  ["Linux Networking.pdf"]="http://linux-training.be/linuxnet.pdf"
  ["Pro_Git_FR.pdf"]="https://github.com/progit/progit2-fr/releases/download/2.1.78/progit.pdf"
  ["Linux_Kernel_In_A_Nutshell.tar.gz"]="http://files.kroah.com/lkn/lkn_pdf.tar.gz"
  ["Advanced_Bash_Scripting_Guide.pdf"]="https://tldp.org/LDP/abs/abs-guide.pdf"
  ["debian-handbook.epub"]="http://debian-handbook.info/download/fr-FR/stable/debian-handbook.epub"
)

# 3. Dépôts GitHub personnels (clonage/pull complet)
declare -A PUBLIC_REPOS=(
  ["mini-projects"]="https://github.com/binnotkari-wq/mini-projects.git"
  ["nixos-dotfiles"]="https://github.com/binnotkari-wq/nixos-dotfiles.git"
  ["post-install"]="https://github.com/binnotkari-wq/post-install.git"
  ["scripts"]="https://github.com/binnotkari-wq/scripts.git"
  ["silverblue_bootc"]="https://github.com/binnotkari-wq/silverblue_bootc.git"
)

# 4. Modèles LLM GGUF
declare -A LLMS=(
  ["Qwen3.5-4B-Q4_K_M.gguf"]="https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf"
)

# 5. Archives ZIM (Kiwix)
declare -A ZIMS=(
  ["archlinux_en_all_maxi_2026-07.zim"]="https://mirror.download.kiwix.org/zim/other/archlinux_en_all_maxi_2026-07.zim"
  ["devdocs_en_man_2026-07.zim"]="https://mirror.download.kiwix.org/zim/devdocs/devdocs_en_man_2026-07.zim"
  ["kris-occhipinti_en_all_2026-07.zim"]="https://mirror.download.kiwix.org/zim/videos/kris-occhipinti_en_all_2026-07.zim"
  ["gentoo_en_all_maxi_2026-07.zim"]="https://mirror.download.kiwix.org/zim/other/gentoo_en_all_maxi_2026-07.zim"
  ["alpinelinux_en_all_maxi_2026-07.zim"]="https://mirror.download.kiwix.org/zim/other/alpinelinux_en_all_maxi_2026-07.zim"
)

# 6. Pages man système à exporter en HTML
MAN_PAGES=(bash podman buildah bootc flatpak wine btrfs cryptsetup git just)

declare -i SUCCESS_COUNT=0
declare -i FAIL_COUNT=0
declare -i SKIPPED_COUNT=0
FAILED_ITEMS=()
SKIPPED_ITEMS=()

log "================================================="
log " Synchronisation du kit de survie Linux offline"
log " Dossier cible : ${SCRIPT_DIR}"
log "================================================="

# --- SECTION 1 : DEPOTS GIT (DOCS & EXEMPLES SEULEMENT, MODE LIGHT) ---------
log "=== 1. Dépôts de documentation Git (mode light) ==="

for NAME in "${!REPOS[@]}"; do
  URL="${REPOS[${NAME}]}"
  TARGET_PATH="${DOCS_DIR}/${NAME}"
  log "-> Dépôt doc : ${NAME}"

  rm -rf "${TARGET_PATH}"

  if git clone --depth 1 --filter=blob:none --no-checkout --quiet "${URL}" "${TARGET_PATH}"; then
    pushd "${TARGET_PATH}" >/dev/null

    git sparse-checkout init --cone >/dev/null 2>&1 || true
    git sparse-checkout set doc docs documentation examples example man pages README* >/dev/null 2>&1 || \
      git sparse-checkout set /* >/dev/null 2>&1 || true
    git checkout --quiet 2>/dev/null || true

    # Nettoyage .git et code source (on ne garde que la doc)
    rm -rf .git
    find . -type f \( -name "*.c" -o -name "*.h" -o -name "*.go" -o -name "*.rs" -o -name "*.o" \) -delete 2>/dev/null || true

    popd >/dev/null
    log "   OK  ${NAME} (documentation extraite)"
    SUCCESS_COUNT+=1
  else
    log "   ÉCHEC récupération de ${NAME}"
    FAIL_COUNT+=1
    FAILED_ITEMS+=("Repo Doc: ${NAME}")
  fi
done

# --- SECTION 2 : E-BOOKS ----------------------------------------------------
log "=== 2. E-books et manuels ==="

for FILE in "${!EBOOKS[@]}"; do
  URL="${EBOOKS[${FILE}]}"
  TARGET_FILE="${EBOOKS_DIR}/${FILE}"
  log "-> E-book : ${FILE}"

  if [[ -f "${TARGET_FILE}" ]]; then
    log "   Mode : déjà présent (vérification des en-têtes)"
  else
    log "   Mode : téléchargement..."
  fi

  if curl -sSL -z "${TARGET_FILE}" -o "${TARGET_FILE}" "${URL}"; then
    log "   OK  ${FILE}"
    SUCCESS_COUNT+=1
  else
    log "   ÉCHEC téléchargement de ${FILE}"
    FAIL_COUNT+=1
    FAILED_ITEMS+=("Ebook: ${FILE}")
  fi
done

# Décompression de l'archive du noyau si présente
if [[ -f "${EBOOKS_DIR}/Linux_Kernel_In_A_Nutshell.tar.gz" ]]; then
  log "-> Extraction de l'archive du noyau Linux..."
  tar -xzf "${EBOOKS_DIR}/Linux_Kernel_In_A_Nutshell.tar.gz" -C "${EBOOKS_DIR}" 2>/dev/null || true
fi

# --- SECTION 3 : REPOS GITHUB PERSONNELS ------------------------------------
log "=== 3. Dépôts GitHub personnels ==="

for NAME in "${!PUBLIC_REPOS[@]}"; do
  URL="${PUBLIC_REPOS[${NAME}]}"
  TARGET_PATH="${PUBLIC_REPOS_DIR}/${NAME}"
  log "-> Dépôt perso : ${NAME}"

  if [[ -d "${TARGET_PATH}/.git" ]]; then
    log "   Mode : mise à jour (git pull)"
    if git -C "${TARGET_PATH}" pull --quiet; then
      log "   OK  ${NAME} (mis à jour)"
      SUCCESS_COUNT+=1
    else
      log "   ÉCHEC pull de ${NAME}"
      FAIL_COUNT+=1
      FAILED_ITEMS+=("Repo Perso: ${NAME}")
    fi
  else
    log "   Mode : clonage complet..."
    if git clone --quiet "${URL}" "${TARGET_PATH}"; then
      log "   OK  ${NAME} (cloné)"
      SUCCESS_COUNT+=1
    else
      log "   ÉCHEC clonage de ${NAME}"
      FAIL_COUNT+=1
      FAILED_ITEMS+=("Repo Perso: ${NAME}")
    fi
  fi
done

# --- SECTION 4 : MODÈLES LLM ------------------------------------------------
log "=== 4. Modèles LLM (GGUF) ==="

for FILE in "${!LLMS[@]}"; do
  URL="${LLMS[${FILE}]}"
  TARGET_FILE="${LLMS_DIR}/${FILE}"
  log "-> Modèle LLM : ${FILE}"

  if [[ -f "${TARGET_FILE}" ]]; then
    log "   Mode : vérification / reprise du téléchargement..."
  else
    log "   Mode : démarrage du téléchargement..."
  fi

  if curl -sSL -C - -L -# -o "${TARGET_FILE}" "${URL}"; then
    log "   OK  ${FILE}"
    SUCCESS_COUNT+=1
  else
    log "   ÉCHEC téléchargement de ${FILE}"
    FAIL_COUNT+=1
    FAILED_ITEMS+=("LLM: ${FILE}")
  fi
done

# --- SECTION 5 : ARCHIVES ZIM (KIWIX) ---------------------------------------
log "=== 5. Archives ZIM (Kiwix) ==="

for FILE in "${!ZIMS[@]}"; do
  URL="${ZIMS[${FILE}]}"
  TARGET_FILE="${ZIMS_DIR}/${FILE}"
  log "-> Archive ZIM : ${FILE}"

  if [[ -f "${TARGET_FILE}" ]]; then
    log "   Mode : vérification / reprise du téléchargement..."
  else
    log "   Mode : démarrage du téléchargement..."
  fi

  if curl -sSL -C - -L -# -o "${TARGET_FILE}" "${URL}"; then
    log "   OK  ${FILE}"
    SUCCESS_COUNT+=1
  else
    log "   ÉCHEC téléchargement de ${FILE}"
    FAIL_COUNT+=1
    FAILED_ITEMS+=("ZIM: ${FILE}")
  fi
done

# --- SECTION 6 : EXPORT DES PAGES MAN SYSTÈME -------------------------------
log "=== 6. Export des pages man système vers HTML ==="

if command -v man2html >/dev/null 2>&1; then
  for page in "${MAN_PAGES[@]}"; do
    MANPATH_FILE="$(man -w "${page}" 2>/dev/null || true)"

    if [[ -n "${MANPATH_FILE}" && -f "${MANPATH_FILE}" ]]; then
      if [[ "${MANPATH_FILE}" == *.gz ]]; then
        gzip -dc "${MANPATH_FILE}" | man2html > "${MAN_DIR}/${page}.html" 2>/dev/null || true
      else
        man2html "${MANPATH_FILE}" > "${MAN_DIR}/${page}.html" 2>/dev/null || true
      fi
      log "   OK  page man exportée : ${page}"
      SUCCESS_COUNT+=1
    else
      log "   IGNORÉ page man introuvable (outil non installé localement) : ${page}"
      SKIPPED_COUNT+=1
      SKIPPED_ITEMS+=("Man Page: ${page}")
    fi
  done
  log "Pages man générées dans ${MAN_DIR}/"
else
  log "AVERTISSEMENT: 'man2html' n'est pas installé. Étape ignorée."
fi

# --- BILAN FINAL -------------------------------------------------------------
log "================================================="
log " Résumé de la synchronisation"
log " Succès  : ${SUCCESS_COUNT}"
log " Ignorés : ${SKIPPED_COUNT} (ex. outils non installés localement, sans impact)"
log " Échecs  : ${FAIL_COUNT}"

if [[ ${SKIPPED_COUNT} -gt 0 ]]; then
  log " Éléments ignorés :"
  for ITEM in "${SKIPPED_ITEMS[@]}"; do
    log "   - ${ITEM}"
  done
fi

if [[ ${FAIL_COUNT} -gt 0 ]]; then
  log " Éléments en échec :"
  for ITEM in "${FAILED_ITEMS[@]}"; do
    log "   - ${ITEM}"
  done
fi
log "================================================="

# Seuls les vrais échecs (téléchargement, clonage) font échouer le script.
# Une page man absente parce que l'outil correspondant n'est pas installé
# localement n'est pas une erreur : ce n'est pas la faute du script.
[[ ${FAIL_COUNT} -eq 0 ]] || exit 1
