# Namespace-Modell für MojoAkku — Vorschlag v2

Status: **Vorschlag zur Freigabe** (noch nichts umbenannt, nichts committet)
Autor: super/Manager · Datum: 2026-09-28
Datenbasis: `task all` auf `main` @ `9a013b5` — **244 Libraries** (4 `done`, 240 `todo`)

---

## 0. Was sich gegenüber v1 geändert hat

| v1 | v2 |
|---|---|
| 14 Domains, `core_` mit **63** = Giga-Topf | **33 Domains**, größte `data_` und `lang_` mit **21** |
| `misc_`-Sammelbecken | **gestrichen** — alles sauber zugeordnet |
| 1 Präfix-Segment | **2 bevorzugt, max 3** (`units_distance`, `physics_cosmology`) |
| keine `units_`/`physics_`/`math_special` | **neu**: `units_` (Maßeinheiten), `physics_` (Fachrechnungen), `math_special` |
| `functions_` (mit Füllwort) | **verworfen** — `func` sagt nichts; `physics_*` + `math_special` ersetzen es |
| `ast` in `core_` | `ast` → **`code_`** (Dev-/Code-Verarbeitungs-Kontext) |
| `core_algorithm` unklar | `algorithm` → **`coll_algorithm`** (Container-/Algorithmen-Sammlung) |

## 1. Entscheidung in einem Satz

**Das Repo bleibt flach**, aber die Namen bekommen eine **Domain-Präfix**. Mehr,
kleinere Sammlungen statt weniger großer — Organisation vor Kürze.

## 2. Regeln (hart)

1. **Trenner ist immer `_` (Unterstrich), niemals `-`** (Backtick-Zwang im Import).
2. **2 Segmente bevorzugt** (`crypto_tls`), **maximal 3** (`math_special_bessel`).
3. **Keine Füllwörter in der Mitte** — `func`, `misc`, `general`, `utilities`
   sind verboten (`physics_cosmology` sagt mehr als `math_func_cosmology`).
