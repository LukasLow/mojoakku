# MojoAkku prim_endian — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from akku.prim_endian import ...` works. Nothing else lives here: the public
# surface is defined by the per-entry files and this file only forwards names.

from .endian_order import EndianOrder
from .endian_error_kind import EndianErrorKind
from .endian_error import EndianError
from .host_order import host_order
from .swap_bytes import swap_bytes
from .to_order import to_order
from .from_order import from_order
from .to_bytes_into import to_bytes_into
from .from_bytes import from_bytes

# API-DOCS-START
# Purpose   — akku/prim_endian is the MojoAkku byte-order (endianness) library:
#   a small, predictable toolkit that names byte order, detects the host order
#   at compile time, converts integer values between the host order and a named
#   order, and reads or writes an integer's bytes to/from a byte span with an
#   explicit order and a length check. It is a leaf library with no sibling
#   dependencies. It is built for a low-vision user: one order value, one typed
#   error with a closed kind, explicit order on every call — never a global
#   switch and never a hidden default — value semantics throughout, and no magic
#   sentinels.
# Overview  — three independently usable layers:
#     1. Order vocabulary — EndianOrder. The concrete orders LITTLE and BIG plus
#        the compile-time alias NATIVE, which resolves to the host order.
#        Network byte order is documented as BIG; there is no NETWORK value.
#     2. Value conversion — host_order, swap_bytes, to_order, from_order.
#        host_order() reports the target's order; swap_bytes is the raw reversal
#        primitive; to_order/from_order reinterpret an integer between the host
#        order and a named order (a no-op when they already match).
#     3. Buffer layer — to_bytes_into, from_bytes. Write an integer's bytes into
#        a caller-owned MutSpan[UInt8, _], or read an integer from a borrowed
#        Span[UInt8, _], in an explicit order, with a length check that raises a
#        typed error.
#   Cross-cutting: one typed error (EndianError) with a closed EndianErrorKind
#   (BAD_LENGTH, OTHER); one order value (EndianOrder) reused by every call;
#   explicit order on every call; and value semantics throughout with no hidden
#   global state.
# Dependencies — none. prim_endian depends only on the Mojo standard library
#   (Scalar, DType, Span, MutSpan, UInt8, String, Some[Writer]) and the standard
#   primitives std.bit.byte_swap and std.sys host-order predicates. It is a leaf:
#   no signature mentions a stream, socket, file or other sibling concept. Later
#   protocol and serialisation libraries point to prim_endian, never the reverse.
# Public API — the ordered index (each entry is specified in its own file):
#     1. EndianOrder      — the order of a conversion: LITTLE, BIG, NATIVE.
#     2. EndianErrorKind  — closed failure discriminant: BAD_LENGTH, OTHER.
#     3. EndianError      — the one typed error: kind: EndianErrorKind,
#                           op: String, detail: String.
#     4. host_order       — the host's order, resolved at compile time; returns
#                           LITTLE or BIG (never a third value).
#     5. swap_bytes       — reverse an integral value's byte order.
#     6. to_order         — reinterpret an integer from the host order into a
#                           named order (no-op or swap).
#     7. from_order       — the inverse of to_order (interpret a value that is
#                           in a named order as a host-order value).
#     8. to_bytes_into    — write an integer's bytes into a caller-owned
#                           MutSpan[UInt8, _] in a given order; length-checked.
#     9. from_bytes       — read an integer from a borrowed Span[UInt8, _] in a
#                           given order; length-checked.
# Error Surface — exactly one error type, EndianError, carrying
#   kind: EndianErrorKind, op: String and detail: String. Which API raises what:
#     EndianOrder / EndianErrorKind / EndianError  — none
#     host_order / swap_bytes / to_order /
#       from_order                                 — none
#     to_bytes_into                                — EndianError: BAD_LENGTH
#                                                    (dst.len != the carrier's
#                                                    byte width)
#     from_bytes                                   — EndianError: BAD_LENGTH
#                                                    (src.len != the carrier's
#                                                    byte width)
#   The only release-1 EndianError is a recoverable data error: the caller passes
#   a correctly sized buffer. No operation is fatal and none aborts. OTHER is
#   reserved for any other condition and carries its context in the opaque
#   detail string; no release-1 operation raises it. Callers branch on kind,
#   never on the opaque detail string. `print(err)` gives a readable message.
# Conventions — one order vocabulary: LITTLE, BIG and the compile-time alias
#   NATIVE. Network byte order is big-endian and is documented as BIG; there is
#   no separate NETWORK value. Order is always explicit: every conversion and
#   buffer call takes an EndianOrder, with no default and no global switch.
#   NATIVE resolves at compile time and is the non-portable path. Byte layout is
#   per order: for BIG, byte index 0 is the most significant byte; for LITTLE,
#   byte index 0 is the least significant byte. Byte width is the carrier's own
#   width, never inferred from a length argument. Names are snake_case for
#   functions and methods, CamelCase for types and SCREAMING_CASE for comptime
#   constants. Value conversions are total; only the buffer layer raises, and
#   only for a wrong length. There are no sentinels and no hidden global state.
# API-DOCS-END
