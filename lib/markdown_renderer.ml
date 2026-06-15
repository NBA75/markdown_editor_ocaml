open Markdown_parser

let escape_html s =
  let b = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      match c with
      | '&' -> Buffer.add_string b "&amp;"
      | '<' -> Buffer.add_string b "&lt;"
      | '>' -> Buffer.add_string b "&gt;"
      | '"' -> Buffer.add_string b "&quot;"
      | '\'' -> Buffer.add_string b "&#39;"
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

(* Neutralise les schémas d'URL dangereux pour éviter l'injection de scripts
   via [javascript:], [data:] ou [vbscript:]. *)
let sanitize_url url =
  let u = String.trim url in
  let low = String.lowercase_ascii u in
  let dangerous = [ "javascript:"; "data:"; "vbscript:" ] in
  if List.exists (fun p -> String.starts_with ~prefix:p low) dangerous then "#" else u

let rec render_inline = function
  | Text s -> escape_html s
  | Bold xs -> "<strong>" ^ render_inlines xs ^ "</strong>"
  | Italic xs -> "<em>" ^ render_inlines xs ^ "</em>"
  | Code s -> "<code>" ^ escape_html s ^ "</code>"
  | Link { text; href } ->
    Printf.sprintf "<a href=\"%s\">%s</a>" (escape_html (sanitize_url href)) (render_inlines text)
  | Image { alt; src } ->
    Printf.sprintf "<img src=\"%s\" alt=\"%s\" />" (escape_html (sanitize_url src)) (escape_html alt)

and render_inlines xs = String.concat "" (List.map render_inline xs)

let rec render_block = function
  | Heading (lvl, xs) -> Printf.sprintf "<h%d>%s</h%d>" lvl (render_inlines xs) lvl
  | Paragraph xs -> "<p>" ^ render_inlines xs ^ "</p>"
  | Code_block (lang, content) ->
    let cls =
      match lang with
      | Some l -> Printf.sprintf " class=\"language-%s\"" (escape_html l)
      | None -> ""
    in
    Printf.sprintf "<pre><code%s>%s</code></pre>" cls (escape_html content)
  | Block_quote blocks -> "<blockquote>\n" ^ render blocks ^ "\n</blockquote>"
  | List (Bullet, items) -> "<ul>\n" ^ render_items items ^ "</ul>"
  | List (Ordered, items) -> "<ol>\n" ^ render_items items ^ "</ol>"
  | Thematic_break -> "<hr />"

and render_items items =
  String.concat "" (List.map (fun it -> "<li>" ^ render_inlines it ^ "</li>\n") items)

and render blocks = String.concat "\n" (List.map render_block blocks)

let render_string md = render (Markdown_parser.parse md)

let render_page ~title body =
  Printf.sprintf
    {html|<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>%s</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; line-height: 1.6;
           max-width: 760px; margin: 2rem auto; padding: 0 1rem; color: #222; }
    pre { background: #f4f4f4; padding: 0.8rem; border-radius: 6px; overflow-x: auto; }
    code { background: #f4f4f4; padding: 0.1rem 0.3rem; border-radius: 3px; }
    pre code { background: none; padding: 0; }
    blockquote { border-left: 4px solid #ddd; margin: 0; padding-left: 1rem; color: #555; }
    img { max-width: 100%%; }
    hr { border: none; border-top: 1px solid #ddd; }
  </style>
</head>
<body>
%s
</body>
</html>
|html}
    (escape_html title) body
