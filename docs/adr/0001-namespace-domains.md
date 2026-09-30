# ADR 0001 — Domain-Präfixe für flache Library-Namen

- **Status:** accepted (2026-09-29)
- **Kontext:** MojoAkku hat 244 Katalog-Einträge (4 ausgeliefert: `bit`, `io`,
  `base64`, `string`). Alle sind flache Siblings unter `mojoakku/`. Mit 244
  Namen kollidiert die flache Liste mit der Lesbarkeit (z. B. `hash` vs `digest`,
  `time` vs `datetime`, `format`).

## Entscheidung

1. **Das Repo bleibt flach.** Kein Verzeichnisbaum — die `task test`/`ci`-Discovery
   globbt `mojoakku/*/`, und AGENTS.md verbietet nur *strukturelle Nesting*.
2. **Namen bekommen ein Domain-Präfix**, getrennt mit `_` (niemals `-`, das
   erzwingt Backticks im Import): `crypto_tls` statt `tls`.
3. **Tiefe: 2 Segmente bevorzugt, max 3.** Kein Füllwort in der Mitte
   (`func`, `misc`, `general`) — `phy_cosmology` nicht `math_func_cosmology`.
4. **`math_` ist die Ausnahme:** expansiv erlaubt (`math_number`, `math_algebra`,
   `math_linear`, `math_geometry`, `math_special_*`, `math_logic`).
5. **Der übliche Namespace ist der Themename selbst** (scipy: `special`,
   `constants`, `stats`; astropy: `cosmology`, `units`) — belegt in
   `docs/architecture/research/`.

## Neue Konventionen

- **`mojoNeeds:`** — Pflichtfeld in `.repo/todo/<id>.yml`: Liste von
  Capability-Schlüsseln aus `mojo.yml`.
- **`mojo.yml`** — Capability-Ledger: was Mojo 1.1.0 kann (`have`), teilweise
  kann (`partial`) oder nicht kann (`missing`), je mit Quelle.
- **Ableitungsregel:** `task todo` zeigt eine Lib nur, wenn alle `mojoNeeds`
  `have` sind **und** alle `libdeps` `done`.
- **`covered_<x>`** — Lib ist durch std/MAX abgedeckt, wird *nicht* gebaut
  (`covered_simd`, `covered_tensor`, `covered_ml`, `covered_soa`,
  `covered_broadcast`).
- **`homeless_<x>`** — noch kein Zuhause, kommt bald (`homeless_pdf`,
  `homeless_game`).

## Domains (Stand der Entscheidung)

Text/Struktur: `text_` `markup_` `document_` `format_` `codec_`
Daten: `data_`→`format_`/`db_`/`archive_`/`serialize_`
Zahlen: `math_` (expansiv) · `stat_` · `algo_`
Natur/Anwendung: `phy_` `chem_` `bio_` `econ_` `units_`
Krypto/Security: `crypto_` `security_`
Netz: `net_` (raw) `proto_` (Protokolle) `web_` (Browser-nah)
System: `os_` `fs_` `io_` `cli_` `sync_` `async_` `dist_` `time_` `build_`
Sprache: `lang_` `meta_` `coll_` `mem_` `prim_` `code_` `dev_`
Medien/UI: `media_` `ui_` · `app_frame` `app_native` `app_webview`

## Konsequenzen

- **Ein Umbenennungs-Zug für alle 244** (inkl. der 4 Code-Libs + `BREAKING`).
- `gpu_` wird **nicht** angelegt (MAX deckt Compute; Rendering geht in `app_*`).
- **Nordstern:** eine App komplett in Mojo — „Tauri/Wails für Mojo" — via
  **MojoAkku-CLI** (Host-Skelett + Mojo-`cdylib` + Assets→`comptime`), gestützt
  auf `c-ffi`.

## Quellen

- `docs/architecture/namespace-model.md` (konsolidiertes Modell)
- `docs/architecture/final-domains.md` (Domain → Präfix + Mitglieder)
- `docs/architecture/rename-map.txt` (alt → neu, alle 244)
- `mojo.yml` (Capability-Ledger)
- `docs/architecture/research/render-rust.md`, `render-odin-zig.md`,
  `render-webview.md`
- Buch `mojov1`: `interop/calling-c`, `concurrency/gpu-and-accelerators`,
  `concurrency/async-and-parallelism`, `project/structure`
- User-Freigaben 2026-09-29 (Runde 1 + 2)