4. **Domains sind ein geschlossener Satz** (33, §4). Kein Freitext-Präfix.
5. Das Präfix ist **Teil des Verzeichnis- und Paketnamens** → `akku/crypto_tls/`.
6. Der **`name:`-Wert** in `_todos/<id>.yml` bleibt der Anzeigename (z. B. „TLS").
7. **Kein Sammelbecken.** Eine Lib, die in keine Domain passt, ist ein Signal, eine
   neue Domain zu eröffnen — nicht, sie irgendwo unterzuschieben.

## 3. Warum flach statt Verzeichnisbaum (unverändert)

| Frage | Fakt | Quelle |
|---|---|---|
| Bindestriche? | Nein — Paketname = Verzeichnisname, ungültige Identifiererzwingen Backticks | `mojov1/project/structure` |
| Bricht Präfix die Regeln? | Nein, verboten ist nur *strukturelle Nesting* | `AGENTS.md` |
| Präfix kostet Tooling? | Nein — `task test`/`ci` globben `akku/*/` | `Taskfile.yml`, Tasks `test` und `ci` |
| Verzeichnisbaum kostet Tooling? | Ja — Discovery, `__init__`-Ebenen, Branch-Modell | `Taskfile.yml:343`, `LibraryLayout.md` |
| User betroffen? | Nein — nichts verpackt/veröffentlicht | User-Angabe 2026-09-28 |

## 4. Die 33 Domains — und was jede hat

Summe **244** (+ die neuen `units_*`/`physics_*` in §6). Jede Zeile: das Präfix
(die Sammlung) und darunter „das hat:" mit den enthaltenen Libraries **ohne
Präfix** (das Präfix steht schon davor).

**`lang_`** (21) — das hat:
error, trait, typeclass, functor, enum, variant, option, pattern, closure, context, contextmanager, dataclass, propertywrapper, keypath, defer, drop, tie, immutable, contract, lazy, logic

**`data_`** (21) — das hat:
json, csv, toml, yaml, ini, zon, binary, serialization, compression, archive, base64, config, spec, table, cache, database, kvstore, orm, sql, redis, uuid

**`meta_`** (16) — das hat:
comptime, macro, metadata, metatable, reflection, dispatch, overload, quotation, annotation, typing, varargs, delegation, singleton, observation, observer, embed

**`dev_`** (14) — das hat:
logging, tracing, profiling, benchmark, debug, testing, mock, metric, instrument, doc, ffi, hotload, sandbox, script

**`net_`** (13) — das hat:
socket, tcp, udp, ip, nic, packet, multicast, unixsocket, dns, ftp, mail, proxy, rpc

**`os_`** (11) — das hat:
core, process, env, signal, user, daemon, session, shell, management, notification, clipboard

**`build_`** (11) — das hat:
core, package, module, target, versioning, migration, artifact, autoload, plugin, lockfile, virtualenv

**`web_`** (10) — das hat:
http, http2, http3, websocket, sse, quic, url, uri, mime, cookie

**`text_`** (10) — das hat:
string, encoding, unicode, regex, format, diff, search, pretty, textedit, i18n

**`mem_`** (10) — das hat:
core, ownership, allocator, layout, align, pin, refcount, weak, weakref, safety

**`coll_`** (10) — das hat:
core, tuple, ranges, set, iter, algorithm, bisect, zipper, transducer, handlemap

**`math_`** (9 + 1 neu) — das hat:
core, numerics, complex, decimal, rational, bigint, factor, currency, random (+ neu: special — Bessel, Gamma, erf, Legendre, Orthogonalpolynome; scipys Begriff)

**`sync_`** (8) — das hat:
core, atomic, thread, channel, queue, pool, cell, stm

**`fs_`** (7) — das hat:
core, file, path, glob, tempfile, watch, mmap

**`crypto_`** (7) — das hat:
hash, digest, cipher, mac, publickey, certificate, noise

**`security_`** (6) — das hat:
tls, keyring, jwt, oauth, password, auth

**`media_`** (6) — das hat:
image, audio, pdf, font, color, game

**`markup_`** (6) — das hat:
html, markdown, xml, template, richtext, pod

**`dist_`** (6) — das hat:
actor, cluster, supervisor, broker, parallel, isolate

**`code_`** (6) — das hat:
ast, parser, interpreter, codegen, objectfile, lint

**`async_`** (6) — das hat:
core, future, coroutine, eventloop, scheduler, flow

**`ui_`** (5) — das hat:
gui, tui, chart, easing, input

**`gpu_`** (5) — das hat:
core, simd, broadcast, soa, ml

**`linear_`** (4) — das hat:
matrix, tensor, geometry, graph

**`time_`** (3 + 1 neu) — das hat:
clock, datetime, zone (+ neu: duration)

**`stat_`** (3) — das hat:
statistics, formula, dataframe

**`prim_`** (3) — das hat:
bit, endian, limits

**`cli_`** (3) — das hat:
core, terminal, console

**`io_`** (2) — das hat:
core, stream

**`units_`** (1 + neu) — das hat:
core (+ neu: distance, mass, time, temperature, electricity, energy, pressure, speed)

**`geo_`** (1) — das hat:
core

**`physics_`** *(neu)* — das hat:
mechanics, relativity, cosmology, quantum, thermo, chemistry, **finance** *(Domäne „Fachrechnungen"; Topik statt Füllwort — siehe §6)*

**`chem_`** — offen: `chemistry` kann hier statt unter `physics_` liegen (siehe offene Frage 9).

> `core` steht jeweils für die Haupt-Lib der Domain (`os_core`, `mem_core`, …).
> Größte Domain nach dem Umbau: **21** (war 63). Kein Sammelbecken mehr.
> Die wenigen Umbenennungen der lokalen Namen (`time`→`clock`, `timezone`→`zone`,
> `math`/`os`/`fs`/`io`/`sync`/`mem`→`core`, `unit`→`units_core`) stehen in §5.

### Warum `physics_` und nicht `functions_physik_...`

Der übliche Namespace ist **der Themennamen selbst**, nicht ein Füllwort. Belegt:
`scipy.special`, `scipy.constants`, `scipy.stats`, `scipy.linalg` und
`astropy.cosmology`, `astropy.units`, `astropy.constants` — alle **einstufig,
Themename, kein `math_`/`func_`-Präfix**.

Deshalb:
- **`functions_` ist gestrichen** — `func` ist ein Füllwort und macht Namen
  verwechselbar (`math_func_cosmology` sagt nicht mehr als `physics_cosmology`).
- **`physics_`** ist die Domäne, die Fachthemen bündelt: `physics_cosmology`
  (wie `astropy.cosmology`: Rotverschiebung, Hubble, `comoving_distance`),
  `physics_relativity` (Einstein-Gleichungen, Metriken),
  `physics_mechanics`, `physics_quantum`, `physics_thermo`.
- **`math_special`** ist der scipy-Name für die große Funktionssammlung
  (Bessel, Gamma, erf, Legendre) — genau die „coole Mathe"-Sammlung.
- **Regel:** 2 Segmente = `domäne_thema`; **kein Füllwort in der Mitte**
  (`func`, `misc`, `general`, `utilities`).


## 5. Dein `time`-Beispiel (die Aufteilung)

| jetzt | neu | was |
|---|---|---|
| `time` | `time_clock` | monotone/Wall-Clock, Unix-Zeit → **Computer-Zeit** |
| `datetime` | `time_datetime` | Kalenderwert, RFC rein/raus, Formatierung |
| `timezone` | `time_zone` | tz-Datenbank |
| *(neu)* | `time_duration` | Dauer, Arithmetik |

Weitere Trennungen, die sofort klar werden:

| jetzt | neu | warum |
|---|---|---|
| `hash` | `crypto_hash` | **nicht-krypto** (FNV/xxHash) |
| `digest` | `crypto_digest` | **krypto** (SHA/BLAKE) |
| `tls` | `security_tls` | TLS ist Security-Schicht, nicht roher Socket |
| `layout` | `mem_layout` | **Memory-Layout** (nicht UI!) |
| `ast` | `code_ast` | Code-Verarbeitung (dein Punkt) |

### Lokale Namen, die sich ändern (nicht nur Präfix)

Bei den meisten Libs kommt nur das Domain-Präfix davor (`socket` → `net_socket`).
Diese lokalen Namen ändern sich zusätzlich:

| jetzt | neu | Domain |
|---|---|---|
| `time` | `time_clock` | time_ |
| `timezone` | `time_zone` | time_ |
| `math` | `math_core` | math_ |
| `os` | `os_core` | os_ |
| `fs` | `fs_core` | fs_ |
| `io` | `io_core` | io_ |
| `sync` | `sync_core` | sync_ |
| `memory` | `mem_core` | mem_ |
| `collections` | `coll_core` | coll_ |
| `cli` | `cli_core` | cli_ |
| `gpu` | `gpu_core` | gpu_ |
| `async` | `async_core` | async_ |
| `build` | `build_core` | build_ |
| `geo` | `geo_core` | geo_ |
| `unit` | `units_core` | units_ |

Alle übrigen 229 Libs behalten ihren lokalen Namen und bekommen nur das Präfix.

## 6. Neue Libraries (Domains `units_`, `physics_`, `math_special`)

Diese Libs existieren **noch nicht** und kämen als neue Katalog-Einträge dazu.
Domain-Präfix als *collection*, kein Füllwort (`func`/`misc`) und kein `core_units`.

### `units_` — Maßeinheiten (dein Vorschlag)

| neu | Inhalt (Beispiel) |
|---|---|
| `units_core` | Basistypen, Umrechnung, Dimensionen (ex `unit`) |
| `units_distance` | kilometer, meter, centimeter, feet, inches, mile |
| `units_mass` | kilogram, gram, pound, ounce, tonne |
| `units_time` | nanosecond, millisecond, second, minute, hour, day, year, decade |
| `units_temperature` | celsius, fahrenheit, kelvin |
| `units_electricity` | ampere, volt, ohm, watt, coulomb |
| `units_energy` | joule, calorie, kilowatt-hour, electronvolt |
| `units_pressure` | pascal, bar, psi, atmosphere |
| `units_speed` | meter-per-second, km/h, knot, mph |

Ziel-Anwendung (dein Beispiel): `var speed = distance / time` mit echten
Einheiten und Dimensionsprüfung. `units_core` trägt das Typsystem, die
`units_*`-Libs liefern die konkreten Einheiten. Vorbild: `astropy.units`,
`scipy.constants`.

### `physics_` — Fachrechnungen (dein Vorschlag, topical)

| neu | Inhalt |
|---|---|
| `physics_mechanics` | Kinematik, Kraft, Energie, Impuls |
| `physics_relativity` | Einstein-Gleichungen, Metriken, Lorentz |
| `physics_cosmology` | Rotverschiebung, Hubble, `comoving_distance` (wie `astropy.cosmology`) |
| `physics_quantum` | Schrödinger, Zustände, Operatoren |
| `physics_thermo` | Wärme, Entropie, Zustandsgleichungen |
| `physics_chemistry` | Mol, Konzentration, Gasgesetze (oder eigene `chem_`-Domain) |
| `physics_finance` | Zins, Barwert, Annuität |

> Die Liste ist **offen/erweiterbar** — jede neue Fachsammlung ist eine neue
> `physics_*`-Lib. Kein `functions_`-Präfix: `physics_cosmology` ist der übliche
> Themen-Namespace (wie `astropy.cosmology`), `math_func_cosmology` wäre ein
> Füllwort-Name.

### `math_special` — die große Funktionssammlung

| neu | Inhalt |
|---|---|
| `math_special` | Bessel, Gamma, Beta, erf/Fresnel, Legendre, Orthogonalpolynome — der scipy-Begriff (`scipy.special`) |

> Bewusst **eine** gut organisierte Lib statt vieler kleiner: scipy hält die
> gesamte Sammlung unter `special`. Falls sie zu groß wird, kann sie später in
> `math_special_bessel` / `math_special_gamma` / … geteilt werden.

**Katalog-Wachstum:** 244 → **318** (244 Bestand + **74 neue** Libs, angelegt).
Die vollständige, angelegte Liste steht in `docs/architecture/new-libraries.txt`
und unten in §7.

## 7. Angelegte neue Libraries (74)

Alle beschlossenen neuen Libs sind als `_todos/<id>.yml` angelegt (`status: todo`):
`units_*` (8) · `phy_*` (5) · `chem_*` (4) · `bio_*` (4) · `econ_*` (3) ·
`math_special_*` (4) · `app_*` (3) · `crypto_*` (6) · `security_*` (5) ·
`proto_*` (9) · `archive_*` (5) · `serialize_*` (4) · `codec_*` (3) ·
`document_*` (4) · `algo_*` (5) · `fs_find` · `time_duration`.

Gesamtzahl Katalog: **318**. Davon 4 `done`, 6 `covered_*`, 2 `homeless_*`.

## 8. Kosten & Ablauf (wenn freigegeben)

**Pro bestehender Library mechanisch:**
1. `_todos/<alt>.yml` → `_todos/<neu>.yml`.
2. `akku/<alt>/` → `akku/<neu>/` (nur bei den 4 `done`-Libs).
3. `_tests/*.mojo`: die `from <alt> import …`-Zeile (1 Zeile pro Datei).
4. Docs-Header, Branch-Name `<neu>-library`.

**Repo-weit, einmalig:**
5. `AGENTS.md`, `.agents/workflows/LibraryLayout.md`, Phasen-Workflows:
   Namensregel + die 33er-Domain-Tabelle.
6. `.changes/new/…` mit `BREAKING:`-Zeile.
7. ADR als dauerhafte Begründung.

**Neue Libs** (`units_*`, `physics_*`, `math_special`, `time_duration`)
durchlaufen die volle Phase-1–13-Pipeline — als eigene Vorhaben, nicht Teil des
Umbaus.

## 9. Konsolidierte Entscheidungen (Runde 1 + 2 + Research)

Status: **alles „passt"**, nur wenige Punkte bewusst als **unsicher/Research**
markiert. Nichts umbenannt, nichts committet.

### 8.1 Neue/geänderte Domains

| Domain | Änderung | Beleg/Quelle |
|---|---|---|
| `format_` | **neu** — Datenformate (json, csv, toml, yaml, ini, zon, config, spec) | Runde 1 |
| `db_` | **neu** — Datenbanken (database, sql, orm, redis, kvstore, table, cache) | Runde 1 |
| `archive_` | **neu** — Kompression/Archive (archive, compression, + zip/tar/gzip/zstd/7z) | Runde 1 |
| `serialize_` | **neu** — Schema-/Transport-Serialisierung (serialization, binary, + protobuf/flatbuffers/msgpack/thrift) | Runde 1 |
| `codec_` | **neu** — Text↔Binär (base64, encoding, + hex/base32/base64url) | Runde 1/2 |
| `document_` | **neu** — fertige Dokumente (pdf, template, + docx/odt/epub) | Runde 1 |
| `markup_` | bleibt — Auszeichnungssprachen (html, xml, markdown, richtext, pod); **xml bleibt hier** (Python-Stil) | Runde 2 |
| `math_` | **Ausnahme: expansiv erlaubt** — math_number, math_algebra, math_linear, math_geometry, math_special, math_logic | Runde 2 |
| `algo_` | **neu** — Informatik/CS (algo_pathfind, algo_sort, algo_graph, algo_complexity) | Runde 2 |
| `phy_` | **neu** — Physik (phy_mechanics, phy_relativity, phy_cosmology, phy_quantum, phy_thermo) | Runde 2 |
| `chem_` / `bio_` / `econ_` | **neu** — Chemie / Biologie / Ökonomie (finance → econ) | Runde 2 |
| `stat_` | **neu/getrennt** — Statistik (stat_statistics, stat_dataframe, stat_formula) | Runde 2 |
| `units_` | **neu** — Maßeinheiten (units_distance, units_time, units_mass, …, **+ geo_**) | Runde 2 |
| `net_` / `proto_` / `web_` | **drei Schichten** — net_ = raw sockets · proto_ = alle Protokolle (http, dns, mail, rpc, imap, smtp, jmap …) · web_ = Browser-nah (url, uri, mime, cookie) | Runde 2 (C) |
| `app_frame` | **neu** — Basis: Fenster, Eventloop, Input, Plattform-Entry, Surface-Handle | Research |
| `app_native` | **neu** — eigener Renderer (Dart/Flutter-Modell), sitzt auf `gpu_` | Research |
| `app_webview` | **neu** — System-WebView (Tauri/Wails-Modell), Ziele Linux→macOS→Windows→Android→iOS | Research |
| `gpu_` | **behalten mit definiertem Mehrwert** — Grafik (wgpu-native) + Compute (MAX) in einem Ownership-Modell | Research |
| `homeless_` | **neu (Übergang)** — noch kein Zuhause (homeless_pdf, homeless_game) | Runde 1 |
| `security_` | bleibt — + webauth (Passkeys/FIDO2), totp, cert, acl, ratelimit | Runde 1 |
| `crypto_` | bleibt — + kdf, kex, aead, sign, rng, pqc | Runde 2 |
| `os_` | `daemon` → `service` | Runde 1 |
| `cli_` | bleibt + **tui** (aus ui_), `terminal`, `console` | Runde 1 |
| `fs_` | bleibt + **fs_find** | Runde 1 |
| `media_` | `pdf`, `game` → `homeless_` | Runde 1 |
| `geo_` | **weg** → zu `units_` | Runde 1 |
| `prim_` | bleibt (Nachfrage: umbenennen? → nein) | Runde 1 |

### 8.2 Capability-Ledger (neu)

- **`mojo.yml`** — was Mojo kann/nicht kann, belegt (Stand 1.1.0). Liegt im
  Repo-Root. Beispiel: `async` = **missing**, `net-sockets` = **have**
  (libc-Socket-API via C-FFI, probe-verifiziert), `c-ffi`/`time`/`pure-mojo` = **have**.
- **`mojoNeeds:`** — neues Pflichtfeld in `_todos/<id>.yml`.
- **Ableitungsregel:** `task todo` zeigt eine Lib nur, wenn alle `mojoNeeds`
  `have` sind **und** alle `libdeps` `done`.

### 8.3 Offene Punkte (bewusst unsicher → später)

1. **`frame_/gpu_/ui_` → jetzt `app_frame/app_native/app_webview/gpu_`** (Runde 2,
   „passt"). Detail-Design nach der Render-Research.
2. **`gpu_`-Mehrwert** muss konkret sein (Grafik + Compute + Ownership), sonst in
   `app_native` auflösen.
3. **Mobil** (`app_webview` auf Android/iOS) ist heute aus Mojo **nicht**
   erreichbar (kein JNI/Obj-C); Interface mobilfähig auslegen, Umsetzung später.
4. **`math_special`** als eine Lib oder splitten (`math_special_bessel` …)?
5. **`proto_`** Inhalt final (imap/smtp/jmap/ssh/ldap/mqtt/ntp …) festlegen.
6. **ADR-Ablage:** `.agents/decisions/` (neu)?
7. **Umfang:** 240 `todo` zuerst (skriptbar), die 4 `done` separat umbenennen?

---

*Vorschlag v2. Nichts umbenannt, nichts committet. Zuordnung maschinell geprüft:
244 alte IDs → 244 eindeutige neue Namen, keine Lücke, keine Dopplung (§4).*
*Research-Berichte: `docs/architecture/research/render-rust.md`,
`render-odin-zig.md`, `render-webview.md`.*
*Capability-Ledger: `mojo.yml`.*
*Umsetzung: ADR `docs/adr/0001-namespace-domains.md`.*
