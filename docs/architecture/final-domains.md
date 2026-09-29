# FINALE Domain-Zuordnung — maßgeblich für den Rename

Regel: `alt_id` → `<domain>_<lokalname>`. Lokalname = alt_id, AUSSER in der
Ausnahmetabelle unten. Kein Bindestrich. `depends_on` wird mit umbenannt.

## Domain → Präfix + Mitglieder (alt-ids)

### Text & Struktur
- `text_`   : string encoding unicode regex format diff search pretty textedit i18n
- `markup_` : html xml markdown richtext pod template
- `document_`: pdf
- `format_` : json csv toml yaml ini zon config spec
- `codec_`  : base64
- `code_`   : ast parser interpreter codegen objectfile lint

### Daten
- `db_`      : database sql orm redis kvstore table cache
- `archive_` : archive compression
- `serialize_`: serialization binary

### Zahlen (math_ expansiv)
- `math_`      : numerics complex decimal rational bigint factor currency random
- `math_linear_`: matrix tensor geometry graph
- `math_special_`: (neu, gesplittet)
- `algo_`      : algorithm
- `stat_`      : statistics formula dataframe

### Natur / Anwendung
- `phy_`   : (neu) mechanics relativity cosmology quantum thermo
- `chem_`  : (neu)
- `bio_`   : (neu)
- `econ_`  : currency? -> NEIN, currency bleibt math_. econ = (neu)
- `units_` : unit geo

### Krypto / Security
- `crypto_`   : hash digest cipher mac publickey certificate noise
- `security_` : tls keyring jwt oauth password auth

### Netz (3 Schichten)
- `net_`   : socket tcp udp ip nic packet multicast unixsocket
- `proto_` : dns ftp rpc mail   (mail wird zu pop3 imap smtp jmap aufgelöst)
- `web_`   : http http2 http3 websocket sse quic url uri mime cookie

### System
- `os_`    : os process env signal user daemon session shell management notification clipboard
- `fs_`    : fs file path glob tempfile watch mmap
- `io_`    : io stream
- `cli_`   : cli terminal console tui
- `sync_`  : sync atomic thread channel queue pool cell stm
- `async_` : async future coroutine eventloop scheduler flow
- `dist_`  : actor cluster supervisor broker parallel isolate
- `time_`  : time datetime timezone
- `build_` : build package module target versioning migration artifact autoload plugin lockfile virtualenv

### Sprache
- `lang_` : error trait typeclass functor enum variant option pattern closure context contextmanager dataclass propertywrapper keypath defer drop tie immutable contract lazy logic
- `meta_` : comptime macro metadata metatable reflection dispatch overload quotation annotation typing varargs delegation singleton observation observer embed
- `coll_` : collections tuple ranges set iter bisect zipper transducer handlemap
- `mem_`  : memory ownership allocator layout align pin refcount weak weakref safety
- `prim_` : bit endian limits
- `dev_`  : logging tracing profiling benchmark debug testing mock metric instrument doc ffi hotload sandbox script

### Medien / UI
- `media_` : image audio font color game
- `ui_`    : gui tui chart easing input
- `app_`   : app_frame app_native app_webview (neu)
- `homeless_`: pdf game   (Übergang; pdf ist oben bei document_ — entscheide: homeless)
- `covered_`: simd tensor broadcast soa ml   (std/MAX deckt; nicht bauen)

## Lokale Namens-Ausnahmen (alt_id → neuer lokaler Name)

| alt_id | lokalname | voll |
|---|---|---|
| time | clock | time_clock |
| timezone | zone | time_zone |
| math | core | math_core |
| os | core | os_core |
| fs | core | fs_core |
| io | core | io_core |
| sync | core | sync_core |
| memory | core | mem_core |
| collections | core | coll_core |
| cli | core | cli_core |
| async | core | async_core |
| build | core | build_core |
| unit | core | units_core |
| algorithm | pathfind? | NEIN → algo_core |
| format | text_format | text_format (Konflikt-Notiz) |

## Domain-Präfixe OHNE Mitglied (bleiben leer, nur Konvention)
- `app_`, `phy_`, `chem_`, `bio_`, `econ_` → neue Libs (später)

## Abgeleitete mojoNeeds (Vorschlag, pro Domain)
- pure (text/markup/format/codec/code/math*/stat/algo/coll/lang/meta/mem/prim/time/dev): `[pure-mojo]`
- db/archive/serialize: `[pure-mojo]` (Datei-IO), redis: `[net-sockets]`
- crypto_/security_: `[pure-mojo]`; security_tls: `[net-sockets]`
- net_/proto_/web_: `[net-sockets]`; web_http* zusätzlich `[c-ffi]`? nein → `[net-sockets]`
- os_/fs_/io_/cli_: `[pure-mojo, fs-full]` (process: `[process]`)
- sync_: `[threads]`; async_: `[async]` (→ missing!); dist_: `[net-sockets, threads]`
- media_: `[pure-mojo]`; ui_/app_*: `[gui-windowing]` bzw. `[webview]`
- covered_*: `[pure-mojo]` (nur Doku)
