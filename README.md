# Éditeur Markdown — OCaml

Application d'édition de fichiers Markdown **écrite intégralement en OCaml**,
servie **localement** dans le navigateur par un backend [Dream](https://aantron.github.io/dream/).
Le texte s'édite à gauche, l'aperçu HTML s'affiche en direct à droite ; les fichiers
sont lus et écrits sur votre disque, et la prévisualisation se fait via un moteur
Markdown → HTML écrit maison (aucune bibliothèque Markdown externe).

> Aucune donnée ne quitte votre machine : le serveur écoute uniquement sur
> `127.0.0.1` (localhost).

## Démarrage rapide (étudiants)

Prérequis : **OCaml ≥ 4.13**, **opam ≥ 2.2**, et la bibliothèque système **`libev-dev`**.

```bash
# 1. Récupérer le code
git clone <URL-du-dépôt> markdown_editor_ocaml
cd markdown_editor_ocaml

# 2. (Linux Debian/Ubuntu) dépendance système de Dream
sudo apt-get install -y libev-dev

# 3. Installer les dépendances OCaml du projet (lit le fichier .opam)
opam install . --deps-only --with-test
eval $(opam env)          # met dune/ocaml dans le PATH

# 4. Compiler, tester, lancer
make build
make test
make run                  # puis ouvrir http://127.0.0.1:8080
```

Sans `make` : `dune build`, `dune runtest`, `dune exec bin/main.exe`.

> Première étape de lecture conseillée : `docs/ocaml-pedagogie.md` (exposé) puis
> `document.mli` → `markdown_parser.mli` → `markdown_renderer.ml` → `bin/main.ml`.

## Description

- **Édition** : zone de saisie Markdown + barre d'outils (titres, gras, italique,
  code, listes, citations, liens, images).
- **Prévisualisation** : rendu HTML en direct (titres, paragraphes, gras, italique,
  code en ligne et en bloc, listes, liens, images, citations, séparateurs).
- **Fichiers** : nouveau, ouvrir, enregistrer, enregistrer sous, détection des
  modifications non sauvegardées, erreurs d'accès gérées proprement.
- **Fichiers récents** : menu « Récents » des derniers fichiers ouverts/enregistrés
  (10 max, sans doublon, plus récent en tête), réouverture en un clic, bouton
  « Vider », et masquage des fichiers qui n'existent plus.
- **Recherche / remplacement** : barre (`Ctrl+F`), navigation entre occurrences,
  remplacer une occurrence ou toutes, option sensible à la casse. Le moteur de
  remplacement est en OCaml (`Text_search`, testé) ; la mise en évidence est gérée
  côté navigateur.
- **Préférences** : thème clair/sombre **persistant**, dossier par défaut,
  prévisualisation automatique et **autosauvegarde** activables/désactivables —
  réglables depuis l'interface (bouton « ⚙ Préférences ») et mémorisés d'une session à l'autre.
- **Autosauvegarde** (désactivée par défaut) : enregistre le document après ~2 s
  d'inactivité, **uniquement si le fichier est déjà nommé** (jamais un « sans-titre »),
  avec un indicateur « 💾 auto HH:MM ».
- **Export** : génération d'un fichier HTML complet et autonome ; **export PDF** via
  l'impression du navigateur (« Imprimer → Enregistrer en PDF »), sans dépendance.
- **Sécurité** : tout le contenu Markdown est échappé au rendu ; les schémas d'URL
  dangereux (`javascript:`, `data:`, `vbscript:`) sont neutralisés.

## Architecture

La logique métier est isolée dans une bibliothèque **pure et testable**
(`lib/`), totalement indépendante du serveur web. Seul `bin/main.ml` dépend de Dream.

```
markdown_editor_ocaml/
├── dune-project
├── bin/
│   ├── dune
│   └── main.ml              # serveur Dream + page de l'éditeur (HTML/CSS/JS)
├── lib/                     # bibliothèque métier pure (aucun effet réseau)
│   ├── dune
│   ├── document.ml{,i}      # modèle de document + détection des modifications
│   ├── file_service.ml{,i}  # lecture/écriture/export disque (résultats typés)
│   ├── recent_files.ml{,i}  # liste des fichiers récents (logique pure + persistance)
│   ├── markdown_parser.ml{,i}   # Markdown -> AST typé
│   ├── markdown_renderer.ml{,i} # AST -> HTML échappé
│   ├── text_search.ml{,i}   # recherche / remplacement de texte (pur, testé)
│   ├── editor_state.ml{,i}  # orchestration des opérations utilisateur
│   └── config.ml{,i}        # configuration locale (thème, dossier, auto-aperçu)
├── test/                    # tests unitaires (alcotest)
│   ├── dune
│   ├── run_tests.ml
│   ├── test_document.ml
│   ├── test_file_service.ml
│   ├── test_markdown_renderer.ml
│   ├── test_config.ml
│   ├── test_recent_files.ml
│   └── test_text_search.ml
├── examples/
│   └── sample.md
└── README.md
```

