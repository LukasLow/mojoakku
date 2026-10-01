# prim_endian — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected
end state.

## Value conversions

- `to_network` / `to_host` word aliases — htonl/ntohl-style names for the
  big-endian edge. (origin: `c.md` §1)
- `swap_words` for multi-word carriers beyond the scalar width. (origin:
  `c.md` §1)

## Buffer / byte-array layer

- `to_be_bytes` / `from_be_bytes` (and le/ne) fixed-size byte-array conversion —
  value → `[u8; N]` and back. (origin: `rust.md` §3)
- Slice / byte-span encode-decode with a length check — the fallible buffer form
  for non-statically-known lengths. (origin: `rust.md` §4)
- Append helpers — write a value's bytes into an existing buffer. (origin:
  `go.md` §3)
- Stream helpers — read a value from / write a value to a reader/writer.
  (origin: `go.md` §3, `java.md` §3)

## Order as a value

- `ByteOrder` value type (BIG / LITTLE / NATIVE) with per-call selection —
  the Go/Rust `ByteOrder` abstraction. (origin: `go.md` §7, `rust.md` §7)
- Buffer-order handle — a cursor/reader carrying its own order, à la
  `ByteBuffer.order`. (origin: `java.md` §1)

## Host detection beyond a bool

- A named `NativeEndian` value/alias rather than a bare boolean. (origin:
  `rust.md` §9)
- A runtime-free three-way host classification including mixed/pdp order.
  (origin: `c.md` §1, §9)

## Declarative carrier

- Pattern-style endian conversion over a byte sequence (Elixir `::big`/
  `::little`/`::native` analogue). (origin: `elixir.md` §1)
