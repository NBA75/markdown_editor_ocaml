(** Liste des fichiers récemment ouverts ou enregistrés.

    La liste est ordonnée du plus récent au plus ancien, sans doublon, et bornée
    en taille. La logique (ajout, déduplication, troncature) est pure et testable ;
    la persistance se fait dans un fichier texte (un chemin par ligne). *)

val default_path : unit -> string
(** Fichier de stockage standard : [~/.config/markdown_editor/recent]
    (à côté du fichier de configuration). *)

val add : max:int -> string -> string list -> string list
(** [add ~max path list] place [path] en tête, supprime un éventuel doublon, et
    tronque la liste à [max] éléments. Un chemin vide laisse la liste inchangée. *)

val of_string : string -> string list
(** Lit une liste depuis un contenu texte (une entrée par ligne, lignes vides ignorées). *)

val to_string : string list -> string
(** Sérialise la liste (une entrée par ligne). *)

val load : string -> string list
(** Charge la liste depuis un fichier ; liste vide si absent ou illisible. *)

val save : string -> string list -> (unit, string) result
(** Écrit la liste dans un fichier. Crée le dossier parent si nécessaire. *)

val existing : string list -> string list
(** Filtre les entrées dont le fichier n'existe plus sur le disque. *)
