# MojoAkku bit — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from bit import ...` works. Nothing else lives here: the public surface is
# defined by the per-entry files and this file only forwards names.

from .bit_error_kind import BitErrorKind
from .bit_error import BitError
from .bit_order import BitOrder
from .bit_set import BitSet
from .bit_set_iter import BitSetIter
from .get_bits import get_bits
from .set_bits import set_bits
from .bit_reader import BitReader
from .bit_writer import BitWriter

# API-DOCS-START
# Purpose   — akku/prim_bit is the bit twiddling and bitset library for MojoAkku:
#   a small, predictable toolkit for working at the bit level. It is a leaf
#   library with no sibling dependencies, and a general-purpose base block useful
#   far outside networking for flags, permission sets, feature switches, bitfield
#   parsing and packed data. It is built for a low-vision user: one error model,
#   one ordering model, one container, explicit bounds behaviour and no magic
#   values. The Mojo standard library already ships the scalar primitives in
#   std.bit (pop_count, clz/ctz, bit_reverse, rotate, ...), so bit does not
#   rebuild them; it fills the three gaps the stdlib leaves.
# Overview  — three independently usable layers on top of the stdlib scalars:
#     1. Container layer — BitSet. A growable, word-packed set of bits
#        (List[UInt64], 64-bit words) with LSB-first indexing, value semantics,
#        set algebra (incl. `complement` over an explicit width), cardinality,
#        ascending search (`find_next`), full iteration (`for i in bits`),
#        and byte serialisation (`to_bytes` / `from_bytes`).
#     2. Bitfield layer — get_bits / set_bits. Extract or insert an inclusive
#        [hi:lo] sub-range of any unsigned integral carrier (generic over dtype),
#        with defined bounds and a defined overflow policy (a field that does not
#        fit raises, never truncates).
#     3. Bit-I/O layer — BitReader / BitWriter. Read and write individual bits
#        and up to 64-bit groups over bytes, with an explicit bit order passed
#        by the caller — never a global switch and never a hidden default.
#   Cross-cutting: one typed error (BitError) with a closed BitErrorKind; one
#   ordering value (BitOrder); explicit bounds; and value semantics throughout
#   with no hidden global state.
# Dependencies — none. bit depends only on the Mojo standard library (Span,
#   List, Optional, UInt64, Int, Bool, String). It is a leaf: no signature
#   mentions a stream, socket, file, buffer or other sibling concept. Later
#   libraries (hash, digest, encoding, compression) point to bit, never the
#   reverse.
# Public API — the ordered index (each entry is specified in its own file):
#     1. BitErrorKind — closed failure discriminant: RANGE, BAD_RANGE,
#                        OVERFLOW, EOF, OTHER.
#     2. BitError     — the one typed error: kind: BitErrorKind, op: String,
#                        detail: String.
#     3. BitOrder     — the bit order of a reader/writer: MSB_FIRST, LSB_FIRST.
#     4. BitSet       — a growable, word-packed set of bits with LSB-first
#                        indexing, set algebra (incl. complement), cardinality,
#                        ascending search, iteration and byte serialisation.
#     5. BitSetIter   — ascending iterator over a BitSet's set-bit indices,
#                        returned by `BitSet.__iter__` (snapshot semantics).
#     6. get_bits     — extract the inclusive field [hi:lo] of an unsigned
#                        integral value as a right-aligned value of the same type.
#     7. set_bits     — insert a field into the inclusive [hi:lo] range of an
#                        unsigned integral value, returning the new value.
#     8. BitReader    — read individual bits and up to 64-bit groups over a
#                        borrowed byte span, in an explicit bit order.
#     9. BitWriter    — write individual bits and up to 64-bit groups into an
#                        owned byte buffer, in an explicit bit order.
# Error Surface — exactly one error type, BitError, carrying kind: BitErrorKind,
#   op: String and detail: String. Which API raises what:
#     BitSet.set / clear / toggle / set_to / test /
#       set_range / clear_range / toggle_range /
#       complement / complement_with           — BitError: RANGE (negative
#                                                  index / negative lo / negative
#                                                  complement width),
#                                                  BAD_RANGE (lo > hi)
#     BitSet queries and set algebra (find_next,
#       count, is_empty, all, any, none, is_subset_of,
#       is_superset_of, is_disjoint, to_list, to_bytes,
#       from_bytes, __iter__, reserve, shrink, clear_all,
#       __len__, capacity, union, intersection, difference,
#       symmetric_difference, *_with)           — none
#     get_bits / set_bits                       — BitError: RANGE (lo < 0 or
#                                                  hi > bit_width - 1), BAD_RANGE
#                                                  (hi < lo), OVERFLOW (field does
#                                                  not fit)
#     BitReader.read_bit                        — BitError: EOF
#     BitReader.read_bits                       — BitError: EOF, RANGE
#                                                  (count < 1 or count > 64)
#     BitReader.align / bit_pos / bits_left /
#       has_bits / order                        — none
#     BitWriter.write_bits                      — BitError: RANGE (count < 0 or
#                                                  count > 64), OVERFLOW (nonzero
#                                                  bits above count)
#     BitWriter.write_bit / align / bit_len /
#       byte_len / to_bytes / order             — none
#   Every BitError is a recoverable data error: correct the index/range/count,
#   widen the field, or read fewer bits / supply more bytes. No operation is
#   fatal. Callers branch on `kind`, never on the opaque `detail` string.
#   `print(err)` gives a readable operation + detail message.
# Conventions — indexing: the container is LSB-first and zero-based (index i is
#   bit i % 64 of word i / 64); it is not configurable. Ranges are inclusive
#   [lo, hi] with lo <= hi; lo > hi is BAD_RANGE and a negative bound is RANGE.
#   `BitSet` byte serialisation is little-endian, LSB-first and minimal length.
#   Ordering is explicit and per reader/writer, never global. The bitfield
#   carrier is generic over any unsigned integral dtype; the field bound is the
#   carrier's own width. Names are snake_case for functions and methods,
#   CamelCase for types and SCREAMING_CASE for comptime constants. There are no
#   sentinels — absence is Optional and a bad input is a typed error — and no
#   hidden global state.
# API-DOCS-END
