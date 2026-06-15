open Markdown_editor

let contains s sub =
  let ls = String.length s and lu = String.length sub in
  let rec loop i =
    if i + lu > ls then false
    else if String.sub s i lu = sub then true
    else loop (i + 1)
  in
  loop 0

let test_init_clean () =
  Alcotest.(check bool) "état initial non modifié" false (Editor_state.is_modified (Editor_state.init ()))

let test_update_modifies () =
  let s = Editor_state.init () |> Editor_state.update "abc" in
  Alcotest.(check bool) "modifié après saisie" true (Editor_state.is_modified s)

let test_new_document_resets () =
  let s = Editor_state.init () |> Editor_state.update "abc" |> Editor_state.new_document in
  Alcotest.(check bool) "document vierge non modifié" false (Editor_state.is_modified s)

let test_save_without_path_fails () =
  let s = Editor_state.init () |> Editor_state.update "abc" in
  match Editor_state.save s with
  | Error (File_service.Invalid_path _) -> ()
  | Error e -> Alcotest.failf "erreur inattendue : %s" (File_service.string_of_error e)
  | Ok _ -> Alcotest.fail "save sans chemin doit échouer"

let test_save_as_then_open () =
  let path = Filename.temp_file "mdstate" ".md" in
  let s = Editor_state.init () |> Editor_state.update "contenu" in
  (match Editor_state.save_as path s with
   | Ok s' ->
     Alcotest.(check bool) "propre après save_as" false (Editor_state.is_modified s');
     (match Editor_state.open_file path (Editor_state.init ()) with
      | Ok s2 ->
        Alcotest.(check bool) "ouvert non modifié" false (Editor_state.is_modified s2);
        Alcotest.(check string) "contenu relu" "contenu" s2.Editor_state.document.Document.content
      | Error e -> Alcotest.failf "open_file : %s" (File_service.string_of_error e))
   | Error e -> Alcotest.failf "save_as : %s" (File_service.string_of_error e));
  Sys.remove path

let test_preview () =
  let s = Editor_state.init () |> Editor_state.update "# Titre" in
  Alcotest.(check bool) "preview rend le titre" true (contains (Editor_state.preview s) "<h1>Titre</h1>")

let test_export_html () =
  let path = Filename.temp_file "mdstate" ".html" in
  let s = Editor_state.init () |> Editor_state.update "# Titre" in
  (match Editor_state.export_html path s with
   | Ok () -> ()
   | Error e -> Alcotest.failf "export_html : %s" (File_service.string_of_error e));
  (match File_service.read_file path with
   | Ok html -> Alcotest.(check bool) "HTML exporté complet" true (contains html "<h1>Titre</h1>")
   | Error e -> Alcotest.failf "relecture : %s" (File_service.string_of_error e));
  Sys.remove path

let tests =
  [ ( "Editor_state",
      [ Alcotest.test_case "init non modifié" `Quick test_init_clean;
        Alcotest.test_case "update => modifié" `Quick test_update_modifies;
        Alcotest.test_case "new_document réinitialise" `Quick test_new_document_resets;
        Alcotest.test_case "save sans chemin échoue" `Quick test_save_without_path_fails;
        Alcotest.test_case "save_as puis open" `Quick test_save_as_then_open;
        Alcotest.test_case "preview" `Quick test_preview;
        Alcotest.test_case "export HTML" `Quick test_export_html ] ) ]
