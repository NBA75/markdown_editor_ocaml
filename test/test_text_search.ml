open Markdown_editor

let test_count () =
  Alcotest.(check int) "trois occurrences" 3 (Text_search.count ~pattern:"a" "banana");
  Alcotest.(check int) "aucune" 0 (Text_search.count ~pattern:"z" "banana");
  Alcotest.(check int) "motif vide => 0" 0 (Text_search.count ~pattern:"" "banana")

let test_positions () =
  Alcotest.(check (list int)) "positions de 'na'" [ 2; 4 ]
    (Text_search.positions ~pattern:"na" "banana")

let test_non_overlapping () =
  (* "aa" dans "aaaa" : positions 0 et 2 (sans chevauchement). *)
  Alcotest.(check (list int)) "sans chevauchement" [ 0; 2 ]
    (Text_search.positions ~pattern:"aa" "aaaa")

let test_case_insensitive () =
  Alcotest.(check int) "insensible à la casse" 2
    (Text_search.count ~case_sensitive:false ~pattern:"ab" "ABabXY");
  Alcotest.(check int) "sensible à la casse" 1
    (Text_search.count ~case_sensitive:true ~pattern:"ab" "ABabXY")

let test_replace_all () =
  let out, n = Text_search.replace_all ~pattern:"chat" ~replacement:"chien" "le chat et le chat" in
  Alcotest.(check string) "texte remplacé" "le chien et le chien" out;
  Alcotest.(check int) "deux remplacements" 2 n

let test_replace_no_reanalysis () =
  (* Le texte inséré contient le motif : il ne doit pas être ré-analysé. *)
  let out, n = Text_search.replace_all ~pattern:"a" ~replacement:"aa" "aaa" in
  Alcotest.(check string) "pas de boucle" "aaaaaa" out;
  Alcotest.(check int) "trois remplacements" 3 n

let test_replace_preserves_case () =
  let out, n = Text_search.replace_all ~case_sensitive:false ~pattern:"le" ~replacement:"LE" "Le le LE" in
  Alcotest.(check string) "remplacement insensible casse" "LE LE LE" out;
  Alcotest.(check int) "trois" 3 n

let tests =
  [ ( "Text_search",
      [ Alcotest.test_case "comptage" `Quick test_count;
        Alcotest.test_case "positions" `Quick test_positions;
        Alcotest.test_case "sans chevauchement" `Quick test_non_overlapping;
        Alcotest.test_case "casse" `Quick test_case_insensitive;
        Alcotest.test_case "remplacer tout" `Quick test_replace_all;
        Alcotest.test_case "pas de ré-analyse" `Quick test_replace_no_reanalysis;
        Alcotest.test_case "casse insensible au remplacement" `Quick test_replace_preserves_case ] ) ]
