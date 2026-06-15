type inline =
  | Text of string
  | Bold of inline list
  | Italic of inline list
  | Code of string
  | Link of { text : inline list; href : string }
  | Image of { alt : string; src : string }

type list_kind = Bullet | Ordered

type block =
  | Heading of int * inline list
  | Paragraph of inline list
  | Code_block of string option * string
  | Block_quote of block list
  | List of list_kind * inline list list
  | Thematic_break

type document = block list

(* ------------------------------------------------------------------ *)
(* Petits utilitaires de chaînes                                        *)
(* ------------------------------------------------------------------ *)

(* Normalise les fins de ligne en '\n' (gère CRLF et CR isolés). *)
let normalize s =
  let b = Buffer.create (String.length s) in
  let n = String.length s in
  let i = ref 0 in
  while !i < n do
    let c = s.[!i] in
    if c = '\r' then begin
      Buffer.add_char b '\n';
      if !i + 1 < n && s.[!i + 1] = '\n' then incr i
    end
    else Buffer.add_char b c;
    incr i
  done;
  Buffer.contents b

(* Supprime les espaces et tabulations en début de chaîne. *)
let lstrip s =
  let n = String.length s in
  let j = ref 0 in
  while !j < n && (s.[!j] = ' ' || s.[!j] = '\t') do incr j done;
  String.sub s !j (n - !j)

let is_blank line = String.trim line = ""

(* Cherche la sous-chaîne [sub] dans [s] à partir de [from]. *)
let find_sub s sub from =
  let ls = String.length s and lu = String.length sub in
  if lu = 0 then Some from
  else begin
    let rec loop i =
      if i + lu > ls then None
      else if String.sub s i lu = sub then Some i
      else loop (i + 1)
    in
    loop from
  end

(* ------------------------------------------------------------------ *)
(* Reconnaissance des blocs (niveau ligne)                             *)
(* ------------------------------------------------------------------ *)

