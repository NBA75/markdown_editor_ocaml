(** Recherche et remplacement de texte brut (sous-chaînes, sans expressions
    régulières). Logique pure et testable.

    Les occurrences sont recherchées sans chevauchement, de gauche à droite.
    La comparaison insensible à la casse se fait sur l'ASCII
    ([String.lowercase_ascii]) : les majuscules accentuées ne sont pas repliées. *)

val positions : ?case_sensitive:bool -> pattern:string -> string -> int list
(** Décalages (en octets) de début de chaque occurrence de [pattern].
    Liste vide si [pattern] est vide. Défaut : [case_sensitive = true]. *)

val count : ?case_sensitive:bool -> pattern:string -> string -> int
(** Nombre d'occurrences de [pattern]. *)

val replace_all :
  ?case_sensitive:bool -> pattern:string -> replacement:string -> string -> string * int
(** [replace_all ~pattern ~replacement text] renvoie le texte transformé et le
    nombre de remplacements effectués. Le texte inséré n'est jamais ré-analysé
    (pas de boucle si [replacement] contient [pattern]). *)
