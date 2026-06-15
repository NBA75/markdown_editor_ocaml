type t = {
  path : string option;
  content : string;
  saved_content : string;
}

let create ?path content = { path; content; saved_content = content }

let empty = { path = None; content = ""; saved_content = "" }

let is_modified t = t.content <> t.saved_content

let update_content content t = { t with content }

let mark_saved t = { t with saved_content = t.content }

let set_path path t = { t with path = Some path }

let filename t =
  match t.path with
  | None -> "(sans titre)"
  | Some p -> Filename.basename p

let is_whitespace = function ' ' | '\t' | '\n' | '\r' -> true | _ -> false

(* Compte les mots en parcourant le contenu une seule fois : on incrémente
   à chaque transition « dans un mot » -> « hors d'un mot ». *)
let word_count t =
  let s = t.content in
  let n = String.length s in
  let rec loop i in_word count =
    if i >= n then if in_word then count + 1 else count
    else if is_whitespace s.[i] then loop (i + 1) false (if in_word then count + 1 else count)
    else loop (i + 1) true count
  in
  loop 0 false 0

let char_count t = String.length t.content

let line_count t =
  if t.content = "" then 0
  else 1 + String.fold_left (fun acc c -> if c = '\n' then acc + 1 else acc) 0 t.content
