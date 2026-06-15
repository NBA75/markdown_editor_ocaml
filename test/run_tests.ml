(* Point d'entrée des tests : agrège les suites de chaque module. *)
let () =
  Alcotest.run "markdown_editor"
    (Test_document.tests @ Test_markdown_renderer.tests @ Test_file_service.tests
   @ Test_config.tests @ Test_recent_files.tests @ Test_text_search.tests
   @ Test_editor_state.tests)
