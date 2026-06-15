type theme = Light | Dark

type t = {
  theme : theme;
  default_dir : string;
  auto_preview : bool;
  auto_save : bool;
}

let default = { theme = Light; default_dir = "."; auto_preview = true; auto_save = false }

let theme_to_string = function Light -> "light" | Dark -> "dark"

let theme_of_string s =
  match String.lowercase_ascii (String.trim s) with
  | "dark" | "sombre" -> Dark
  | _ -> Light

let bool_of_value s =
  match String.lowercase_ascii (String.trim s) with
  | "false" | "0" | "no" | "non" -> false
  | _ -> true

let of_string str =
  let lines = String.split_on_char '\n' str in
  List.fold_left
    (fun acc line ->
      let line = String.trim line in
      if line = "" || line.[0] = '#' then acc
      else
        match String.index_opt line '=' with
        | None -> acc
        | Some i ->
          let key = String.trim (String.sub line 0 i) in
          let v = String.trim (String.sub line (i + 1) (String.length line - i - 1)) in
          (match key with
           | "theme" -> { acc with theme = theme_of_string v }
           | "default_dir" -> { acc with default_dir = v }
           | "auto_preview" -> { acc with auto_preview = bool_of_value v }
           | "auto_save" -> { acc with auto_save = bool_of_value v }
           | _ -> acc))
    default lines

let to_string t =
  Printf.sprintf "theme=%s\ndefault_dir=%s\nauto_preview=%b\nauto_save=%b\n"
    (theme_to_string t.theme) t.default_dir t.auto_preview t.auto_save

let load path =
  match File_service.read_file path with
  | Ok s -> of_string s
  | Error _ -> default

(* Dossier de configuration standard (XDG), avec repli sur ~/.config. *)
let config_home () =
  match Sys.getenv_opt "XDG_CONFIG_HOME" with
  | Some d when String.trim d <> "" -> d
  | _ -> (
      match Sys.getenv_opt "HOME" with
      | Some h -> Filename.concat h ".config"
      | None -> ".")

let default_path () =
  Filename.concat (Filename.concat (config_home ()) "markdown_editor") "config"

let save path t =
  try
    File_service.ensure_parent_dir path;
    let oc = open_out_bin path in
    output_string oc (to_string t);
    close_out oc;
    Ok ()
  with Sys_error msg -> Error msg
