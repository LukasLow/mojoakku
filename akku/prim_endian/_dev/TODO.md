# prim_endian — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected
end state.

## Value conversions

- `to_network` / `to_host` word aliases — htonl/ntohl-style names for the
  big-endian edge. (origin: `c.md` §1)
- `swap_words` for multi-word carriers beyond the scalar width. (origin:
  `c.md` §1)
- `to_ne_bytes` / `from_ne_bytes` fixed-size native byte-array conversion — a
  `[u8; N]`-style value form. (origin: `rust.md` §3)
- `to_be_bytes` / `from_be_bytes` (and le/ne) fixed-size byte-array conversion —
  value → `[u8; N]` and back. (origin: `rust.md` §3)
- A tagged order-carrying integer wrapper (`BigEndian[Int32]`-style) that keeps
  the endianness invariant in the type. (origin: `c.md` §11, `cpp.md` §11)
- Float carriers for `swap_bytes` / `to_order` / `from_order`, with the
  documented NaN/reinterpret caveat. (origin: `cpp.md` §11)
- `comptime`-order specialization — instantiate the conversion per order
  instead of passing a runtime `EndianOrder` value. (origin: `cpp.md` §12,
  `elixir.md` §12)

## Buffer / byte-array layer

- Append helpers — append a value's bytes to an existing buffer. (origin:
  `go.md` §3)
- Stream helpers — read a value from / write a value to a reader/writer.
  (origin: `go.md` §3, `java.md` §3)

## Order as a value

- Buffer-order handle — a cursor/reader carrying its own order, à la
  `ByteBuffer.order`. (origin: `java.md` §1)

## Host detection beyond a bool

- A runtime-free three-way host classification including mixed/pdp order.
  (origin: `c.md` §1, §9)

## Declarative carrier

- Pattern-style endian conversion over a byte sequence (Elixir `::big`/
  `::little`/`::native` analogue). (origin: `elixir.md` §1)
