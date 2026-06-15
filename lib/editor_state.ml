type t = {
  document : Document.t;
  config : Config.t;
}

let init ?(config = Config.default) () = { document = Document.empty; config }

let new_document t = { t with document = Document.empty }

let open_file path t =
  match File_service.read_file path with
  | Ok content -> Ok { t with document = Document.create ~path content }
  | Error e -> Error e

let update content t = { t with document = Document.update_content content t.document }

let save t =
  match t.document.Document.path with
  | None -> Error (File_service.Invalid_path "aucun fichier associé : utilisez « enregistrer sous »")
  | Some path -> (
      match File_service.write_file path t.document.Document.content with
      | Ok () -> Ok { t with document = Document.mark_saved t.document }
      | Error e -> Error e)

let save_as path t =
  match File_service.write_file path t.document.Document.content with
  | Ok () -> Ok { t with document = Document.mark_saved (Document.set_path path t.document) }
  | Error e -> Error e

let export_html path t =
  let html =
    Markdown_renderer.render_page
      ~title:(Document.filename t.document)
      (Markdown_renderer.render_string t.document.Document.content)
  in
  File_service.export_html path html

let preview t = Markdown_renderer.render_string t.document.Document.content

let is_modified t = Document.is_modified t.document
