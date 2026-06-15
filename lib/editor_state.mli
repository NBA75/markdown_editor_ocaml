(** État applicatif : relie le document courant et la configuration, et orchestre
    les opérations utilisateur (nouveau, ouvrir, modifier, sauvegarder, exporter).

    Les opérations qui touchent au disque renvoient un [result] dont l'erreur est
    celle de {!File_service}.

    Note : ce module fournit une API d'orchestration « avec état » prête à l'emploi.
    Le serveur web (bin/main.ml) est volontairement sans état et appelle directement
    {!Document}, {!File_service} et {!Markdown_renderer} ; il ne passe donc pas par
    ce module. {!Editor_state} reste utile pour une intégration alternative (TUI,
    autre frontal) et est couvert par les tests. *)

type t = {
  document : Document.t;
  config : Config.t;
}

val init : ?config:Config.t -> unit -> t
(** État initial : document vierge et configuration fournie (ou par défaut). *)

val new_document : t -> t
(** Repart d'un document vierge. *)

val open_file : string -> t -> (t, File_service.error) result
(** Ouvre un fichier et en fait le document courant. *)

val update : string -> t -> t
(** Met à jour le contenu du document courant (saisie utilisateur). *)

val save : t -> (t, File_service.error) result
(** Enregistre le document courant. Échoue si aucun chemin n'est associé. *)

val save_as : string -> t -> (t, File_service.error) result
(** Enregistre le document courant sous un nouveau chemin, qui devient le chemin courant. *)

val export_html : string -> t -> (unit, File_service.error) result
(** Exporte le document courant en HTML complet vers [path]. *)

val preview : t -> string
(** Fragment HTML de prévisualisation du document courant. *)

val is_modified : t -> bool
(** Le document courant a-t-il des modifications non sauvegardées ? *)
