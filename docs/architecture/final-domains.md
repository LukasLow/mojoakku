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

## Neue Libs (angelegt)

74 zusätzliche Libraries wurden nach dem Namespace-Gespräch beschlossen und als
`_todos/<id>.yml` angelegt (`status: todo`). Quelle der Zeilen:
`docs/architecture/new-libraries.txt`.

- `units_` (8): units_distance units_mass units_time units_temperature units_electricity units_energy units_pressure units_speed
- `phy_` (5): phy_mechanics phy_relativity phy_cosmology phy_quantum phy_thermo
- `chem_` (4): chem_core chem_molecule chem_reaction chem_periodic
- `bio_` (4): bio_core bio_sequence bio_genome bio_align
- `econ_` (3): econ_core econ_finance econ_money
- `math_special_` (4): math_special_bessel math_special_gamma math_special_erf math_special_orthogonal
- `app_` (3): app_frame app_native app_webview
- `crypto_` (6): crypto_kdf crypto_kex crypto_aead crypto_sign crypto_rng crypto_pqc
- `security_` (5): security_webauth security_totp security_cert security_acl security_ratelimit
- `proto_` (9): proto_pop3 proto_imap proto_smtp proto_jmap proto_ssh proto_ldap proto_mqtt proto_ntp proto_snmp
- `archive_` (5): archive_zip archive_tar archive_gzip archive_zstd archive_7z
- `serialize_` (4): serialize_protobuf serialize_flatbuffers serialize_msgpack serialize_thrift
- `codec_` (3): codec_hex codec_base32 codec_base64url
- `document_` (4): document_docx document_odt document_epub document_convert
- `algo_` (5): algo_pathfind algo_sort algo_graph algo_complexity algo_search
- `fs_` (1): fs_find
- `time_` (1): time_duration

## Abgeleitete mojoNeeds (Vorschlag, pro Domain)
- pure (text/markup/format/codec/code/math*/stat/algo/coll/lang/meta/mem/prim/time/dev): `[pure-mojo]`
- db/archive/serialize: `[pure-mojo]` (Datei-IO), redis: `[net-sockets]`
- crypto_/security_: `[pure-mojo]`; security_tls: `[net-sockets]`
- net_/proto_/web_: `[net-sockets]`; web_http* zusätzlich `[c-ffi]`? nein → `[net-sockets]`
- os_/fs_/io_/cli_: `[pure-mojo, fs-full]` (process: `[process]`)
- sync_: `[threads]`; async_: `[async]` (→ missing!); dist_: `[net-sockets, threads]`
- media_: `[pure-mojo]`; ui_/app_*: `[gui-windowing]` bzw. `[webview]`
- covered_*: `[pure-mojo]` (nur Doku)
