#!/usr/bin/env bash
# télécharge le kit de survie Linux offline (docs, e-books, repos perso, LLM, ZIM, pages man)
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/local/bin:${PATH}"

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${DIR}/resources.list"

DOCS_DIR="${DIR}/github_docs"
EBOOKS_DIR="${DIR}/ebooks"
REPOS_DIR="${DIR}/git"
LLMS_DIR="${DIR}/llm"
ZIMS_DIR="${DIR}/zims"
MAN_DIR="${DIR}/man"
mkdir -p "${DOCS_DIR}" "${EBOOKS_DIR}" "${REPOS_DIR}" "${LLMS_DIR}" "${ZIMS_DIR}" "${MAN_DIR}"

FAILED=()

log() { printf '[sync] %s\n' "$*"; }

# 1. Docs Git (clone léger, sparse-checkout, sans .git ni code source)
log "1. Dépôts de documentation..."
for NAME in "${!REPOS[@]}"; do
  TARGET="${DOCS_DIR}/${NAME}"
  rm -rf "${TARGET}"
  if git clone --depth 1 --filter=blob:none --no-checkout --quiet "${REPOS[${NAME}]}" "${TARGET}"; then
    pushd "${TARGET}" >/dev/null
    # --no-cone requis : seul ce mode accepte les patterns glob (README*, /*.md)
    git sparse-checkout init --no-cone >/dev/null 2>&1
    git sparse-checkout set --no-cone \
      '/*.md' '/*.rst' '/*.txt' '/*.adoc' '/README*' \
      '/doc/**' '/docs/**' '/documentation/**' \
      '/examples/**' '/example/**' '/man/**' '/pages/**' >/dev/null 2>&1 || true
    git checkout --quiet 2>/dev/null || true
    rm -rf .git
    find . -type f \( -name "*.c" -o -name "*.h" -o -name "*.go" -o -name "*.rs" -o -name "*.o" \) -delete 2>/dev/null || true
    popd >/dev/null
  else
    FAILED+=("Repo Doc: ${NAME}")
  fi
done

# 2. E-books (téléchargés seulement si absents/obsolètes)
log "2. E-books..."
for FILE in "${!EBOOKS[@]}"; do
  TARGET="${EBOOKS_DIR}/${FILE}"
  curl -sSL -z "${TARGET}" -o "${TARGET}" "${EBOOKS[${FILE}]}" || FAILED+=("Ebook: ${FILE}")
done
[[ -f "${EBOOKS_DIR}/Linux_Kernel_In_A_Nutshell.tar.gz" ]] && \
  tar -xzf "${EBOOKS_DIR}/Linux_Kernel_In_A_Nutshell.tar.gz" -C "${EBOOKS_DIR}" 2>/dev/null || true

# 3. Dépôts GitHub personnels (pull si déjà clonés, sinon clone complet)
log "3. Dépôts personnels..."
for NAME in "${!PUBLIC_REPOS[@]}"; do
  TARGET="${REPOS_DIR}/${NAME}"
  if [[ -d "${TARGET}/.git" ]]; then
    git -C "${TARGET}" pull --quiet || FAILED+=("Repo Perso: ${NAME}")
  else
    git clone --quiet "${PUBLIC_REPOS[${NAME}]}" "${TARGET}" || FAILED+=("Repo Perso: ${NAME}")
  fi
done

# 4. Modèles LLM (reprise possible avec -C -)
log "4. Modèles LLM..."
for FILE in "${!LLMS[@]}"; do
  curl -sSL -C - -L -# -o "${LLMS_DIR}/${FILE}" "${LLMS[${FILE}]}" || FAILED+=("LLM: ${FILE}")
done

# 5. Archives ZIM (Kiwix)
log "5. Archives ZIM..."
for FILE in "${!ZIMS[@]}"; do
  curl -sSL -C - -L -# -o "${ZIMS_DIR}/${FILE}" "${ZIMS[${FILE}]}" || FAILED+=("ZIM: ${FILE}")
done

# 6. Pages man système exportées en HTML (ignoré si man2html absent, pas une erreur)
log "6. Pages man..."
if command -v man2html >/dev/null 2>&1; then
  for page in "${MAN_PAGES[@]}"; do
    MANPATH_FILE="$(man -w "${page}" 2>/dev/null || true)"
    [[ -z "${MANPATH_FILE}" || ! -f "${MANPATH_FILE}" ]] && continue
    if [[ "${MANPATH_FILE}" == *.gz ]]; then
      gzip -dc "${MANPATH_FILE}" | man2html > "${MAN_DIR}/${page}.html" 2>/dev/null || true
    else
      man2html "${MANPATH_FILE}" > "${MAN_DIR}/${page}.html" 2>/dev/null || true
    fi
  done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  log "Échecs :"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi
log "Terminé sans erreur."
