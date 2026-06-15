(** Conversion de la structure Markdown ({!Markdown_parser}) vers du HTML.

    Toutes les données issues du Markdown sont échappées : aucun contenu du
    document n'est interprété comme du HTML actif. Les URL de liens et d'images
    sont également filtrées (schémas dangereux neutralisés). *)

val escape_html : string -> string
(** Échappe les caractères HTML sensibles : esperluette, chevrons, guillemets et apostrophe. *)

val render_inline : Markdown_parser.inline -> string
(** Rend un élément « en ligne » en HTML. *)

val render_block : Markdown_parser.block -> string
(** Rend un bloc en HTML. *)

val render : Markdown_parser.document -> string
(** Rend un document entier en fragment HTML (sans entête de page). *)

val render_string : string -> string
(** Raccourci : [render_string md = render (Markdown_parser.parse md)]. *)

val render_page : title:string -> string -> string
(** [render_page ~title body] enveloppe un fragment HTML dans un document HTML
    complet et autonome (utilisé pour l'export). *)
