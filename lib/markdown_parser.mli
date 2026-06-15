(** Analyse (parsing) du Markdown brut vers une structure intermédiaire typée.

    Le parseur est volontairement simple et pragmatique : il couvre le
    sous-ensemble Markdown exigé par le cahier des charges (titres, paragraphes,
    gras, italique, code, listes, liens, images, citations, séparateurs) sans
    viser la conformité CommonMark intégrale. La structure produite est ensuite
    convertie en HTML par {!Markdown_renderer}. *)

(** Éléments « en ligne » (à l'intérieur d'un bloc de texte). *)
type inline =
  | Text of string                              (** Texte brut (sera échappé au rendu). *)
  | Bold of inline list                         (** Gras : [**...**] ou [__...__]. *)
  | Italic of inline list                       (** Italique : [*...*] ou [_..._]. *)
  | Code of string                              (** Code en ligne : [`...`]. *)
  | Link of { text : inline list; href : string }   (** Lien : [\[texte\](url)]. *)
  | Image of { alt : string; src : string }     (** Image : [!\[alt\](src)]. *)

(** Nature d'une liste. *)
type list_kind =
  | Bullet    (** Liste à puces ([-], [*], [+]). *)
  | Ordered   (** Liste numérotée ([1.], [2.], ...). *)

(** Éléments « blocs ». *)
type block =
  | Heading of int * inline list            (** Titre de niveau 1 à 6. *)
  | Paragraph of inline list                (** Paragraphe. *)
  | Code_block of string option * string    (** Bloc de code clôturé : langage optionnel, contenu brut. *)
  | Block_quote of block list               (** Citation (peut contenir d'autres blocs). *)
  | List of list_kind * inline list list    (** Liste : chaque élément est une suite d'« inline ». *)
  | Thematic_break                          (** Séparateur horizontal ([---], [***], [___]). *)

type document = block list

val parse : string -> document
(** [parse markdown] transforme le texte Markdown en structure typée. Ne lève
    jamais d'exception : toute entrée produit un document (éventuellement vide). *)
