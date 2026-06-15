# Comprendre OCaml en partant d'un vrai projet

> Support pédagogique — l'éditeur Markdown de ce dépôt sert d'exemple fil rouge.
> Public : novices découvrant OCaml. Objectif : comprendre vite la **logique de
> programmation** (point d'entrée `main.ml` + bibliothèques `lib/`).

---

## 1. OCaml en une phrase

**OCaml est un langage compilé, à typage statique fort avec inférence de types,
multi-paradigme (fonctionnel d'abord, mais aussi impératif et objet), où
l'immuabilité et le filtrage de motifs (*pattern matching*) sont centraux.**

Traduction pour un débutant :
- **Compilé** : le code est transformé en programme natif rapide (pas interprété
  à la volée comme Python).
- **Typage statique fort** : chaque valeur a un type connu *avant* l'exécution ;
  beaucoup d'erreurs sont attrapées **à la compilation**.
- **Inférence de types** : on écrit *peu* d'annotations ; le compilateur **devine**
  les types tout seul. On a la sécurité du typage sans la lourdeur.
- **Fonctionnel d'abord** : on programme surtout avec des **fonctions** qui
  transforment des données **immuables** (on ne modifie pas, on **recrée**).

---

## 2. L'architecture « point d'entrée + bibliothèques »

C'est LE schéma mental à retenir. Un projet OCaml moderne (avec l'outil `dune`)
sépare :

- **`lib/` — la bibliothèque** : la *logique métier pure*, réutilisable et testable.
  C'est le **moteur**. Il ne sait rien du réseau ni de l'écran.
- **`bin/main.ml` — le point d'entrée** : l'exécutable. Il **orchestre** les
  modules de la bibliothèque et gère les *effets* (serveur web, fichiers).
- **`test/` — les tests** : vérifient la bibliothèque sans lancer l'application.

```
┌──────────────────────────────────────────────────────────────┐
│                      NAVIGATEUR (client)                       │
│          textarea (saisie)   ◄────►   aperçu HTML              │
└───────────────▲────────────────────────────┬──────────────────┘
                │ requêtes HTTP               │ réponses
                │ (localhost:8080)            ▼
┌───────────────┴────────────────────────────────────────────────┐
│                 bin/main.ml  —  POINT D'ENTRÉE                  │
│   let () = Dream.run … @@ Dream.router [ /api/preview, … ]      │
│   • démarre le serveur, route les requêtes                     │
│   • NE CONTIENT PAS la logique métier : il APPELLE la lib       │
└───────────────┬────────────────────────────────────────────────┘
                │ utilise
┌───────────────▼────────────────────────────────────────────────┐
│                  lib/  —  BIBLIOTHÈQUE (logique pure)           │
│                                                                │
│   Markdown_parser ──► Markdown_renderer     (Markdown → HTML)   │
│   Document   File_service   Config   Recent_files              │
│   Text_search   Editor_state                                   │
│                                                                │
│   chaque module = un .mli (le CONTRAT) + un .ml (le CODE)       │
└───────────────▲────────────────────────────────────────────────┘
                │ vérifiée par
        test/  (53 tests, framework Alcotest)
```

**Pourquoi cette séparation ?** Parce que la logique pure (transformer du
Markdown en HTML) est facile à **tester** et à **réutiliser**, tandis que les
*effets de bord* (lire un fichier, répondre sur le réseau) sont **confinés** aux
bords du programme. C'est une règle d'or de l'architecture logicielle.

---

## 3. Le flux de données, concrètement

Quand vous tapez `# Titre`, voici le voyage de la donnée :

```
 "# Titre"   ──parse──►   [ Heading (1, [Text "Titre"]) ]   ──render──►   "<h1>Titre</h1>"
  (string)                 AST typé : type « document »                     (string HTML)
   texte brut              représentation intermédiaire                     prêt à afficher
```

- `Markdown_parser.parse` : transforme du **texte** en **arbre typé** (AST,
  *Abstract Syntax Tree*).
- `Markdown_renderer.render` : transforme cet **arbre** en **HTML**.

Deux fonctions **pures** : mêmes entrées → mêmes sorties, aucun effet de bord.
C'est testable en une ligne, et c'est exactement ce que font nos tests.

---

## 4. Les 7 concepts OCaml illustrés par le code

### ① Modules et interfaces : `.ml` + `.mli`
Chaque brique a **deux fichiers** :
- `document.mli` = le **contrat public** (ce que les autres peuvent utiliser) ;
- `document.ml` = l'**implémentation** (cachée derrière le contrat).

C'est de l'**encapsulation** : on peut changer le `.ml` sans rien casser tant que
le `.mli` reste stable.

### ② Types algébriques : variants et records
La force d'OCaml. On **modélise le domaine** avec des types précis.

```ocaml
(* VARIANT (« somme ») : énumère les cas possibles d'un élément Markdown *)
type inline =
  | Text of string
  | Bold of inline list
  | Italic of inline list
  | Link of { text : inline list; href : string }

(* RECORD (« produit ») : regroupe des champs nommés *)
type t = { path : string option; content : string; saved_content : string }
```

### ③ Filtrage de motifs (*pattern matching*)
On traite **chaque cas** d'un type, et le compilateur **vérifie qu'on n'en oublie
aucun** :

```ocaml
let rec render_inline = function
  | Text s          -> escape_html s
  | Bold xs         -> "<strong>" ^ render_inlines xs ^ "</strong>"
  | Italic xs       -> "<em>"     ^ render_inlines xs ^ "</em>"
  | Link { text; href } -> ...
```

### ④ Immuabilité et fonctions pures
On ne **modifie** pas une donnée, on en **renvoie une nouvelle** :

```ocaml
let update_content content t = { t with content }
(* renvoie un NOUVEAU document ; l'ancien est intact *)
```

### ⑤ Gestion des erreurs par valeurs : `option` et `result`
Pas de `null`, pas d'exception silencieuse. On rend l'échec **visible dans le type** :

```ocaml
val read_file : string -> (string, error) result
(* le résultat est SOIT Ok contenu, SOIT Error e ; impossible de l'ignorer *)

match File_service.read_file path with
| Ok contenu -> (* … *)
| Error e    -> (* message clair, pas de plantage *)
```

### ⑥ Inférence de types
On écrit `let add ~max path list = …` sans annoter, et OCaml **déduit**
`int -> string -> string list -> string list`. Sécurité maximale, verbosité minimale.

### ⑦ Le point d'entrée : `let () = …`
Un programme OCaml démarre par une expression de type `unit` (noté `()`, « rien à
renvoyer, juste des effets ») :

```ocaml
let () =
  Dream.run ~interface:"127.0.0.1" ~port
  @@ Dream.router [ Dream.post "/api/preview" preview_handler; … ]
```

L'opérateur `|>` (*pipe*) et `@@` enchaînent les transformations comme un tapis
roulant, ce qui rend le code lisible de gauche à droite / de haut en bas.

---

## 5. Positionnement d'OCaml face aux autres langages

| Critère | **OCaml** | Python | Java | JavaScript | Haskell | Rust | C |
|---|---|---|---|---|---|---|---|
| Typage | statique, **inféré** | dynamique | statique, verbeux | dynamique | statique, inféré | statique, inféré | statique, faible |
| Paradigme | fonctionnel + impératif + objet | multi | objet | multi | **pur** fonctionnel | multi | impératif |
| Vitesse | **élevée** (natif) | faible | élevée (JVM) | moyenne | élevée | **très élevée** | **maximale** |
| Mémoire | **GC** auto | GC | GC | GC | GC | **ownership** (sans GC) | manuelle |
| `null` / erreurs | **option/result** | exceptions | `null` + exceptions | `undefined` | Maybe/Either | Option/Result | pointeurs nus |
| Courbe d'apprentissage | moyenne | **facile** | moyenne | facile | difficile | difficile | moyenne-difficile |

### À retenir sur le positionnement
- **vs Python** : OCaml attrape les erreurs **à la compilation** et tourne **bien
  plus vite** ; Python a, en échange, un écosystème de bibliothèques gigantesque.
- **vs Java** : OCaml est **plus concis** (inférence, types algébriques, pattern
  matching) et **élimine le `null`** grâce à `option`.
- **vs Haskell** : même famille fonctionnelle, mais OCaml est **pragmatique** :
  effets de bord autorisés sans cérémonie, évaluation **stricte** (Haskell est
  paresseux et « pur »).
- **vs Rust** : parenté forte — **le premier compilateur Rust était écrit en
  OCaml**. Rust ajoute le contrôle mémoire fin (*ownership*, sans ramasse-miettes) ;
  OCaml garde un **GC** et reste plus simple à écrire.
- **vs C** : OCaml offre la **sûreté mémoire** (pas de segfault) et un GC, pour des
  performances souvent proches, au prix d'un contrôle bas niveau moindre.

### Où OCaml brille dans l'industrie
Compilateurs et analyse statique (Rust, **Flow** de Meta, **Hack**), preuve
formelle (l'assistant **Coq** est écrit en OCaml), finance quantitative
(**Jane Street** l'utilise massivement), outillage de build. Son point fort :
écrire des programmes **corrects** qui manipulent des structures complexes.

---

## 6. Mémo express (à garder sous les yeux)

| Idée clé | Ce que ça veut dire |
|---|---|
| **`.mli` / `.ml`** | contrat public / implémentation cachée |
| **`type … = A \| B of …`** | un variant : « c'est l'un de ces cas » |
| **`type t = { … }`** | un record : « un paquet de champs nommés » |
| **`match x with …`** | on traite chaque cas, le compilateur vérifie l'exhaustivité |
| **immuable** | on ne modifie pas, on **recrée** (`{ t with champ = … }`) |
| **`option`** | `Some v` ou `None` — remplace `null` |
| **`result`** | `Ok v` ou `Error e` — l'échec est dans le type |
| **`let () = …`** | le point d'entrée du programme (effets de bord) |
| **`\|>` et `@@`** | enchaîner des fonctions, lisible comme un tapis roulant |
| **inférence** | on annote peu, le compilateur déduit les types |

### Mini-lexique
- **AST** (*Abstract Syntax Tree*) : représentation arborescente et typée d'un
  texte/programme. Ici : le Markdown analysé.
- **Effet de bord** : action qui touche le monde extérieur (fichier, réseau,
  écran). On les confine dans `bin/` et `File_service`.
- **Fonction pure** : sans effet de bord ; même entrée → même sortie.
- **GC** (*Garbage Collector*) : libère automatiquement la mémoire inutilisée.
- **`dune`** : l'outil de build standard d'OCaml (compile, teste, lance).
- **`opam`** : le gestionnaire de paquets d'OCaml (installe les bibliothèques).

---

## 7. Pour pratiquer sur ce projet

```bash
opam install dream lwt alcotest      # dépendances (une fois)
dune build                           # compiler
dune runtest                         # lancer les 53 tests
dune exec bin/main.exe               # démarrer → http://127.0.0.1:8080
```

Bon point de départ pour lire le code dans l'ordre :
`document.mli` → `markdown_parser.mli` → `markdown_renderer.ml` → `bin/main.ml`.
