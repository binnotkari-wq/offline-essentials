# justfile - offline-essentials
#
# Orchestration du kit de survie Linux offline.
# Chaque recette appelle un script existant sans dupliquer sa logique ;
# tout le contenu (docs, e-books, flatpaks, modèles LLM, outils de
# lecture) est reconstruit dans les dossiers du dépôt, prêt à être copié
# tel quel sur une machine hors-ligne.

set shell := ["bash", "-euo", "pipefail", "-c"]

# Affiche la liste des recettes disponibles
default:
    @just --list
    @export JUST_CHOOSER='bash -c "mapfile -t recipes; exec < /dev/tty; select item in \"\${recipes[@]}\"; do echo \"\$item\"; break; done"'
    @just --choose

# Synchronise le kit de ressources (docs, e-books, repos perso, LLM, ZIM, man)
sync:
    ./ressources/sync.shà

# Installe une liste de flatpaks sur la machine courante, EN LIGNE
flatpak-online-install:
    ./flatpak-repo/flatpak_online-install.sh

# Construit/actualise le dépôt OSTree offline (sideload) depuis une machine en ligne
flatpak-local-archive:
    ./flatpak-repo/flatpak_local-archive.sh

# Installe/actualise les flatpaks depuis le dépôt OSTree sideloadé, HORS-LIGNE
flatpak-offline-install:
    ./flatpak-repo/flatpak_offline-install.sh

# Provisionne les outils de lecture standalone (llama.cpp, kiwix, glow, mdcat)
provision:
    ./reading_tools/provision.sh

# Empaquette le kit en un unique fichier SquashFS vérifiable (offline-essentials.sqfs)
package:
    ./package.sh

# Bilan de l'espace disque occupé par le dataset
check-space:
    @echo "=========================================="
    @echo "          ÉTAT DU STOCKAGE ET DISQUE      "
    @echo "=========================================="
    @echo "--> Espace disponible sur la partition :"
    @df -h .
    @echo "-------------------------------------------"
    @echo "--> Espace utilisé par le dataset offline :"
    @du -sh ./
    @echo "-------------------------------------------"
    @bash -c 'shopt -s dotglob nullglob; du -sh ./*/*/'

# Liste les refs (applications) présentes dans le dépôt local
list:
    @ostree refs --repo="./flatpak-repo/.ostree/repo" 2>/dev/null || echo "Dépôt local vide ou inexistant : ./flatpak-repo/.ostree/repo"

# Reconstruit l'intégralité du kit, dans l'ordre : ressources -> flatpaks -> outils -> bilan
all: sync flatpak-local-archive provision check-space
    @echo "Kit offline-essentials reconstruit. Copiez le dépôt sur la machine cible,"
    @echo "puis lancez 'just flatpak-offline-install' une fois sur place."
    @echo "Pour un fichier unique à transférer, lancez ensuite 'just package'."
