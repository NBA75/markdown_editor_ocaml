open Markdown_editor

let test_roundtrip () =
  let path = Filename.temp_file "mdtest" ".md" in
  (match File_service.write_file path "contenu de test" with
   | Ok () -> ()
   | Error e -> Alcotest.failf "écriture inattendue en échec : %s" (File_service.string_of_error e));
  (match File_service.read_file path with
   | Ok s -> Alcotest.(check string) "aller-retour fichier" "contenu de test" s
   | Error e -> Alcotest.failf "lecture inattendue en échec : %s" (File_service.string_of_error e));
  Sys.remove path

let test_not_found () =
  match File_service.read_file "/chemin/inexistant/zzz_123456.md" with
  | Error (File_service.Not_found _) -> ()
  | Error e -> Alcotest.failf "attendu Not_found, obtenu : %s" (File_service.string_of_error e)
  | Ok _ -> Alcotest.fail "une erreur était attendue"

let test_invalid_empty_path () =
  match File_service.write_file "" "x" with
  | Error (File_service.Invalid_path _) -> ()
  | _ -> Alcotest.fail "chemin vide : Invalid_path attendu"

let test_export_html () =
  let path = Filename.temp_file "mdexport" ".html" in
  let html = Markdown_renderer.render_page ~title:"T" (Markdown_renderer.render_string "# Titre") in
  (match File_service.export_html path html with
   | Ok () -> ()
   | Error e -> Alcotest.failf "export en échec : %s" (File_service.string_of_error e));
  (match File_service.read_file path with
   | Ok s ->
     Alcotest.(check bool) "le HTML exporté est complet" true
       (String.length s > 0
        && (let lu = String.length "<!DOCTYPE html>" in
            String.length s >= lu && String.sub s 0 lu = "<!DOCTYPE html>"))
   | Error e -> Alcotest.failf "relecture en échec : %s" (File_service.string_of_error e));
  Sys.remove path

let tests =
  [ ( "File_service",
      [ Alcotest.test_case "écriture puis lecture" `Quick test_roundtrip;
        Alcotest.test_case "fichier absent => Not_found" `Quick test_not_found;
        Alcotest.test_case "chemin vide => Invalid_path" `Quick test_invalid_empty_path;
        Alcotest.test_case "export HTML sur disque" `Quick test_export_html ] ) ]
