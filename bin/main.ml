(* Serveur web local de l'éditeur Markdown.

   Le navigateur détient le texte en cours d'édition ; le serveur fournit des
   services sans état :
     - GET  /              : la page de l'éditeur ;
     - POST /api/preview   : Markdown (corps) -> fragment HTML de prévisualisation ;
     - GET  /api/open      : ?path=...        -> contenu brut du fichier ;
     - POST /api/save      : ?path=... + corps (Markdown) -> écrit le fichier ;
     - POST /api/export    : ?path=... + corps (Markdown) -> écrit un HTML complet.

   Toute la logique Markdown et fichiers vient de la bibliothèque « markdown_editor ». *)

open Markdown_editor

(* Promesse d'arrêt : lorsqu'elle se résout, Dream s'arrête proprement
   (libère le port) et le programme se termine. Déclenchée par /api/quit. *)
let stop, stop_resolver = Lwt.wait ()

(* Nombre maximal de fichiers récents conservés. *)
let max_recents = 10

(* Ajoute un chemin à la liste des fichiers récents (best-effort). *)
let record_recent path =
  let store = Recent_files.default_path () in
  let updated = Recent_files.add ~max:max_recents path (Recent_files.load store) in
  ignore (Recent_files.save store updated)

(* --- Gestionnaires de routes --------------------------------------- *)

let preview_handler request =
  Lwt.bind (Dream.body request) (fun body ->
      Dream.html (Markdown_renderer.render_string body))

let open_handler request =
  match Dream.query request "path" with
  | None -> Dream.respond ~status:`Bad_Request "Paramètre « path » manquant."
  | Some path -> (
      match File_service.read_file path with
      | Ok content ->
        record_recent path;
        Dream.respond
          ~headers:[ ("Content-Type", "text/plain; charset=utf-8") ]
          content
      | Error e -> Dream.respond ~status:`Bad_Request (File_service.string_of_error e))

let save_handler request =
  match Dream.query request "path" with
  | None -> Dream.respond ~status:`Bad_Request "Paramètre « path » manquant."
  | Some path ->
    Lwt.bind (Dream.body request) (fun content ->
        match File_service.write_file path content with
        | Ok () -> record_recent path; Dream.respond "ok"
        | Error e -> Dream.respond ~status:`Bad_Request (File_service.string_of_error e))

let export_handler request =
  match Dream.query request "path" with
  | None -> Dream.respond ~status:`Bad_Request "Paramètre « path » manquant."
  | Some path ->
    Lwt.bind (Dream.body request) (fun md ->
        let html =
          Markdown_renderer.render_page ~title:(Filename.basename path)
            (Markdown_renderer.render_string md)
        in
        match File_service.export_html path html with
        | Ok () -> Dream.respond "ok"
        | Error e -> Dream.respond ~status:`Bad_Request (File_service.string_of_error e))

