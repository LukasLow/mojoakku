from std.os import abort

from .bit_error import BitError
from .bit_order import BitOrder


# BitReader — read individual bits and up to 64-bit groups over a borrowed span.
struct BitReader[origin: Origin[mut=False]](Deinitable):
    var _buffer: Span[UInt8, Self.origin]
    var _order: BitOrder
    var _bit_pos: Int

    def __init__(out self, buffer: Span[UInt8, Self.origin], order: BitOrder):
        abort("MojoAkku: this API is not yet implemented")

    def read_bit(mut self) raises BitError -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def read_bits(mut self, count: Int) raises BitError -> UInt64:
        abort("MojoAkku: this API is not yet implemented")

    def align(mut self):
        abort("MojoAkku: this API is not yet implemented")

    def bit_pos(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def bits_left(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def has_bits(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def order(self) -> BitOrder:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# BitReader — read individual bits and up to 64-bit groups from borrowed bytes.
# Signature:
#   struct BitReader[origin: Origin[mut=False]](Deinitable):
#       var _buffer: Span[UInt8, Self.origin]
#       var _order: BitOrder
#       var _bit_pos: Int
#       def __init__(out self, buffer: Span[UInt8, Self.origin], order: BitOrder)
#       def read_bit(mut self) raises BitError -> Bool
#       def read_bits(mut self, count: Int) raises BitError -> UInt64
#       def align(mut self)
#       def bit_pos(self) -> Int
#       def bits_left(self) -> Int
#       def has_bits(self) -> Bool
#       def order(self) -> BitOrder
# What it does:
#   Constructed from a borrowed Span[UInt8, _]; it never owns, copies or retains
#   the data, and the lifetime checker ties the reader to the borrowed span.
#   `order` sets the bit sequence. `read_bit` returns the next bit (True = 1):
#   MSB_FIRST visits bit 7, 6, ... of each byte, LSB_FIRST visits bit 0, 1, ....
#   `read_bits(count)` reads the next `count` bits (1..64) as a UInt64; the first
#   bit read is the most significant of the returned value under MSB_FIRST and
#   the least significant under LSB_FIRST, so you never reverse the result.
#   `read_bits` is atomic: if not enough bits remain it raises EOF and leaves the
#   reader unchanged, so you can retry with a smaller count. `align` advances to
#   the next byte boundary, clamping to the total bit count so bits_left never
#   goes negative. `bit_pos`, `bits_left`, `has_bits` and `order` report state.
# Returns:
#   `read_bit` returns a Bool, `read_bits` a UInt64; `bit_pos`/`bits_left` an
#   Int, `has_bits` a Bool, `order` the reader's BitOrder. None borrows from or
#   retains the source bytes.
# Errors:
#   raises BitError — EOF when no bits remain (read_bit) or not enough bits
#   remain (read_bits); RANGE when read_bits is called with count < 1 or
#   count > 64. All are recoverable.
# Example:
#   var data: List[UInt8] = [0b1011_0100]
#   var r = BitReader(Span(data), BitOrder.MSB_FIRST)
#   print(r.read_bit())      # -> True   (bit 7 first)
#   print(r.read_bits(3))    # -> next 3 bits as a value
#   print(r.bits_left())     # -> 4
# API-DOCS-END
