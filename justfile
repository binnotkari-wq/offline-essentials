# justfile - offline-essentials
#
# Chaque recette appelle un script existant sans dupliquer sa logique ;
# les scripts vivent sous scripts/<categorie>/ et lisent/écrivent leurs
# données sous dataset/<categorie>/ (même nom de sous-dossier des deux côtés).

set shell := ["bash", "-euo", "pipefail", "-c"]

# --- utilitaires ---

# Affiche la liste des recettes disponibles
_default:
    @just --list --list-heading $'Installation, construction et déploiement des logiciels et documentations\n'

# Menu interactif groupé par catégories
_menu:
    #!/usr/bin/env bash
    
    # 1. Extraction et formatage des catégories et recettes
    # Lit le justfile, détecte les en-têtes '# ---' et les noms de recettes
    SELECTION=$(awk '
        /^# ---/ { 
            gsub(/^# --- *| *---$/, ""); 
            category=$0; 
            print "\n\033[1;35m══ " category " ══\033[0m" 
        }
        /^[a-zA-Z0-9_-]+:/ && !/^_/ { 
            split($1, a, ":"); 
            print "  " a[1] 
        }
    ' {{justfile()}} | fzf \
        --ansi \
        --layout=reverse \
        --border=rounded \
        --prompt="❯ " \
        --header="Choisis une recette par catégorie" \
        --preview '
            # Nettoie les espaces pour récuperer le nom exact de la recette
            recipe=$(echo {} | xargs);
            if [ -n "$recipe" ] && ! echo "{}" | grep -q "══"; then
                just --show "$recipe" 2>/dev/null || echo "Aperçu indisponible"
            fi
        ' \
        --preview-window=right:50%:wrap)

    # 2. Nettoyage du nom sélectionné (enlève les espaces)
    RECIPE=$(echo "$SELECTION" | xargs)

    # 3. Exécution si ce n'est pas une ligne d'en-tête de catégorie
    if [ -n "$RECIPE" ] && ! echo "$SELECTION" | grep -q "══"; then
        just "$RECIPE"
    fi

# Confirmations d'éxecution d'une recette.
_confirm recipe:
    #!/usr/bin/env bash
    read -p "Exécuter '{{recipe}}' ? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        just {{recipe}}
    fi

# Bilan de l'espace disque occupé par le dataset
_check-space:
    @echo "=========================================="
    @echo "          ÉTAT DU STOCKAGE ET DISQUE      "
    @echo "=========================================="
    @echo "--> Espace disponible sur la partition :"
    @df -h .
    @echo "-------------------------------------------"
    @echo "--> Espace utilisé par le dataset offline :"
    @du -sh ./dataset
    @echo "-------------------------------------------"
    @bash -c 'shopt -s dotglob nullglob; du -sh ./dataset/*/'

# --- resources ---

# Télécharge le kit de ressources (docs, e-books, repos perso, LLM, ZIM, man)
[group('resources')]
resources_online-download:
    ./scripts/resources/resources_online-download.sh

# Copie le dataset resources/ vers ~/resources
[group('resources')]
resources-deploy:
    ./scripts/resources/resources_deploy.sh

# --- flatpak ---

# Installe une liste de flatpaks sur la machine courante, EN LIGNE
[group('flatpak')]
flatpak-online-install:
    ./scripts/flatpak/flatpak_online-install.sh

# Construit/actualise le dépôt OSTree offline (sideload) depuis une machine en ligne
[group('flatpak')]
flatpak-local-archive:
    ./scripts/flatpak/flatpak_local-archive.sh

# Installe/actualise les flatpaks depuis le dépôt OSTree sideloadé, HORS-LIGNE
[group('flatpak')]
flatpak-offline-deploy:
    ./scripts/flatpak/flatpak_offline-deploy.sh

# --- brew ---

# Installe Homebrew et les formules listées, EN LIGNE
[group('brew')]
brew-online-install:
    ./scripts/brew/brew_online-install.sh

# Archive le prefix Linuxbrew installé, EN LIGNE
[group('brew')]
brew-local-archive:
    ./scripts/brew/brew_local-archive.sh

# Restaure le prefix Linuxbrew archivé, HORS-LIGNE
[group('brew')]
brew-offline-deploy:
    ./scripts/brew/brew_offline-deploy.sh

# --- distrobox / toolbox ---

# Build l'image toolbox depuis le Containerfile, EN LIGNE
[group('distrobox / toolbox')]
container-online-build:
    ./scripts/distrobox/container_online-build.sh

# Crée la distrobox et exporte les binaires manquants vers l'hôte
[group('distrobox / toolbox')]
distrobox-create:
    ./scripts/distrobox/distrobox_create.sh

# Fige/exporte le conteneur toolbox initialisé, EN LIGNE
[group('distrobox / toolbox')]
container-local-archive:
    ./scripts/distrobox/container_local-archive.sh

# Importe l'image toolbox exportée, HORS-LIGNE
[group('distrobox / toolbox')]
container-offline-import:
    ./scripts/distrobox/container_offline-import.sh

# --- tools ---

# Télécharge les binaires standalone (glow, mdcat, just, llama.cpp, kiwix-tools, distrobox), EN LIGNE
[group('tools')]
tools-online-download:
    ./scripts/tools/tools_online-download.sh

# Installe les binaires standalone téléchargés vers ~/.local/bin et ~/.local/share
[group('tools')]
tools-local-copy:
    ./scripts/tools/tools_local-copy.sh

# --- squashfs-image ---

# Empaquette dataset/ + scripts/ + justfile + README.md en un fichier SquashFS unique
[group('squashfs-image')]
image_local-build:
    ./scripts/squashfs-image/image_local-build.sh

# Vérifie l'intégrité et monte le fichier SquashFS en lecture seule
[group('squashfs-image')]
image-mount:
    ./scripts/squashfs-image/image_mount.sh

# --- workflows ---

# Installe l'intégralité du kit. Opération idempotente.
[group('workflows')]
online_install:
    just resources_online-download
    just resources-deploy
    just flatpak-online-install
    just brew-online-install
    just container-online-build
    just distrobox-create
    just tools-online-download
    just tools-local-copy
    @echo ""
    @echo "Kit installé. Copiez le dépôt sur la machine cible."

# Prépare une archive squashfs de l'intégralité du kit. Opération idempotente. Aucune connection réseau nécessaire.
[group('workflows')]
local_archive:
    @echo "condition : online_install doit avoir été exécuté au préalable"
    just flatpak-local-archive
    just brew-local-archive
    just container-local-archive
    just _check-space
    just image_local-build
    @echo "Archivage terminé. Copier et monter le dossier ./squashfs-image sur la machine cible."

# Déploie l'intégralité du kit depuis l'archive squashfs. Opération idempotente. Aucune connection réseau nécessaire.
[group('workflows')]
offline_deploy:
    just _confirm tools-local-copy
    just _confirm container-offline-import distrobox-create
    just _confirm brew-offline-deploy
    just _confirm flatpak-offline-deploy
    just _confirm resources-deploy
    @echo "Déploiement terminé."