(* Renvoie le document HTML complet (page autonome) pour l'impression / export PDF.
   Réutilise render_page : la sortie est identique à l'export HTML. *)
let render_page_handler request =
  let title = Option.value ~default:"Document" (Dream.query request "title") in
  Lwt.bind (Dream.body request) (fun md ->
      Dream.html (Markdown_renderer.render_page ~title (Markdown_renderer.render_string md)))

(* Remplace toutes les occurrences d'un motif (moteur OCaml Text_search).
   Motif/remplacement/casse en paramètres d'URL, texte dans le corps.
   Renvoie le texte transformé ; le nombre de remplacements va dans l'en-tête. *)
let replace_handler request =
  let pattern = Option.value ~default:"" (Dream.query request "pattern") in
  let replacement = Option.value ~default:"" (Dream.query request "replacement") in
  let case_sensitive = Dream.query request "case" = Some "true" in
  Lwt.bind (Dream.body request) (fun text ->
      let out, n = Text_search.replace_all ~case_sensitive ~pattern ~replacement text in
      Dream.respond
        ~headers:
          [ ("Content-Type", "text/plain; charset=utf-8");
            ("X-Replacements", string_of_int n) ]
        out)

(* Renvoie la liste des fichiers récents existants (un chemin par ligne). *)
let recents_get_handler _request =
  let list = Recent_files.existing (Recent_files.load (Recent_files.default_path ())) in
  Dream.respond
    ~headers:[ ("Content-Type", "text/plain; charset=utf-8") ]
    (Recent_files.to_string list)

(* Vide la liste des fichiers récents. *)
let recents_clear_handler _request =
  match Recent_files.save (Recent_files.default_path ()) [] with
  | Ok () -> Dream.respond "ok"
  | Error e -> Dream.respond ~status:`Bad_Request e

(* Renvoie la configuration courante au format clé=valeur. *)
let config_get_handler _request =
  let cfg = Config.load (Config.default_path ()) in
  Dream.respond
    ~headers:[ ("Content-Type", "text/plain; charset=utf-8") ]
    (Config.to_string cfg)

(* Enregistre la configuration reçue (format clé=valeur) dans le fichier standard. *)
let config_post_handler request =
  Lwt.bind (Dream.body request) (fun body ->
      let cfg = Config.of_string body in
      match Config.save (Config.default_path ()) cfg with
      | Ok () -> Dream.respond "ok"
      | Error e -> Dream.respond ~status:`Bad_Request e)

(* Arrête proprement le serveur. On répond d'abord au navigateur, puis on
   déclenche l'arrêt après un court délai pour que la réponse soit bien partie. *)
let quit_handler _request =
  Lwt.async (fun () ->
      Lwt.bind (Lwt_unix.sleep 0.3) (fun () ->
          (try Lwt.wakeup_later stop_resolver () with _ -> ());
          Lwt.return_unit));
  Dream.respond "Le serveur s'arrête. Vous pouvez fermer cet onglet."

(* --- Page de l'éditeur (HTML + CSS + JS, servie telle quelle) -------- *)

let page =
  {page|<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Éditeur Markdown — OCaml</title>
  <style>
    :root { --bg:#ffffff; --fg:#1d1d1f; --panel:#f7f7f8; --border:#e2e2e6;
            --accent:#2563eb; --muted:#6b7280; }
    body.dark { --bg:#1e1e22; --fg:#e6e6e6; --panel:#27272c; --border:#3a3a40;
                --accent:#60a5fa; --muted:#9ca3af; }
    * { box-sizing: border-box; }
    body { margin:0; font-family: system-ui, -apple-system, sans-serif;
           background:var(--bg); color:var(--fg); height:100vh; display:flex; flex-direction:column; }
    header { display:flex; align-items:center; gap:.4rem; padding:.5rem .8rem;
             border-bottom:1px solid var(--border); flex-wrap:wrap; }
    header .title { font-weight:600; margin-right:.6rem; }
    header .sep { width:1px; height:22px; background:var(--border); margin:0 .3rem; }
    button { font:inherit; padding:.35rem .6rem; border:1px solid var(--border);
             background:var(--panel); color:var(--fg); border-radius:6px; cursor:pointer; }
    button:hover { border-color:var(--accent); color:var(--accent); }
    button.primary { background:var(--accent); color:#fff; border-color:var(--accent); }
    .spacer { flex:1; }
    .status { font-size:.85rem; color:var(--muted); }
    .status .modif { color:#d97706; font-weight:600; }
    main { flex:1; display:flex; min-height:0; }
    .pane { flex:1; min-width:0; display:flex; flex-direction:column; }
    .pane.editor { border-right:1px solid var(--border); }
    .pane h2 { font-size:.75rem; text-transform:uppercase; letter-spacing:.05em;
               color:var(--muted); margin:0; padding:.4rem .8rem; border-bottom:1px solid var(--border); }
    textarea { flex:1; border:0; resize:none; padding:1rem; font-family:ui-monospace, monospace;
               font-size:14px; line-height:1.6; background:var(--bg); color:var(--fg); outline:none; }
    .preview { flex:1; overflow-y:auto; padding:1rem 1.4rem; line-height:1.6; }
    .preview pre { background:var(--panel); padding:.8rem; border-radius:6px; overflow-x:auto; }
    .preview code { background:var(--panel); padding:.1rem .3rem; border-radius:3px; }
    .preview pre code { background:none; padding:0; }
    .preview blockquote { border-left:4px solid var(--border); margin:0; padding-left:1rem; color:var(--muted); }
    .preview img { max-width:100%; }
    .preview hr { border:none; border-top:1px solid var(--border); }
    .overlay { position:fixed; inset:0; background:rgba(0,0,0,.45); display:none;
               align-items:center; justify-content:center; z-index:10; }
    .overlay.open { display:flex; }
    .dialog { background:var(--bg); color:var(--fg); border:1px solid var(--border);
              border-radius:10px; padding:1.2rem 1.4rem; width:min(440px,92vw); }
    .dialog h3 { margin:0 0 1rem; }
    .field { margin-bottom:1rem; display:flex; flex-direction:column; gap:.3rem; }
    .field label { font-size:.85rem; color:var(--muted); }
    .field input[type=text], .field select { padding:.4rem; border:1px solid var(--border);
              border-radius:6px; background:var(--panel); color:var(--fg); font:inherit; }
    .field.row { flex-direction:row; align-items:center; gap:.5rem; }
    .dialog .actions { display:flex; justify-content:flex-end; gap:.5rem; margin-top:.5rem; }
    .recents-wrap { position:relative; display:inline-block; }
    .menu { display:none; position:absolute; top:100%; left:0; margin-top:.2rem;
            min-width:260px; max-width:60vw; background:var(--bg); border:1px solid var(--border);
            border-radius:6px; box-shadow:0 6px 20px rgba(0,0,0,.18); z-index:5;
            max-height:60vh; overflow:auto; }
    .menu.open { display:block; }
    .menu .item { padding:.45rem .6rem; cursor:pointer; white-space:nowrap; overflow:hidden;
                  text-overflow:ellipsis; font-size:.9rem; }
    .menu .item .dir { color:var(--muted); font-size:.8rem; }
    .menu .item:hover { background:var(--panel); color:var(--accent); }
    .menu .empty { padding:.6rem; color:var(--muted); font-size:.85rem; }
    .menu .footer { border-top:1px solid var(--border); }
    .menu .footer button { width:100%; border:0; border-radius:0; background:none; text-align:left; }
    .searchbar { display:none; gap:.4rem; align-items:center; padding:.4rem .8rem;
                 border-bottom:1px solid var(--border); background:var(--panel); flex-wrap:wrap; }
    .searchbar.open { display:flex; }
    .searchbar input[type=text] { padding:.3rem .5rem; border:1px solid var(--border);
                 border-radius:6px; background:var(--bg); color:var(--fg); font:inherit; }
    .searchbar .count { font-size:.85rem; color:var(--muted); min-width:90px; }
    .searchbar label.case { font-size:.85rem; color:var(--muted); display:flex; align-items:center; gap:.25rem; }
  </style>
</head>
<body>
  <header>
    <span class="title">📝 Markdown · OCaml</span>
    <button id="btn-new">Nouveau</button>
    <button id="btn-open">Ouvrir</button>
    <span class="recents-wrap">
      <button id="btn-recents" title="Fichiers récents">Récents ▾</button>
      <div class="menu" id="recents-menu"></div>
    </span>
    <button id="btn-save" class="primary">Enregistrer</button>
    <button id="btn-saveas">Enregistrer sous</button>
    <button id="btn-export">Exporter HTML</button>
    <button id="btn-pdf">Exporter PDF</button>
    <span class="sep"></span>
    <button data-md="h1">H1</button>
    <button data-md="h2">H2</button>
    <button data-md="bold"><b>B</b></button>
    <button data-md="italic"><i>I</i></button>
    <button data-md="code">&lt;/&gt;</button>
    <button data-md="ul">• Liste</button>
    <button data-md="ol">1. Liste</button>
    <button data-md="quote">❝</button>
    <button data-md="link">Lien</button>
    <button data-md="image">Image</button>
    <span class="sep"></span>
    <button id="btn-search" title="Rechercher / remplacer (Ctrl+F)">🔍</button>
    <button id="btn-preview" title="Rafraîchir l'aperçu" style="display:none">Aperçu</button>
    <span class="spacer"></span>
    <span class="status" id="status">Nouveau document</span>
    <span class="sep"></span>
    <button id="btn-prefs" title="Préférences">⚙ Préférences</button>
    <button id="btn-theme" title="Thème clair/sombre (cette session)">🌓</button>
    <button id="btn-quit" title="Arrêter le serveur et quitter">⏻ Quitter</button>
  </header>
  <div class="searchbar" id="searchbar">
    <input type="text" id="search-input" placeholder="Rechercher" />
    <input type="text" id="replace-input" placeholder="Remplacer par" />
    <label class="case"><input type="checkbox" id="search-case" /> Aa (casse)</label>
    <span class="count" id="search-count"></span>
    <button id="search-prev" title="Précédent (Maj+Entrée)">▲</button>
    <button id="search-next" title="Suivant (Entrée)">▼</button>
    <button id="search-replace">Remplacer</button>
    <button id="search-replaceall">Tout remplacer</button>
    <span class="spacer"></span>
    <button id="search-close" title="Fermer (Échap)">✕</button>
  </div>
  <main>
    <section class="pane editor">
      <h2>Édition</h2>
      <textarea id="editor" placeholder="# Écrivez votre Markdown ici..." spellcheck="false"></textarea>
    </section>
    <section class="pane">
      <h2>Prévisualisation</h2>
      <div class="preview" id="preview"></div>
    </section>
  </main>

  <div class="overlay" id="prefs-overlay">
    <div class="dialog">
      <h3>⚙ Préférences</h3>
      <div class="field">
        <label for="pref-theme">Thème</label>
        <select id="pref-theme">
          <option value="light">Clair</option>
          <option value="dark">Sombre</option>
        </select>
      </div>
      <div class="field">
        <label for="pref-dir">Dossier par défaut (ouverture / enregistrement)</label>
        <input type="text" id="pref-dir" placeholder="/home/vous/Documents" />
      </div>
      <div class="field row">
        <input type="checkbox" id="pref-autopreview" />
        <label for="pref-autopreview">Prévisualisation automatique pendant la saisie</label>
      </div>
      <div class="field row">
        <input type="checkbox" id="pref-autosave" />
        <label for="pref-autosave">Enregistrement automatique (fichiers déjà nommés uniquement)</label>
      </div>
      <div class="actions">
        <button id="pref-cancel">Annuler</button>
        <button id="pref-save" class="primary">Enregistrer</button>
      </div>
    </div>
  </div>

  <script>
    const ed = document.getElementById('editor');
    const preview = document.getElementById('preview');
    const statusEl = document.getElementById('status');
    let currentPath = null;
    let savedContent = '';
    let autoPreview = true;
    let autoSave = false;
    let defaultDir = '';

    function counts() {
      const text = ed.value;
      const words = (text.trim().match(/\S+/g) || []).length;
      const chars = text.length;
      return words + ' mot(s) · ' + chars + ' caractère(s)';
    }
    let autoSaveNote = '';
    function refreshStatus() {
      const name = currentPath ? currentPath.split('/').pop() : '(sans titre)';
      const modified = ed.value !== savedContent;
      const modif = modified ? ' <span class="modif">● modifié</span>' : (' · enregistré' + autoSaveNote);
      statusEl.innerHTML = name + ' — ' + counts() + modif;
    }

    // --- Autosauvegarde : seulement si activée ET document déjà nommé ---
    let autoSaveTimer = null;
    function scheduleAutoSave() {
      if (!autoSave || !currentPath) return;
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
      autoSaveTimer = setTimeout(doAutoSave, 2000);
    }
    async function doAutoSave() {
      if (!autoSave || !currentPath || ed.value === savedContent) return;
      const ok = await saveTo(currentPath);
      if (ok) {
        const now = new Date();
        const hh = String(now.getHours()).padStart(2, '0');
        const mm = String(now.getMinutes()).padStart(2, '0');
        autoSaveNote = ' · 💾 auto ' + hh + ':' + mm;
        refreshStatus();
      }
    }

    let previewTimer = null;
    async function doPreview() {
      try {
        const r = await fetch('/api/preview', { method:'POST', body: ed.value });
        preview.innerHTML = await r.text();
      } catch (e) { preview.textContent = 'Erreur de prévisualisation : ' + e; }
    }
    function schedulePreview() {
      if (previewTimer) clearTimeout(previewTimer);
      previewTimer = setTimeout(doPreview, 200);
    }

    ed.addEventListener('input', () => { autoSaveNote = ''; if (autoPreview) schedulePreview(); scheduleAutoSave(); refreshStatus(); });

    // --- Insertion de syntaxe autour de la sélection ---
    function wrap(before, after, placeholder) {
      const s = ed.selectionStart, e = ed.selectionEnd;
      const sel = ed.value.slice(s, e) || placeholder;
      ed.value = ed.value.slice(0, s) + before + sel + after + ed.value.slice(e);
      ed.focus();
      ed.selectionStart = s + before.length;
      ed.selectionEnd = s + before.length + sel.length;
      schedulePreview(); refreshStatus();
    }
    function prefixLine(prefix) {
      const s = ed.selectionStart;
      const lineStart = ed.value.lastIndexOf('\n', s - 1) + 1;
      ed.value = ed.value.slice(0, lineStart) + prefix + ed.value.slice(lineStart);
      ed.focus(); ed.selectionStart = ed.selectionEnd = s + prefix.length;
      schedulePreview(); refreshStatus();
    }
    const actions = {
      h1: () => prefixLine('# '), h2: () => prefixLine('## '),
      bold: () => wrap('**','**','gras'), italic: () => wrap('*','*','italique'),
      code: () => wrap('`','`','code'), ul: () => prefixLine('- '),
      ol: () => prefixLine('1. '), quote: () => prefixLine('> '),
      link: () => wrap('[','](https://)','texte'),
      image: () => wrap('![','](image.png)','alt'),
    };
    document.querySelectorAll('[data-md]').forEach(b =>
      b.addEventListener('click', () => actions[b.dataset.md]()));

    // --- Fichiers ---
    document.getElementById('btn-new').onclick = () => {
      if (ed.value !== savedContent && !confirm('Abandonner les modifications non enregistrées ?')) return;
      ed.value = ''; currentPath = null; savedContent = ''; doPreview(); refreshStatus();
    };
    async function openPath(path) {
      const r = await fetch('/api/open?path=' + encodeURIComponent(path));
      if (!r.ok) { alert(await r.text()); return; }
      ed.value = await r.text(); currentPath = path; savedContent = ed.value;
      doPreview(); refreshStatus();
    }
    document.getElementById('btn-open').onclick = () => {
      const path = prompt('Chemin du fichier .md à ouvrir :', currentPath || withDir(''));
      if (path) openPath(path);
    };

    // --- Fichiers récents ---
    const recentsMenu = document.getElementById('recents-menu');
    async function fetchRecents() {
      try {
        const r = await fetch('/api/recents');
        if (!r.ok) return [];
        return (await r.text()).split('\n').map(s => s.trim()).filter(Boolean);
      } catch (e) { return []; }
    }
    async function openRecentsMenu() {
      const list = await fetchRecents();
      recentsMenu.innerHTML = '';
      if (list.length === 0) {
        const d = document.createElement('div');
        d.className = 'empty'; d.textContent = 'Aucun fichier récent';
        recentsMenu.appendChild(d);
      } else {
        list.forEach(p => {
          const it = document.createElement('div');
          it.className = 'item'; it.title = p;
          const base = p.split('/').pop();
          const dir = p.slice(0, p.length - base.length);
          it.innerHTML = '';
          it.appendChild(document.createTextNode(base));
          if (dir) { const s = document.createElement('span'); s.className = 'dir'; s.textContent = '  ' + dir; it.appendChild(s); }
          it.onclick = () => { recentsMenu.classList.remove('open'); openPath(p); };
          recentsMenu.appendChild(it);
        });
        const f = document.createElement('div');
        f.className = 'footer';
        const b = document.createElement('button');
        b.textContent = '🗑 Vider la liste';
        b.onclick = async (e) => {
          e.stopPropagation();
          try { await fetch('/api/recents/clear', { method:'POST' }); } catch (err) {}
          recentsMenu.classList.remove('open');
        };
        f.appendChild(b); recentsMenu.appendChild(f);
      }
      recentsMenu.classList.add('open');
    }
    document.getElementById('btn-recents').onclick = (e) => {
      e.stopPropagation();
      if (recentsMenu.classList.contains('open')) recentsMenu.classList.remove('open');
      else openRecentsMenu();
    };
    document.addEventListener('click', () => recentsMenu.classList.remove('open'));
    async function saveTo(path) {
      const r = await fetch('/api/save?path=' + encodeURIComponent(path), { method:'POST', body: ed.value });
      if (!r.ok) { alert(await r.text()); return false; }
      currentPath = path; savedContent = ed.value; refreshStatus(); return true;
    }
    document.getElementById('btn-save').onclick = () => {
      if (currentPath) saveTo(currentPath);
      else { const p = prompt('Enregistrer sous (chemin .md) :', withDir('document.md')); if (p) saveTo(p); }
    };
    document.getElementById('btn-saveas').onclick = () => {
      const p = prompt('Enregistrer sous (chemin .md) :', currentPath || withDir('document.md')); if (p) saveTo(p);
    };
    document.getElementById('btn-export').onclick = async () => {
      const def = (currentPath ? currentPath.replace(/\.md$/, '') : withDir('document')) + '.html';
      const path = prompt('Exporter en HTML vers :', def);
      if (!path) return;
      const r = await fetch('/api/export?path=' + encodeURIComponent(path), { method:'POST', body: ed.value });
      alert(r.ok ? 'Export réussi : ' + path : await r.text());
    };
    // Export PDF via l'impression du navigateur (« Enregistrer en PDF »).
    document.getElementById('btn-pdf').onclick = async () => {
      const title = currentPath ? currentPath.split('/').pop().replace(/\.md$/, '') : 'document';
      let html;
      try {
        const r = await fetch('/api/render-page?title=' + encodeURIComponent(title), { method:'POST', body: ed.value });
        if (!r.ok) { alert(await r.text()); return; }
        html = await r.text();
      } catch (e) { alert('Erreur de génération : ' + e); return; }
      const w = window.open('', '_blank');
      if (!w) { alert('Autorisez les fenêtres pop-up pour exporter en PDF, puis réessayez.'); return; }
      w.document.open(); w.document.write(html); w.document.close();
      let printed = false;
      const go = () => { if (printed) return; printed = true; w.focus(); w.print(); };
      w.onload = go;
      setTimeout(go, 1500); // repli si l'événement onload ne se déclenche pas
    };

    document.getElementById('btn-theme').onclick = () => document.body.classList.toggle('dark');

    // --- Préférences / configuration persistante ---
    document.getElementById('btn-preview').onclick = doPreview;
    function withDir(name) { return defaultDir ? (defaultDir.replace(/\/?$/, '/') + name) : name; }

    const isFalse = (v) => v === 'false' || v === '0' || v === 'non' || v === 'no';
    function parseConfig(text) {
      const cfg = { theme:'light', default_dir:'', auto_preview:true, auto_save:false };
      text.split('\n').forEach(line => {
        line = line.trim(); if (!line || line[0] === '#') return;
        const i = line.indexOf('='); if (i < 0) return;
        const k = line.slice(0, i).trim(), v = line.slice(i + 1).trim();
        if (k === 'theme') cfg.theme = v;
        else if (k === 'default_dir') cfg.default_dir = v;
        else if (k === 'auto_preview') cfg.auto_preview = !isFalse(v);
        else if (k === 'auto_save') cfg.auto_save = !isFalse(v) && v !== '';
      });
      return cfg;
    }
    function applyConfig(cfg) {
      document.body.classList.toggle('dark', cfg.theme === 'dark');
      defaultDir = (cfg.default_dir && cfg.default_dir !== '.') ? cfg.default_dir : '';
      autoPreview = cfg.auto_preview !== false;
      autoSave = cfg.auto_save === true;
      document.getElementById('btn-preview').style.display = autoPreview ? 'none' : '';
    }
    function fillPrefForm(cfg) {
      document.getElementById('pref-theme').value = cfg.theme === 'dark' ? 'dark' : 'light';
      document.getElementById('pref-dir').value = (cfg.default_dir && cfg.default_dir !== '.') ? cfg.default_dir : '';
      document.getElementById('pref-autopreview').checked = cfg.auto_preview !== false;
      document.getElementById('pref-autosave').checked = cfg.auto_save === true;
    }
    const overlay = document.getElementById('prefs-overlay');
    let lastConfig = { theme:'light', default_dir:'', auto_preview:true };
    async function loadConfig() {
      try {
        const r = await fetch('/api/config');
        if (r.ok) { lastConfig = parseConfig(await r.text()); applyConfig(lastConfig); fillPrefForm(lastConfig); }
      } catch (e) { /* config indisponible : on garde les valeurs par défaut */ }
    }
    document.getElementById('btn-prefs').onclick = () => { fillPrefForm(lastConfig); overlay.classList.add('open'); };
    document.getElementById('pref-cancel').onclick = () => overlay.classList.remove('open');
    overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('open'); });
    document.getElementById('pref-save').onclick = async () => {
      const theme = document.getElementById('pref-theme').value;
      const dir = document.getElementById('pref-dir').value.trim();
      const ap = document.getElementById('pref-autopreview').checked;
      const as = document.getElementById('pref-autosave').checked;
      const body = 'theme=' + theme + '\ndefault_dir=' + (dir || '.')
                 + '\nauto_preview=' + ap + '\nauto_save=' + as + '\n';
      try {
        const r = await fetch('/api/config', { method:'POST', body });
        if (!r.ok) { alert('Échec de l\'enregistrement : ' + await r.text()); return; }
      } catch (e) { alert('Échec de l\'enregistrement : ' + e); return; }
      lastConfig = { theme, default_dir: dir, auto_preview: ap, auto_save: as };
      applyConfig(lastConfig);
      if (autoPreview) doPreview();
      overlay.classList.remove('open');
    };

    // --- Recherche / remplacement ---
    const searchbar = document.getElementById('searchbar');
    const searchInput = document.getElementById('search-input');
    const replaceInput = document.getElementById('replace-input');
    const caseChk = document.getElementById('search-case');
    const countEl = document.getElementById('search-count');
    let matches = [], matchIndex = 0;

    // Recherche des positions côté JS : indices UTF-16, cohérents avec la
    // sélection de la zone d'édition (correct pour le texte accentué).
    function jsFind(text, pat, cs) {
      const res = [];
      if (!pat) return res;
      const h = cs ? text : text.toLowerCase();
      const p = cs ? pat : pat.toLowerCase();
      let i = 0;
      for (;;) { const idx = h.indexOf(p, i); if (idx < 0) break; res.push(idx); i = idx + p.length; }
      return res;
    }
    function updateCount() {
      countEl.textContent = matches.length ? ((matchIndex + 1) + ' / ' + matches.length) : 'Aucun résultat';
    }
    function highlight() {
      if (!matches.length) return;
      const pos = matches[matchIndex], len = searchInput.value.length;
      ed.setSelectionRange(pos, pos + len);
      const line = ed.value.slice(0, pos).split('\n').length - 1;
      ed.scrollTop = Math.max(0, line * 22 - ed.clientHeight / 2);
    }
    function runSearch() {
      matches = jsFind(ed.value, searchInput.value, caseChk.checked);
      if (matchIndex >= matches.length) matchIndex = 0;
      updateCount();
      if (matches.length) highlight();
    }
    function nextMatch(d) {
      if (!matches.length) return;
      matchIndex = (matchIndex + d + matches.length) % matches.length;
      updateCount(); highlight();
    }
    function openSearch() {
      searchbar.classList.add('open');
      searchInput.focus(); searchInput.select();
      if (searchInput.value) runSearch();
    }
    function closeSearch() { searchbar.classList.remove('open'); ed.focus(); }

    searchInput.addEventListener('input', () => { matchIndex = 0; runSearch(); });
    caseChk.addEventListener('change', () => { matchIndex = 0; runSearch(); });
    document.getElementById('search-next').onclick = () => nextMatch(1);
    document.getElementById('search-prev').onclick = () => nextMatch(-1);
    document.getElementById('search-close').onclick = closeSearch;
    document.getElementById('btn-search').onclick = openSearch;
    searchInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); nextMatch(e.shiftKey ? -1 : 1); }
      else if (e.key === 'Escape') closeSearch();
    });
    replaceInput.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeSearch(); });

    document.getElementById('search-replace').onclick = () => {
      if (!matches.length) return;
      const pos = matches[matchIndex], len = searchInput.value.length;
      ed.value = ed.value.slice(0, pos) + replaceInput.value + ed.value.slice(pos + len);
      if (autoPreview) schedulePreview();
      refreshStatus(); runSearch();
    };
    // Remplacer tout : délégué au moteur OCaml (route /api/replace).
    document.getElementById('search-replaceall').onclick = async () => {
      const pat = searchInput.value;
      if (!pat) return;
      const q = '?pattern=' + encodeURIComponent(pat)
              + '&replacement=' + encodeURIComponent(replaceInput.value)
              + '&case=' + caseChk.checked;
      try {
        const r = await fetch('/api/replace' + q, { method:'POST', body: ed.value });
        if (!r.ok) { alert(await r.text()); return; }
        const n = r.headers.get('X-Replacements') || '0';
        ed.value = await r.text();
        if (autoPreview) schedulePreview();
        refreshStatus(); matchIndex = 0; runSearch();
        countEl.textContent = n + ' remplacement(s)';
      } catch (e) { alert('Échec du remplacement : ' + e); }
    };
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'f') { e.preventDefault(); openSearch(); }
    });

    // --- Quitter : arrête le serveur côté OCaml puis ferme l'application ---
    let quitting = false;
    document.getElementById('btn-quit').onclick = async () => {
      if (ed.value !== savedContent &&
          !confirm('Des modifications ne sont pas enregistrées. Quitter et arrêter le serveur ?')) return;
      quitting = true;
      try { await fetch('/api/quit', { method:'POST' }); } catch (e) { /* le serveur peut couper la connexion */ }
      document.title = 'Arrêté';
      document.body.innerHTML =
        '<div style="padding:2rem;font-family:system-ui,-apple-system,sans-serif">' +
        '<h2>Serveur arrêté</h2><p>L\'application est fermée. Vous pouvez fermer cet onglet.</p></div>';
    };

    // Avertissement avant fermeture si modifications non enregistrées
    // (désactivé lors d'un arrêt volontaire via le bouton Quitter).
    window.addEventListener('beforeunload', (e) => {
      if (!quitting && ed.value !== savedContent) { e.preventDefault(); e.returnValue = ''; }
    });

    refreshStatus(); doPreview(); loadConfig();
  </script>
</body>
</html>
|page}

(* --- Démarrage ----------------------------------------------------- *)

let () =
  let port = try int_of_string (Sys.getenv "PORT") with _ -> 8080 in
  Dream.run ~interface:"127.0.0.1" ~port ~stop
  @@ Dream.logger
  @@ Dream.router
       [ Dream.get "/" (fun _ -> Dream.html page);
         Dream.post "/api/preview" preview_handler;
         Dream.get "/api/open" open_handler;
         Dream.post "/api/save" save_handler;
         Dream.post "/api/export" export_handler;
         Dream.get "/api/config" config_get_handler;
         Dream.post "/api/config" config_post_handler;
         Dream.get "/api/recents" recents_get_handler;
         Dream.post "/api/recents/clear" recents_clear_handler;
         Dream.post "/api/replace" replace_handler;
         Dream.post "/api/render-page" render_page_handler;
         Dream.post "/api/quit" quit_handler ]
