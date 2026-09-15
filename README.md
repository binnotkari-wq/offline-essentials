# offline-essentials

Kit minimal pour utiliser Linux (n'importe quelle distribution) sur une machine **totalement déconnectée** : documentation, e-books, applications (Flatpak), modèle de langage local, outils de lecture, et pages man exportées.

Le dépôt ne contient **aucune référence à une distribution en particulier** : tout ce qui est produit ici doit pouvoir être copié tel quel sur n'importe quelle machine Linux, avec ou sans accès réseau.

## Objectif

Pouvoir manipuler, préparer, personnaliser, expérimenter et maintenir un système Linux en étant **hors-ligne pendant un mois entier** : documentation de référence, applications courantes, un modèle LLM pour interroger la doc localement, et les outils nécessaires pour tout consulter sans navigateur ni connexion.

Le dépôt est prévu pour être rempli/actualisé sur une machine connectée, puis copié (clé USB, disque externe...) vers la machine cible hors-ligne.

## Structure du dépôt

```
offline-essentials/
├── justfile                    # Orchestration de l'ensemble
├── flatpak-repo/
│   ├── flatpaks.json            # Liste déclarative des applications Flatpak
│   ├── download-flatpaks.sh     # Construit un dépôt OSTree offline (sideload)
│   └── install-flatpaks.sh      # Installe depuis ce dépôt OSTree, sans réseau
├── ressources/
│   └── sync.sh                  # Docs Git, e-books, repos perso, LLM, ZIM, pages man
└── reading_tools/
    └── provision.sh             # Binaires standalone : llama.cpp, kiwix-tools, glow, mdcat
```

## Fonctions

### `flatpak-repo/` — Applications Flatpak hors-ligne

Flatpak sait installer des applications depuis un dépôt OSTree local (*sideload*), sans contact réseau, à condition que ce dépôt existe déjà. Le processus est donc en deux temps, sur deux machines différentes :

- **`download-flatpaks.sh`** (sur une machine connectée) : lit `flatpaks.json`, installe localement chaque application listée si besoin, puis appelle `flatpak create-usb` pour construire/actualiser un dépôt OSTree autonome dans `flatpak-repo/.ostree/repo`. Ce dépôt contient tous les objets nécessaires, sans dépendre d'un accès réseau ultérieur.
- **`install-flatpaks.sh`** (sur la machine cible, hors-ligne) : configure le remote `flathub` avec le bon `collection-id` (obligatoire pour que Flatpak fasse correspondre le contenu sideloadé), puis installe/actualise chaque application via `--sideload-repo`.
- **`flatpaks.json`** : chaque entrée est `{ "id": "...", "remote": "...", "branch": "..." }` (`remote`/`branch` optionnels, défaut `flathub`/`stable`). Un champ `note` libre permet de documenter des cas particuliers (ex. préférer une installation native sur NixOS pour certains paquets).

**Choix technique clé** : `flatpak create-usb` ne copie que des refs *déjà installés localement* — il ne télécharge rien lui-même. `download-flatpaks.sh` installe donc d'abord chaque app avant de la copier dans le dépôt. Quand plusieurs entrées du JSON partagent un même id avec des branches différentes (ex. deux versions d'un VulkanLayer), le script utilise le ref complet à 3 segments (`id/arch/branche`) pour éviter toute ambiguïté.

Les deux scripts sont idempotents : `install-flatpaks.sh` ne reconfigure le `collection-id` que s'il diffère, et Flatpak lui-même ne réinstalle pas une app déjà à jour ; `download-flatpaks.sh` ne réinstalle pas les apps déjà présentes et `create-usb` ne copie que les objets manquants.

### `ressources/sync.sh` — Documentation, e-books, repos, LLM, ZIM, man

