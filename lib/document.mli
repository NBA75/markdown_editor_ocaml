(** Représentation d'un document Markdown en cours d'édition.

    Un document garde son contenu courant et le dernier contenu réellement
    sauvegardé, ce qui permet de détecter les modifications non enregistrées
    sans effet de bord. *)

type t = {
  path : string option;        (** Chemin du fichier sur disque, [None] si jamais sauvegardé. *)
  content : string;            (** Contenu Markdown courant. *)
  saved_content : string;      (** Dernier contenu sauvegardé (référence pour la détection de modifications). *)
}

val create : ?path:string -> string -> t
(** [create ?path content] crée un document considéré comme « propre »
    (non modifié) : [content] et [saved_content] sont identiques. *)

val empty : t
(** Document vierge, sans chemin, non modifié. *)

val is_modified : t -> bool
(** [true] si le contenu courant diffère du dernier contenu sauvegardé. *)

val update_content : string -> t -> t
(** Remplace le contenu courant sans changer la référence sauvegardée. *)

val mark_saved : t -> t
(** Marque le contenu courant comme étant la nouvelle référence sauvegardée. *)

val set_path : string -> t -> t
(** Associe (ou réassocie) un chemin de fichier au document. *)

val filename : t -> string
(** Nom de fichier lisible, ou ["(sans titre)"] si le document n'a pas de chemin. *)

val word_count : t -> int
(** Nombre de mots (séquences séparées par des espaces). *)

val char_count : t -> int
(** Nombre de caractères du contenu. *)

val line_count : t -> int
(** Nombre de lignes du contenu (0 pour un contenu vide). *)
