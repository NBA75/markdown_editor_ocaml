open Markdown_editor

let check_list name expected got =
  Alcotest.(check (list string)) name expected got

let test_add_empty_list () =
  check_list "ajout dans liste vide" [ "a.md" ] (Recent_files.add ~max:10 "a.md" [])

let test_add_front () =
  check_list "le plus récent en tête" [ "b.md"; "a.md" ]
    (Recent_files.add ~max:10 "b.md" [ "a.md" ])

let test_dedup_moves_to_front () =
  check_list "doublon remonté sans répétition" [ "a.md"; "c.md"; "b.md" ]
    (Recent_files.add ~max:10 "a.md" [ "c.md"; "b.md"; "a.md" ])

let test_cap () =
  (* On ajoute dans l'ordre 1, 2, ..., 6 : le plus récent est donc "6.md". *)
  let l =
    List.fold_left
      (fun acc i -> Recent_files.add ~max:3 (string_of_int i ^ ".md") acc)
      [] [ 1; 2; 3; 4; 5; 6 ]
  in
  Alcotest.(check int) "taille bornée à 3" 3 (List.length l);
  check_list "trois plus récents" [ "6.md"; "5.md"; "4.md" ] l

let test_empty_path_ignored () =
  check_list "chemin vide ignoré" [ "a.md" ] (Recent_files.add ~max:10 "   " [ "a.md" ])

let test_string_roundtrip () =
  let l = [ "/x/a.md"; "/y/b.md" ] in
  check_list "aller-retour texte" l (Recent_files.of_string (Recent_files.to_string l))

let test_save_load () =
  let path = Filename.temp_file "mdrecent" ".lst" in
  let l = [ "/tmp/a.md"; "/tmp/b.md" ] in
  (match Recent_files.save path l with Ok () -> () | Error e -> Alcotest.failf "save: %s" e);
  check_list "relu depuis le disque" l (Recent_files.load path);
  Sys.remove path

let tests =
  [ ( "Recent_files",
      [ Alcotest.test_case "ajout liste vide" `Quick test_add_empty_list;
        Alcotest.test_case "ajout en tête" `Quick test_add_front;
        Alcotest.test_case "déduplication" `Quick test_dedup_moves_to_front;
        Alcotest.test_case "troncature à max" `Quick test_cap;
        Alcotest.test_case "chemin vide ignoré" `Quick test_empty_path_ignored;
        Alcotest.test_case "aller-retour texte" `Quick test_string_roundtrip;
        Alcotest.test_case "aller-retour disque" `Quick test_save_load ] ) ]
