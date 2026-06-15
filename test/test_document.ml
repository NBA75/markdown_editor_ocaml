open Markdown_editor

let test_create () =
  let d = Document.create "bonjour" in
  Alcotest.(check string) "contenu conservé" "bonjour" d.Document.content;
  Alcotest.(check bool) "non modifié à la création" false (Document.is_modified d)

let test_update_marks_modified () =
  let d = Document.create "a" |> Document.update_content "b" in
  Alcotest.(check bool) "modifié après édition" true (Document.is_modified d)

let test_mark_saved () =
  let d = Document.create "a" |> Document.update_content "b" |> Document.mark_saved in
  Alcotest.(check bool) "propre après sauvegarde" false (Document.is_modified d)

let test_filename () =
  let d = Document.create ~path:"/tmp/notes.md" "x" in
  Alcotest.(check string) "nom de fichier" "notes.md" (Document.filename d);
  Alcotest.(check string) "sans titre" "(sans titre)" (Document.filename (Document.create "x"))

let test_word_count () =
  Alcotest.(check int) "trois mots" 3 (Document.word_count (Document.create "le chat dort"));
  Alcotest.(check int) "vide = 0" 0 (Document.word_count (Document.create "   "));
  Alcotest.(check int) "espaces multiples" 2 (Document.word_count (Document.create "  un   deux  "))

let test_line_count () =
  Alcotest.(check int) "vide = 0 ligne" 0 (Document.line_count (Document.create ""));
  Alcotest.(check int) "trois lignes" 3 (Document.line_count (Document.create "a\nb\nc"))

let tests =
  [ ( "Document",
      [ Alcotest.test_case "création non modifiée" `Quick test_create;
        Alcotest.test_case "édition => modifié" `Quick test_update_marks_modified;
        Alcotest.test_case "mark_saved => propre" `Quick test_mark_saved;
        Alcotest.test_case "nom de fichier" `Quick test_filename;
        Alcotest.test_case "compteur de mots" `Quick test_word_count;
        Alcotest.test_case "compteur de lignes" `Quick test_line_count ] ) ]
