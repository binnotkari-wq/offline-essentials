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
├── package.sh                   # Empaquette le kit en un fichier SquashFS unique
├── flatpak-repo/
│   ├── flatpaks.json               # Liste déclarative des applications Flatpak
│   ├── flatpak_online-install.sh   # Installe la liste sur une machine EN LIGNE
│   ├── flatpak_local-archive.sh    # Construit le dépôt OSTree offline (sideload)
│   └── flatpak_offline-install.sh  # Installe depuis ce dépôt OSTree, HORS-LIGNE
├── ressources/
│   └── sync.sh                  # Docs Git, e-books, repos perso, LLM, ZIM, pages man
└── reading_tools/
    └── provision.sh             # Binaires standalone : llama.cpp, kiwix-tools, glow, mdcat
```

## Fonctions

### `flatpak-repo/` — Applications Flatpak hors-ligne

Flatpak sait installer des applications depuis un dépôt OSTree local (*sideload*), sans contact réseau, à condition que ce dépôt existe déjà. Le kit propose trois scripts distincts, car "installer des flatpaks" (utile même en ligne, sur une machine quelconque) et "construire un dépôt sideload" (utile seulement dans une optique offline) sont deux besoins différents :

- **`flatpak_online-install.sh`** (sur une machine connectée, ou n'importe laquelle) : lit `flatpaks.json`, ajoute le remote `flathub` si besoin, et installe chaque application listée si elle n'est pas déjà présente. Autonome et réutilisable tel quel pour simplement déployer une liste de flatpaks sur une machine en ligne.
- **`flatpak_local-archive.sh`** (sur une machine connectée) : réutilise (`source`) `flatpak_online-install.sh` pour s'assurer que chaque application est installée localement — prérequis technique de `flatpak create-usb`, qui ne copie que des refs déjà installés, sans rien télécharger lui-même — puis configure le `collection-id` sur `flathub` (obligatoire pour le sideload) et appelle `create-usb` pour construire/actualiser le dépôt OSTree autonome dans `flatpak-repo/.ostree/repo`.
- **`flatpak_offline-install.sh`** (sur la machine cible, hors-ligne) : configure le remote `flathub` avec le même `collection-id`, puis installe/actualise chaque application via `--sideload-repo`, sans accès réseau.
- **`flatpaks.json`** : chaque entrée est `{ "id": "...", "remote": "...", "branch": "..." }` (`remote`/`branch` optionnels, défaut `flathub`/`stable`). Un champ `note` libre permet de documenter des cas particuliers (ex. préférer une installation native sur NixOS pour certains paquets).

**Choix technique clé** : `flatpak_local-archive.sh` sourcerait sinon la même boucle d'installation que `flatpak_online-install.sh` — pour éviter cette duplication, il `source` directement le script d'installation online et en réutilise les fonctions (`install_apps_from_json`, `ensure_remote`...) ; une garde en fin de fichier (`if [[ "${BASH_SOURCE[0]}" == "${0}" ]]`) évite que la fonction `main` de `flatpak_online-install.sh` s'exécute une seconde fois quand il est sourcé. Quand plusieurs entrées du JSON partagent un même id avec des branches différentes (ex. deux versions d'un VulkanLayer), le ref complet à 3 segments (`id/arch/branche`) est utilisé pour éviter toute ambiguïté.

Les trois scripts sont idempotents : ni le remote ni le `collection-id` ne sont retouchés s'ils sont déjà corrects, Flatpak lui-même ne réinstalle pas une app déjà à jour, et `create-usb` ne copie que les objets manquants.

### `ressources/sync.sh` — Documentation, e-books, repos, LLM, ZIM, man

Un script unique en six sections, chacune indépendante des autres (une section en échec n'interrompt pas les suivantes) :

1. **Dépôts Git de documentation** (`github_docs/`) : clone en mode léger (`--depth 1 --filter=blob:none --no-checkout`) puis `sparse-checkout` en mode `--no-cone`, avec des patterns explicites : fichiers `*.md`, `*.rst`, `*.txt`, `*.adoc`, `README*` à la racine, plus le contenu complet des dossiers `doc/`, `docs/`, `documentation/`, `examples/`, `example/`, `man/`, `pages/`. Le mode `--no-cone` est nécessaire ici : le mode `--cone` (par défaut) rejette les patterns glob comme `README*` et se limite à des chemins de dossiers exacts — avec des dossiers seuls, tout dépôt dont la doc n'est pas au format Markdown (RST, XML, PDF...) passait à travers le filtre. Le `.git` et les fichiers source (`.c`, `.h`, `.go`, `.rs`, `.o`) sont ensuite supprimés : seule la doc est conservée, pas l'historique ni le code.
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

### `package.sh` — Empaquetage en un fichier unique

Empaquette `flatpak-repo/`, `ressources/` et `reading_tools/` en un seul fichier **SquashFS** (`offline-essentials.sqfs`), accompagné de sa somme de contrôle (`offline-essentials.sqfs.sha256`).

**Choix technique** : SquashFS plutôt qu'une simple archive tar/zip, pour deux raisons — un seul fichier compressé (zstd), facile à copier ou transférer, et surtout un format **en lecture seule par construction** : contrairement à un dossier ou une archive extraite, un SquashFS ne peut pas être remonté en écriture, ce qui garantit qu'il reste identique à ce qu'il était au moment de l'empaquetage. La somme SHA-256 générée à côté permet de vérifier l'intégrité après transfert, sur le même principe que le MD5 publié pour l'ISO du projet `fedora_custom-bootc`.

Ce fichier est volontairement **indépendant de toute image ou ISO** : il ne modifie ni n'embarque rien dans le pipeline bootc, il se copie simplement où besoin (seconde partition d'une clé USB, disque externe...). Une fois copié, il se monte en lecture seule :

```bash
sudo mount -o loop,ro offline-essentials.sqfs /mnt/offline-essentials
```

### `justfile` — Orchestration

Recette par script (`sync`, `flatpak-online-install`, `flatpak-local-archive`, `flatpak-offline-install`, `provision`, `package`), plus :

- **`check-space`** : bilan de l'espace disque occupé par le dataset (`df` de la partition, `du` global et par sous-dossier).
- **`list`** : liste les refs Flatpak présents dans le dépôt OSTree local (`ostree refs`), pour vérifier le contenu déjà téléchargé sans reconstruire le dépôt.
- **`all`** : enchaîne `sync`, `flatpak-local-archive`, `provision` et `check-space` — reconstruit l'intégralité du kit et affiche son poids final. `flatpak-offline-install` n'en fait volontairement pas partie : c'est une étape à exécuter *sur la machine cible*, hors-ligne, séparément. `package` non plus : c'est une étape de transfert, pas de reconstruction.

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

L'ensemble est copiable tel quel sur la machine cible ; une fois là-bas, `just flatpak-offline-install` installe les applications sans réseau, et les binaires de `reading_tools/` permettent de consulter LLM, ZIM et Markdown sans autre dépendance.

Pour un transfert en un seul fichier (clé USB, partage réseau...), `just package` produit `offline-essentials.sqfs` + `offline-essentials.sqfs.sha256` à la racine du dépôt.

## Prérequis

- `bash`, `curl`, `tar`, `git`, `jq`
- `flatpak` (version supportant `create-usb`) pour la partie applications
- `just` pour l'orchestration
- `squashfs-tools` (`mksquashfs`) pour `just package`
- `man2html` (optionnel) pour l'export des pages man
- `ostree` (optionnel) pour `just list`