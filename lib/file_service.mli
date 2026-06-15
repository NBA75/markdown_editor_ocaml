(** Accès au système de fichiers, isolé du reste de l'application.

    Toutes les opérations renvoient un [result] : aucune exception système
    n'est laissée remonter. Les erreurs sont classées dans un type dédié pour
    permettre des messages compréhensibles. *)

type error =
  | Not_found of string         (** Fichier ou chemin absent. *)
  | Permission_denied of string (** Droits d'accès insuffisants. *)
  | Invalid_path of string      (** Chemin vide, dossier, ou autrement invalide. *)
  | Io_error of string          (** Autre erreur d'entrée/sortie. *)

val string_of_error : error -> string
(** Message lisible (en français) décrivant l'erreur. *)

val read_file : string -> (string, error) result
(** Lit l'intégralité d'un fichier texte. *)

val write_file : string -> string -> (unit, error) result
(** [write_file path content] écrit (ou écrase) le fichier [path]. *)

val export_html : string -> string -> (unit, error) result
(** [export_html path html] écrit le document HTML [html] dans [path]. *)

val ensure_parent_dir : string -> unit
(** Crée le dossier parent de [path] (et ses ancêtres) s'il n'existe pas.
    Best-effort : n'échoue pas si le dossier existe déjà. *)
