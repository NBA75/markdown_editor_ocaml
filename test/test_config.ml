open Markdown_editor

let test_roundtrip () =
  let cfg =
    Config.{ theme = Dark; default_dir = "/home/x/docs"; auto_preview = false; auto_save = true }
  in
  let cfg' = Config.of_string (Config.to_string cfg) in
  Alcotest.(check bool) "thème conservé" true (cfg'.Config.theme = Config.Dark);
  Alcotest.(check string) "dossier conservé" "/home/x/docs" cfg'.Config.default_dir;
  Alcotest.(check bool) "auto_preview conservé" false cfg'.Config.auto_preview;
  Alcotest.(check bool) "auto_save conservé" true cfg'.Config.auto_save

let test_auto_save_default () =
  Alcotest.(check bool) "autosauvegarde désactivée par défaut" false Config.default.Config.auto_save;
  Alcotest.(check bool) "auto_save lu" true (Config.of_string "auto_save=true").Config.auto_save

let test_defaults_on_garbage () =
  let cfg = Config.of_string "ceci n'est pas une config\n=valeur sans clé\n# commentaire" in
  Alcotest.(check bool) "thème par défaut" true (cfg.Config.theme = Config.Light);
  Alcotest.(check bool) "auto_preview par défaut" true cfg.Config.auto_preview

let test_partial () =
  let cfg = Config.of_string "theme=dark" in
  Alcotest.(check bool) "thème lu" true (cfg.Config.theme = Config.Dark);
  Alcotest.(check bool) "reste par défaut" true cfg.Config.auto_preview

let test_save_load_roundtrip () =
  let path = Filename.temp_file "mdcfg" ".conf" in
  let cfg = Config.{ theme = Dark; default_dir = "."; auto_preview = false; auto_save = true } in
  (match Config.save path cfg with Ok () -> () | Error e -> Alcotest.failf "save: %s" e);
  let loaded = Config.load path in
  Alcotest.(check bool) "thème relu" true (loaded.Config.theme = Config.Dark);
  Alcotest.(check bool) "auto_preview relu" false loaded.Config.auto_preview;
  Sys.remove path

let test_default_path () =
  let p = Config.default_path () in
  let ends_with s suf =
    let ls = String.length s and lf = String.length suf in
    ls >= lf && String.sub s (ls - lf) lf = suf
  in
  Alcotest.(check bool) "chemin standard" true (ends_with p "markdown_editor/config")

let tests =
  [ ( "Config",
      [ Alcotest.test_case "aller-retour mémoire" `Quick test_roundtrip;
        Alcotest.test_case "autosauvegarde par défaut" `Quick test_auto_save_default;
        Alcotest.test_case "valeurs par défaut sur entrée invalide" `Quick test_defaults_on_garbage;
        Alcotest.test_case "config partielle" `Quick test_partial;
        Alcotest.test_case "aller-retour disque" `Quick test_save_load_roundtrip;
        Alcotest.test_case "chemin par défaut XDG" `Quick test_default_path ] ) ]
