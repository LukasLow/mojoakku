from .bit_error import BitError
from .bit_error_kind import BitErrorKind
from .bit_order import BitOrder


# BitWriter — write individual bits and up to 64-bit groups into an owned buffer.
struct BitWriter(Copyable, Deinitable, Writable):
    var _bytes: List[UInt8]
    var _order: BitOrder
    var _bit_pos: Int        # total bits written so far

    def __init__(out self, order: BitOrder):
        self._bytes = List[UInt8]()
        self._order = order
        self._bit_pos = 0

    def write_bit(mut self, value: Bool):
        var byte_index = self._bit_pos // 8
        var bit_in_byte = self._bit_pos % 8
        if byte_index >= len(self._bytes):
            self._bytes.append(UInt8(0))
        var shift: UInt8
        if self._order == BitOrder.MSB_FIRST:
            shift = UInt8(7 - bit_in_byte)
        else:
            shift = UInt8(bit_in_byte)
        if value:
            self._bytes[byte_index] |= UInt8(1) << shift
        self._bit_pos += 1

    def write_bits(mut self, value: UInt64, count: Int) raises BitError:
        if count < 0 or count > 64:
            raise BitError(
                BitErrorKind.RANGE,
                "write_bits",
                "count must be between 0 and 64",
            )
        # count == 0 is a no-op only for value 0; a nonzero value cannot be
        # written in zero bits. For count == 64 there are no bits above 64, so
        # the `value >> count` shift must not be evaluated (it is undefined).
        if count == 0:
            if value != UInt64(0):
                raise BitError(
                    BitErrorKind.OVERFLOW,
                    "write_bits",
                    "a nonzero value cannot be written in zero bits",
                )
            return
        if count < 64 and (value >> UInt64(count)) != UInt64(0):
            raise BitError(
                BitErrorKind.OVERFLOW,
                "write_bits",
                "value has bits above the requested count",
            )
        var msb = self._order == BitOrder.MSB_FIRST
        for i in range(count):
            var place = i
            if msb:
                place = count - 1 - i
            var bit = ((value >> UInt64(place)) & UInt64(1)) == UInt64(1)
            self.write_bit(bit)

    def align(mut self):
        # Zero-fill the remainder of the current partial byte so a fresh byte
        # starts. Already-aligned writers are left untouched.
        var remainder = self._bit_pos % 8
        if remainder == 0:
            return
        var fill = 8 - remainder
        for _ in range(fill):
            self.write_bit(False)

    def bit_len(self) -> Int:
        return self._bit_pos

    def byte_len(self) -> Int:
        return len(self._bytes)

    def to_bytes(mut self) -> List[UInt8]:
        # Return a copy; the writer keeps its contents and stays writable. The
        # final partial byte is already zero-padded in its unused bits.
        return self._bytes.copy()

    def order(self) -> BitOrder:
        return self._order

    def write_to(self, mut writer: Some[Writer]):
        # The writer's bytes as hex, for debugging, e.g. `BitWriter(MSB_FIRST, deadbeef)`.
        writer.write("BitWriter(", self._order, ", ")
        var digits = String("0123456789abcdef")
        for b in self._bytes:
            writer.write(digits[byte=Int(b >> 4)])
            writer.write(digits[byte=Int(b & 0xF)])
        writer.write(")")

# API-DOCS-START
# BitWriter — write individual bits and up to 64-bit groups into owned bytes.
# Signature:
#   struct BitWriter(Copyable, Deinitable, Writable):
#       var _bytes: List[UInt8]
#       var _order: BitOrder
#       var _bit_pos: Int
#       def __init__(out self, order: BitOrder)
#       def write_bit(mut self, value: Bool)
#       def write_bits(mut self, value: UInt64, count: Int) raises BitError
#       def align(mut self)
#       def bit_len(self) -> Int
#       def byte_len(self) -> Int
#       def to_bytes(mut self) -> List[UInt8]
#       def order(self) -> BitOrder
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed with an explicit `order`; it owns a growing byte buffer. Write
#   bits, then take the bytes with `to_bytes`. `write_bit` appends one bit:
#   MSB_FIRST fills bit 7 of the current byte first, LSB_FIRST bit 0 first, and a
#   fresh byte starts when the current one fills. `write_bits(value, count)`
#   writes the low `count` bits (0..64) of `value`, first-written bit being the
#   most significant under MSB_FIRST (least significant under LSB_FIRST), so it
#   is the inverse of BitReader.read_bits. `count == 0` with value 0 is a no-op;
#   `count == 0` with a nonzero value raises OVERFLOW. `align` zero-fills the
#   remainder of the current partial byte and starts a fresh byte.
# Returns:
#   `to_bytes` returns the bytes as an owned List[UInt8] copy while the writer
#   keeps its contents and stays writable; the final partial byte is zero-padded
#   in its unused bits. `bit_len`/`byte_len` return Int, `order` the BitOrder.
# Errors:
#   raises BitError — RANGE when `count < 0` or `count > 64`; OVERFLOW when
#   `value` has nonzero bits above `count`. A failing write writes nothing
#   (atomic). All are recoverable.
# Example:
#   var w = BitWriter(BitOrder.MSB_FIRST)
#   w.write_bit(True)          # bit 7 -> 1
#   w.write_bits(0b101, 3)     # bits 6..4 -> 1,0,1
#   w.align()                  # zero-fill the rest of the byte
#   var bytes = w.to_bytes()   # -> [0b1101_0000]
#   print(w.bit_len())         # -> 8 (4 written bits + 4 zero-filled by align)
#   w.write_bit(False)         # writer stays usable
# API-DOCS-END