Un script unique en six sections, chacune indépendante des autres (une section en échec n'interrompt pas les suivantes) :

1. **Dépôts Git de documentation** (`github_docs/`) : clone en mode léger (`--depth 1 --filter=blob:none --no-checkout`) puis `sparse-checkout` restreint aux dossiers `doc(s)`, `documentation`, `examples`, `README*`. Le `.git` et les fichiers source (`.c`, `.h`, `.go`, `.rs`, `.o`) sont ensuite supprimés : seule la doc est conservée, pas l'historique ni le code.
2. **E-books** (`ebooks/`) : téléchargement conditionnel (`curl -z`, ne retélécharge que si la ressource distante est plus récente). L'archive du noyau Linux est décompressée automatiquement si présente.
3. **Dépôts GitHub personnels** (`git/`) : clonage complet (avec historique) ou `git pull` si déjà présent — contrairement aux dépôts de doc, ce sont des projets perso à garder intégralement.
4. **Modèles LLM GGUF** (`llm/`) : téléchargement avec reprise sur interruption (`curl -C -`), utile vu la taille des fichiers.
5. **Archives ZIM/Kiwix** (`zims/`) : même logique de reprise, pour des encyclopédies/documentations consultables hors-ligne via `kiwix-serve`.
6. **Pages man système** (`man/`) : export HTML via `man2html` pour les commandes clés du kit (`bash`, `podman`, `buildah`, `bootc`, `flatpak`, `wine`, `btrfs`, `cryptsetup`, `git`, `just`). Étape ignorée proprement si `man2html` n'est pas installé.

**Choix technique** : séparer volontairement "dépôts de doc" (mode light, jetables, reconstruits à chaque run) et "dépôts perso" (mode complet, avec historique, mis à jour par `pull`) — les besoins et le poids ne sont pas les mêmes.

Chaque section produit un bilan (`succès` / `échecs` avec liste des éléments en échec), affiché en fin d'exécution.

### `reading_tools/provision.sh` — Outils de consultation standalone

Télécharge et extrait quatre binaires précompilés, sans dépendance système ni gestionnaire de paquets :

- **llama.cpp** (build Vulkan) : sert un modèle GGUF via `llama-server`, interrogeable depuis un navigateur (`http://127.0.0.1:8080`). Permet d'interroger la documentation collectée avec un LLM local.
- **kiwix-tools** : sert les archives ZIM via `kiwix-serve` (`http://127.0.0.1:8081`).
- **glow** : rendu Markdown en terminal.
- **mdcat** : alternative à `glow`, rendu Markdown en terminal.

**Choix technique** : binaires standalone plutôt que paquets système, pour rester indépendant de la distribution cible et ne pas polluer sa configuration — cohérent avec l'objectif "kit sans référence à une distribution particulière".

### `justfile` — Orchestration

Recette par script (`sync`, `flatpak-download`, `flatpak-install`, `provision`), plus :

- **`check-space`** : bilan de l'espace disque occupé par le dataset (`df` de la partition, `du` global et par sous-dossier).
- **`list`** : liste les refs Flatpak présents dans le dépôt OSTree local (`ostree refs`), pour vérifier le contenu déjà téléchargé sans reconstruire le dépôt.
- **`all`** : enchaîne `sync`, `flatpak-download`, `provision` et `check-space` — reconstruit l'intégralité du kit et affiche son poids final. `flatpak-install` n'en fait volontairement pas partie : c'est une étape à exécuter *sur la machine cible*, hors-ligne, séparément.

## Résultats attendus

Après un `just all` sur une machine connectée, le dépôt contient :

- `flatpak-repo/.ostree/repo` : dépôt OSTree offline, sideloadable
- `ressources/github_docs/` : documentation extraite (sans code ni historique)
- `ressources/ebooks/` : PDF/EPUB de référence
- `ressources/git/` : dépôts personnels complets
- `ressources/llm/` : modèle(s) GGUF
- `ressources/zims/` : archives Kiwix
- `ressources/man/` : pages man exportées en HTML
- `reading_tools/{llama,kiwix,glow,mdcat}/` : binaires standalone prêts à l'emploi

L'ensemble est copiable tel quel sur la machine cible ; une fois là-bas, `just flatpak-install` installe les applications sans réseau, et les binaires de `reading_tools/` permettent de consulter LLM, ZIM et Markdown sans autre dépendance.

## Prérequis

- `bash`, `curl`, `tar`, `git`, `jq`
- `flatpak` (version supportant `create-usb`) pour la partie applications
- `just` pour l'orchestration
- `man2html` (optionnel) pour l'export des pages man
- `ostree` (optionnel) pour `just list`
