from .bit_error import BitError
from .bit_error_kind import BitErrorKind
from .bit_order import BitOrder


# BitReader — read individual bits and up to 64-bit groups over a borrowed span.
struct BitReader[origin: Origin[mut=False]](Deinitable):
    var _buffer: Span[UInt8, Self.origin]
    var _order: BitOrder
    var _bit_pos: Int

    def __init__(out self, buffer: Span[UInt8, Self.origin], order: BitOrder):
        self._buffer = buffer
        self._order = order
        self._bit_pos = 0

    def read_bit(mut self) raises BitError -> Bool:
        if self._bit_pos >= len(self._buffer) * 8:
            raise BitError(
                BitErrorKind.EOF, "read_bit", "no bits remain in the buffer"
            )
        var bit = self._bit_at(self._bit_pos)
        self._bit_pos += 1
        return bit

    def read_bits(mut self, count: Int) raises BitError -> UInt64:
        if count < 1 or count > 64:
            raise BitError(
                BitErrorKind.RANGE,
                "read_bits",
                "count must be between 1 and 64",
            )
        var total = len(self._buffer) * 8
        # Atomic: check availability before advancing _bit_pos, so an EOF
        # leaves the reader unchanged and the caller can retry with a smaller
        # count.
        if self._bit_pos + count > total:
            raise BitError(
                BitErrorKind.EOF,
                "read_bits",
                "not enough bits remain in the buffer",
            )
        var value = UInt64(0)
        var msb = self._order == BitOrder.MSB_FIRST
        for i in range(count):
            var bit = self._bit_at(self._bit_pos)
            self._bit_pos += 1
            var place = i
            if msb:
                place = count - 1 - i
            if bit:
                value |= UInt64(1) << UInt64(place)
        return value

    def align(mut self):
        var total = len(self._buffer) * 8
        var next = (self._bit_pos + 7) // 8 * 8
        # Clamp to the total bit count so bits_left never goes negative.
        if next > total:
            next = total
        self._bit_pos = next

    def bit_pos(self) -> Int:
        return self._bit_pos

    def bits_left(self) -> Int:
        return len(self._buffer) * 8 - self._bit_pos

    def has_bits(self) -> Bool:
        return self.bits_left() > 0

    def order(self) -> BitOrder:
        return self._order

    # ----------------------------------------------------------------------
    # Private helpers (not part of the public surface).
    # ----------------------------------------------------------------------

    def _bit_at(self, pos: Int) -> Bool:
        # MSB_FIRST visits bit 7 of a byte first; LSB_FIRST visits bit 0 first.
        var byte_index = pos // 8
        var bit_in_byte = pos % 8
        var shift: UInt8
        if self._order == BitOrder.MSB_FIRST:
            shift = UInt8(7 - bit_in_byte)
        else:
            shift = UInt8(bit_in_byte)
        return ((self._buffer[byte_index] >> shift) & UInt8(1)) == UInt8(1)

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
