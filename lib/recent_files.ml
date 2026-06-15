let default_path () =
  Filename.concat (Filename.dirname (Config.default_path ())) "recent"

(* Garde au plus [n] éléments en tête de liste. *)
let rec take n = function
  | [] -> []
  | _ when n <= 0 -> []
  | x :: xs -> x :: take (n - 1) xs

let add ~max path list =
  let path = String.trim path in
  if path = "" then list
  else
    let without = List.filter (fun p -> p <> path) list in
    take max (path :: without)

let of_string s =
  String.split_on_char '\n' s
  |> List.map String.trim
  |> List.filter (fun l -> l <> "")

let to_string list = String.concat "" (List.map (fun p -> p ^ "\n") list)

let load path =
  match File_service.read_file path with
  | Ok s -> of_string s
  | Error _ -> []

let save path list =
  try
    File_service.ensure_parent_dir path;
    let oc = open_out_bin path in
    output_string oc (to_string list);
    close_out oc;
    Ok ()
  with Sys_error msg -> Error msg

let existing list =
  List.filter (fun p -> Sys.file_exists p && not (Sys.is_directory p)) list
