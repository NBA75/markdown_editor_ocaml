type error =
  | Not_found of string
  | Permission_denied of string
  | Invalid_path of string
  | Io_error of string

let string_of_error = function
  | Not_found p -> Printf.sprintf "Fichier introuvable : %s" p
  | Permission_denied p -> Printf.sprintf "Permission refusée : %s" p
  | Invalid_path p -> Printf.sprintf "Chemin invalide : %s" p
  | Io_error m -> Printf.sprintf "Erreur d'entrée/sortie : %s" m

(* Teste si [sub] apparaît dans [s] (utilisé pour classer les messages
   d'erreur système, qui ne sont pas structurés). *)
let contains s sub =
  let ls = String.length s and lu = String.length sub in
  if lu = 0 then true
  else begin
    let rec loop i =
      if i + lu > ls then false
      else if String.sub s i lu = sub then true
      else loop (i + 1)
    in
    loop 0
  end

(* Traduit un message Sys_error en erreur typée. *)
let classify path msg =
  if contains msg "No such file" || contains msg "n'existe pas" then Not_found path
  else if contains msg "Permission denied" || contains msg "Permission non accordée" then Permission_denied path
  else Io_error msg

let validate_path path =
  if String.trim path = "" then Error (Invalid_path "(chemin vide)")
  else if Sys.file_exists path && Sys.is_directory path then
    Error (Invalid_path (path ^ " est un dossier"))
  else Ok ()

let read_file path =
  match validate_path path with
  | Error e -> Error e
  | Ok () -> (
      try
        let ic = open_in_bin path in
        let n = in_channel_length ic in
        let content = really_input_string ic n in
        close_in ic;
        Ok content
      with
      | Sys_error msg -> Error (classify path msg))

let write_file path content =
  match validate_path path with
  | Error e -> Error e
  | Ok () -> (
      try
        let oc = open_out_bin path in
        output_string oc content;
        close_out oc;
        Ok ()
      with
      | Sys_error msg -> Error (classify path msg))

let export_html path html = write_file path html

(* Crée un dossier et ses parents si besoin (best-effort). *)
let rec mkdir_p dir =
  if dir = "" || dir = "." || dir = "/" || Sys.file_exists dir then ()
  else begin
    mkdir_p (Filename.dirname dir);
    try Unix.mkdir dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
  end

let ensure_parent_dir path = mkdir_p (Filename.dirname path)