(* Titre ATX : 1 à 6 '#' suivis d'une espace. Renvoie (niveau, texte). *)
let heading_of line =
  let n = String.length line in
  let j = ref 0 in
  while !j < n && line.[!j] = '#' do incr j done;
  if !j >= 1 && !j <= 6 && !j < n && line.[!j] = ' ' then
    Some (!j, String.trim (String.sub line (!j + 1) (n - !j - 1)))
  else None

(* Bloc de code clôturé : ``` ou ~~~. *)
let is_fence line =
  let t = String.trim line in
  String.length t >= 3
  && (let p = String.sub t 0 3 in p = "```" || p = "~~~")

(* Séparateur horizontal : au moins 3 fois le même caractère (- * _),
   espaces autorisés entre eux. *)
let is_thematic_break line =
  let t = String.trim line in
  let len = String.length t in
  if len < 3 then false
  else begin
    let c = t.[0] in
    (c = '-' || c = '*' || c = '_')
    && String.for_all (fun x -> x = c || x = ' ') t
    && String.fold_left (fun acc x -> if x = c then acc + 1 else acc) 0 t >= 3
  end

let is_blockquote line =
  let t = lstrip line in
  String.length t > 0 && t.[0] = '>'

(* Retire le '>' de citation et une espace optionnelle. *)
let strip_quote line =
  let t = lstrip line in
  let t = String.sub t 1 (String.length t - 1) in
  if String.length t > 0 && t.[0] = ' ' then String.sub t 1 (String.length t - 1) else t

(* Élément de liste à puces : -, * ou + suivi d'une espace. *)
let bullet_item line =
  let t = lstrip line in
  if String.length t >= 2 && (t.[0] = '-' || t.[0] = '*' || t.[0] = '+') && t.[1] = ' '
  then Some (String.sub t 2 (String.length t - 2))
  else None

(* Élément de liste numérotée : chiffres suivis de '. '. *)
let ordered_item line =
  let t = lstrip line in
  let n = String.length t in
  let j = ref 0 in
  while !j < n && t.[!j] >= '0' && t.[!j] <= '9' do incr j done;
  if !j > 0 && !j < n && t.[!j] = '.' && !j + 1 < n && t.[!j + 1] = ' ' then
    Some (String.sub t (!j + 2) (n - !j - 2))
  else None

let list_item line =
  match bullet_item line with
  | Some c -> Some (Bullet, c)
  | None -> (match ordered_item line with Some c -> Some (Ordered, c) | None -> None)

(* Une ligne ouvre-t-elle un nouveau bloc ? Sert à clore un paragraphe. *)
let starts_new_block line =
  is_blank line || is_fence line || heading_of line <> None
  || is_thematic_break line || is_blockquote line || list_item line <> None

(* ------------------------------------------------------------------ *)
(* Analyse « inline »                                                   *)
(* ------------------------------------------------------------------ *)

(* À partir d'un '[' en position [start], reconnaît [texte](url).
   Renvoie (texte_brut, url, index_suivant). Pas de crochets imbriqués. *)
let parse_bracket s start =
  let n = String.length s in
  if start >= n || s.[start] <> '[' then None
  else begin
    let rec find_close j = if j >= n then None else if s.[j] = ']' then Some j else find_close (j + 1) in
    match find_close (start + 1) with
    | None -> None
    | Some rb ->
      if rb + 1 < n && s.[rb + 1] = '(' then begin
        let rec find_paren j = if j >= n then None else if s.[j] = ')' then Some j else find_paren (j + 1) in
        match find_paren (rb + 2) with
        | None -> None
        | Some rp ->
          let text = String.sub s (start + 1) (rb - start - 1) in
          let url = String.sub s (rb + 2) (rp - rb - 2) in
          Some (text, url, rp + 1)
      end
      else None
  end

let rec parse_inline s =
  let n = String.length s in
  let buf = Buffer.create 16 in
  let acc = ref [] in
  let flush () =
    if Buffer.length buf > 0 then begin
      acc := Text (Buffer.contents buf) :: !acc;
      Buffer.clear buf
    end
  in
  let i = ref 0 in
  while !i < n do
    let c = s.[!i] in
    let handled =
      if c = '\\' && !i + 1 < n then begin
        (* Échappement : le caractère suivant est pris littéralement. *)
        Buffer.add_char buf s.[!i + 1]; i := !i + 2; true
      end
      else if c = '!' && !i + 1 < n && s.[!i + 1] = '[' then begin
        match parse_bracket s (!i + 1) with
        | Some (alt, src, next) -> flush (); acc := Image { alt; src } :: !acc; i := next; true
        | None -> false
      end
      else if c = '[' then begin
        match parse_bracket s !i with
        | Some (text, href, next) ->
          flush (); acc := Link { text = parse_inline text; href } :: !acc; i := next; true
        | None -> false
      end
      else if c = '`' then begin
        match find_sub s "`" (!i + 1) with
        | Some j -> flush (); acc := Code (String.sub s (!i + 1) (j - !i - 1)) :: !acc; i := j + 1; true
        | None -> false
      end
      else if c = '*' || c = '_' then begin
        let double = !i + 1 < n && s.[!i + 1] = c in
        let marker = if double then String.make 2 c else String.make 1 c in
        let mlen = String.length marker in
        match find_sub s marker (!i + mlen) with
        | Some j when j > !i + mlen ->
          flush ();
          let inner = String.sub s (!i + mlen) (j - !i - mlen) in
          let node = if double then Bold (parse_inline inner) else Italic (parse_inline inner) in
          acc := node :: !acc; i := j + mlen; true
        | _ -> false
      end
      else false
    in
    if not handled then begin Buffer.add_char buf c; incr i end
  done;
  flush ();
  List.rev !acc

(* ------------------------------------------------------------------ *)
(* Analyse des blocs                                                    *)
(* ------------------------------------------------------------------ *)

let rec parse input =
  let input = normalize input in
  let lines = Array.of_list (String.split_on_char '\n' input) in
  let n = Array.length lines in
  let i = ref 0 in
  let blocks = ref [] in
  let push b = blocks := b :: !blocks in
  while !i < n do
    let line = lines.(!i) in
    if is_blank line then incr i
    else if is_fence line then begin
      let lang =
        let t = String.trim line in
        let rest = String.trim (String.sub t 3 (String.length t - 3)) in
        if rest = "" then None else Some rest
      in
      incr i;
      let buf = ref [] in
      while !i < n && not (is_fence lines.(!i)) do
        buf := lines.(!i) :: !buf; incr i
      done;
      if !i < n then incr i; (* saute la clôture *)
      push (Code_block (lang, String.concat "\n" (List.rev !buf)))
    end
    else match heading_of line with
      | Some (lvl, rest) -> push (Heading (lvl, parse_inline rest)); incr i
      | None ->
        if is_thematic_break line then (push Thematic_break; incr i)
        else if is_blockquote line then begin
          let buf = ref [] in
          while !i < n && is_blockquote lines.(!i) do
            buf := strip_quote lines.(!i) :: !buf; incr i
          done;
          let inner = String.concat "\n" (List.rev !buf) in
          push (Block_quote (parse inner))
        end
        else begin
          match list_item line with
          | Some (kind, _) ->
            let items = ref [] in
            let continue = ref true in
            while !continue && !i < n do
              match list_item lines.(!i) with
              | Some (k, c) when k = kind -> items := parse_inline c :: !items; incr i
              | _ -> continue := false
            done;
            push (List (kind, List.rev !items))
          | None ->
            (* Paragraphe : on accumule jusqu'à un nouveau bloc ou une ligne vide. *)
            let buf = ref [] in
            let continue = ref true in
            while !continue && !i < n do
              let l = lines.(!i) in
              if starts_new_block l then continue := false
              else (buf := l :: !buf; incr i)
            done;
            let text = String.concat " " (List.rev !buf) in
            push (Paragraph (parse_inline text))
        end
  done;
  List.rev !blocks
