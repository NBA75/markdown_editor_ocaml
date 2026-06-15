(** Configuration locale de l'application, stockée dans un fichier texte simple.

    Format du fichier : une paire [clé=valeur] par ligne. Les lignes vides et
    celles commençant par [#] sont ignorées. Toute clé inconnue ou valeur
    invalide est ignorée au profit des valeurs par défaut (lecture tolérante). *)

type theme = Light | Dark

type t = {
  theme : theme;            (** Thème d'affichage. *)
  default_dir : string;     (** Dossier proposé par défaut à l'ouverture/sauvegarde. *)
  auto_preview : bool;      (** Prévisualisation automatique pendant la saisie. *)
  auto_save : bool;         (** Enregistrement automatique (uniquement si le document est nommé). *)
}

val default : t
(** Valeurs par défaut : thème clair, dossier courant, prévisualisation active,
    autosauvegarde désactivée. *)

val of_string : string -> t
(** Analyse le contenu d'un fichier de configuration (tolérant aux erreurs). *)

val to_string : t -> string
(** Sérialise la configuration au format [clé=valeur]. *)

val load : string -> t
(** Charge la configuration depuis un fichier ; renvoie {!default} si absent ou illisible. *)

val save : string -> t -> (unit, string) result
(** Écrit la configuration dans un fichier. Crée le dossier parent si nécessaire. *)

val default_path : unit -> string
(** Chemin standard du fichier de configuration :
    [$XDG_CONFIG_HOME/markdown_editor/config], ou à défaut
    [~/.config/markdown_editor/config]. *)
