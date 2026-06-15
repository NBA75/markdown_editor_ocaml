open Markdown_editor

let render = Markdown_renderer.render_string

(* Vrai si [sub] est une sous-chaîne de [s]. *)
let contains s sub =
  let ls = String.length s and lu = String.length sub in
  let rec loop i =
    if i + lu > ls then false
    else if String.sub s i lu = sub then true
    else loop (i + 1)
  in
  loop 0

let check_has name sub s = Alcotest.(check bool) (name ^ " contient « " ^ sub ^ " »") true (contains s sub)
let check_hasnt name sub s = Alcotest.(check bool) (name ^ " ne contient pas « " ^ sub ^ " »") false (contains s sub)

let test_heading () = check_has "titre" "<h1>Titre</h1>" (render "# Titre")
let test_heading_levels () = check_has "titre 3" "<h3>Sous-sous-titre</h3>" (render "### Sous-sous-titre")
let test_paragraph () = check_has "paragraphe" "<p>Bonjour le monde</p>" (render "Bonjour le monde")
let test_bold () = check_has "gras" "<strong>gras</strong>" (render "du **gras** ici")
let test_italic () = check_has "italique" "<em>ital</em>" (render "du *ital* ici")
let test_inline_code () = check_has "code inline" "<code>x = 1</code>" (render "voici `x = 1`")

let test_escape () =
  let out = render "Danger <script>alert(1)</script>" in
  check_has "échappement <" "&lt;script&gt;" out;
  check_hasnt "pas de balise script brute" "<script>" out

let test_link () = check_has "lien" "<a href=\"http://exemple.fr\">site</a>" (render "[site](http://exemple.fr)")
let test_image () = check_has "image" "<img src=\"img.png\" alt=\"logo\" />" (render "![logo](img.png)")

let test_link_xss () =
  let out = render "[piège](javascript:alert(1))" in
  check_hasnt "schéma javascript neutralisé" "javascript:" out;
  check_has "href neutralisé" "href=\"#\"" out

let test_bullet_list () =
  let out = render "- pomme\n- poire" in
  check_has "ul" "<ul>" out;
  check_has "item pomme" "<li>pomme</li>" out;
  check_has "item poire" "<li>poire</li>" out

let test_ordered_list () =
  let out = render "1. un\n2. deux" in
  check_has "ol" "<ol>" out;
  check_has "item un" "<li>un</li>" out

let test_code_block () =
  let out = render "```ocaml\nlet x = 1\n```" in
  check_has "pre/code" "<pre><code class=\"language-ocaml\">" out;
  check_has "contenu code" "let x = 1" out

let test_blockquote () = check_has "citation" "<blockquote>" (render "> une citation")
let test_thematic_break () = check_has "séparateur" "<hr />" (render "---")

let test_export_page () =
  let html = Markdown_renderer.render_page ~title:"Doc" (render "# Salut") in
  check_has "doctype" "<!DOCTYPE html>" html;
  check_has "titre de page" "<title>Doc</title>" html;
  check_has "corps rendu" "<h1>Salut</h1>" html

let tests =
  [ ( "Markdown_renderer",
      [ Alcotest.test_case "titre h1" `Quick test_heading;
        Alcotest.test_case "titre h3" `Quick test_heading_levels;
        Alcotest.test_case "paragraphe" `Quick test_paragraph;
        Alcotest.test_case "gras" `Quick test_bold;
        Alcotest.test_case "italique" `Quick test_italic;
        Alcotest.test_case "code inline" `Quick test_inline_code;
        Alcotest.test_case "échappement HTML" `Quick test_escape;
        Alcotest.test_case "lien" `Quick test_link;
        Alcotest.test_case "image" `Quick test_image;
        Alcotest.test_case "lien XSS neutralisé" `Quick test_link_xss;
        Alcotest.test_case "liste à puces" `Quick test_bullet_list;
        Alcotest.test_case "liste numérotée" `Quick test_ordered_list;
        Alcotest.test_case "bloc de code" `Quick test_code_block;
        Alcotest.test_case "citation" `Quick test_blockquote;
        Alcotest.test_case "séparateur" `Quick test_thematic_break;
        Alcotest.test_case "page d'export" `Quick test_export_page ] ) ]
