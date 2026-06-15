let normalize case_sensitive s = if case_sensitive then s else String.lowercase_ascii s

let positions ?(case_sensitive = true) ~pattern hay =
  let plen = String.length pattern in
  if plen = 0 then []
  else begin
    let h = normalize case_sensitive hay in
    let p = normalize case_sensitive pattern in
    let n = String.length h in
    let rec loop i acc =
      if i + plen > n then List.rev acc
      else if String.sub h i plen = p then loop (i + plen) (i :: acc)
      else loop (i + 1) acc
    in
    loop 0 []
  end

let count ?(case_sensitive = true) ~pattern hay =
  List.length (positions ~case_sensitive ~pattern hay)

let replace_all ?(case_sensitive = true) ~pattern ~replacement hay =
  let plen = String.length pattern in
  if plen = 0 then (hay, 0)
  else begin
    let h = normalize case_sensitive hay in
    let p = normalize case_sensitive pattern in
    let n = String.length hay in
    let buf = Buffer.create n in
    let count = ref 0 in
    let i = ref 0 in
    while !i < n do
      if !i + plen <= n && String.sub h !i plen = p then begin
        Buffer.add_string buf replacement;
        incr count;
        i := !i + plen
      end
      else begin
        (* On copie le caractère original (casse et accents préservés). *)
        Buffer.add_char buf hay.[!i];
        incr i
      end
    done;
    (Buffer.contents buf, !count)
  end
