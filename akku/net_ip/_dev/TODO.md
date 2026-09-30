# net_ip — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`.

## Deferred network/CIDR additions

- `Prefix` / CIDR type — an address plus a prefix length with `contains`,
  `network`, `broadcast`, `hosts` (a separate future `net_prefix` library, not this one). (origin: `go.md` §3, `python.md` §3, `cpp.md` §3)
- `Ipv4Addr.network` / `netmask` helpers — default mask and masked-network math. (origin: `go.md` §3, `python.md` §3)
- `InetAddr` / address+port pairing — the socket-address layer; likely `net_socket`. (origin: `julia.md` §3, `elixir.md` §3)
- `range`/`subnetMatch` classification against a caller-supplied list of CIDRs. (origin: `js-ts.md` §3)

## Deferred classification additions

- `is_reserved` / `is_documentation` / registry-aware predicates — IANA special-purpose registry coverage beyond the core set. (origin: `python.md` §3, `rust.md` §3)
- `is_site_local` (v6), `is_v4_compatible` (v6) — the remaining RFC 4291/4193 categories. (origin: `java.md` §9, `cpp.md` §9)
- `is_global` convenience predicate — complement-style "not private" helper. (origin: `python.md` §3, `julia.md` §3)

## Deferred conversion additions

- `to_bits` / `from_bits` — explicit integer round trip under those names (UInt32/UInt128 accessors already ship as to_u32/to_u128). (origin: `rust.md` §3, `go.md` §3)
- `format_into` — write the textual form into a caller buffer instead of returning a String. (origin: `c.md` §3; `akku.codec_base64` `encode_into`)

## Deferred I/O and interop

- `Reader`/`Writer` integration — parse from an `akku.io_core.Reader` or format into a `ByteWriter` without an intermediate string. (origin: `c.md` §3; `akku.io_core` byte layer)
- `hash` support — a stable hash for use as a map key. (origin: `go.md` §5, `python.md` §5)
- `zone id` (`%eth0`) parsing — scope ids on link-local addresses (rejected for now). (origin: `go.md` §3, RFC 4007)
