BREAKING: catalogue — all 244 libraries renamed to domain-prefixed flat names (`bit`→`prim_bit`, `io`→`io_core`, `base64`→`codec_base64`, `string`→`text_string`, `socket`→`net_socket`, …); every `depends_on` rewritten. New in the YAML: `mojoNeeds:` per library.
NEW: mojo.yml capability ledger (what Mojo 1.1.0 can/cannot do, sourced) + `task todo` capability gate (`mojoNeeds` must be `have`); `task todo -- --all` / `todo-all` show planned-but-blocked libs with reasons.
NEW: `docs/adr/0001-namespace-domains.md` + `docs/architecture/` (namespace model, domain map, rename map, render research).
INTERNAL: `covered_*` namespace for std/MAX-covered libs (simd, tensor, broadcast, soa, ml); `homeless_*` for pdf/game.