**Pourquoi cette séparation ?** Le parsing et le rendu Markdown sont des fonctions
pures, faciles à tester sans démarrer de serveur. Les effets de bord (disque,
réseau) sont confinés dans `File_service` et `bin/main.ml`. Toutes les opérations
faillibles renvoient un `result` plutôt que de lever une exception.

### Justification des bibliothèques

- **dream** : serveur web OCaml moderne, routage simple, idéal pour une appli locale.
- **alcotest** : framework de tests unitaires courant de l'écosystème OCaml.
- **lwt** : bibliothèque de concurrence requise par Dream (pour lire le corps des requêtes).
- *Aucune* dépendance pour le Markdown lui-même : parser et renderer sont écrits maison.

## Prérequis

- OCaml ≥ 4.13
- `dune` ≥ 3.0
- `opam` ≥ 2.2 (pour installer les dépendances système de Dream)
- Bibliothèque système `libev-dev` (dépendance de Dream)

## Installation des dépendances

```bash
# Bibliothèque système requise par Dream
sudo apt-get install -y libev-dev

# Dépendances OCaml
opam install -y dream lwt alcotest
```

## Compilation

```bash
dune build
```

## Exécution

```bash
dune exec bin/main.exe
# puis ouvrir http://127.0.0.1:8080 dans un navigateur
```

Le port peut être changé via la variable d'environnement `PORT` :

```bash
PORT=9000 dune exec bin/main.exe
```

### Préférences et fichier de configuration

Les préférences se règlent via le bouton **« ⚙ Préférences »** (thème, dossier par
défaut, prévisualisation automatique). Elles sont enregistrées dans :

```
${XDG_CONFIG_HOME:-~/.config}/markdown_editor/config
```

Format `clé=valeur` (lisible et éditable à la main) :

```
theme=dark
default_dir=/home/vous/Documents
auto_preview=true
auto_save=false
```

L'application crée au plus **deux fichiers persistants** dans
`~/.config/markdown_editor/`, en dehors de vos documents : `config` (préférences)
et `recent` (liste des fichiers récents, un chemin par ligne).

Pour repartir d'un environnement totalement vierge :

```bash
rm -rf ~/.config/markdown_editor
```

### Arrêter l'application proprement

Deux moyens, tous deux laissent un environnement propre (processus arrêté, port libéré) :

- **Bouton « ⏻ Quitter »** dans la barre d'outils : arrête le serveur depuis le
  navigateur (route `POST /api/quit`), puis affiche un message de fermeture.
- **`Ctrl+C`** dans le terminal où le serveur tourne.

> Fermer simplement l'onglet du navigateur **n'arrête pas** le serveur : celui-ci
> continue de tourner et garde le port occupé. Utilisez le bouton « Quitter » ou `Ctrl+C`.
> L'application n'écrit aucun fichier temporaire : seuls les fichiers que vous
> sauvegardez ou exportez explicitement sont créés.

## Lancement des tests

```bash
dune runtest
```

## Exemples d'utilisation

1. Lancez le serveur, ouvrez `http://127.0.0.1:8080`.
2. Cliquez **Ouvrir** et saisissez `examples/sample.md` (chemin relatif au dossier de lancement).
3. Modifiez le texte : l'aperçu se met à jour automatiquement.
4. Cliquez **Enregistrer** pour écrire le fichier, ou **Exporter HTML** pour produire
   une page HTML autonome.
5. Cliquez **Exporter PDF** : une fenêtre imprimable s'ouvre et la boîte d'impression
   du navigateur apparaît ; choisissez « Enregistrer en PDF » comme destination.

## Limites connues

- Le sous-ensemble Markdown couvre les besoins courants mais n'est **pas**
  intégralement conforme à CommonMark (pas de tables GFM, pas de listes imbriquées,
  pas de titres « setext », liens de référence non gérés).
- L'ouverture/sauvegarde se fait par **saisie d'un chemin** (pas de sélecteur de
  fichier natif, contrainte des navigateurs).
- Application mono-document et mono-utilisateur (serveur local sans authentification).
- Recherche/remplacement : pas d'expressions régulières ; l'option « sensible à la
  casse » se replie sur l'ASCII (les majuscules accentuées ne sont pas égalées en
  mode insensible).
- Export PDF : passe par la boîte d'impression du navigateur (geste manuel) ;
  l'application n'écrit pas le `.pdf` directement.

## Pistes d'évolution

- Export PDF « direct » côté serveur (sans boîte d'impression) via un navigateur
  *headless* (chromium `--print-to-pdf`), si un export non interactif est souhaité.
- Listes imbriquées, tables.
- Sélecteur de fichiers via l'API File System Access des navigateurs compatibles.

## Licence

Distribué sous licence **MIT** (voir [LICENSE](LICENSE)) : réutilisation,
modification et redistribution libres, y compris à des fins pédagogiques.
Contribution **libre**, sans attribution à une personne ou une entité.
