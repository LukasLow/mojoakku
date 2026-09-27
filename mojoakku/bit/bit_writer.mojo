from std.os import abort

from .bit_error import BitError
from .bit_order import BitOrder


# BitWriter — write individual bits and up to 64-bit groups into an owned buffer.
struct BitWriter(Copyable, Deinitable, Writable):
    var _bytes: List[UInt8]
    var _order: BitOrder
    var _bit_pos: Int        # bits written into the current partial byte

    def __init__(out self, order: BitOrder):
        abort("MojoAkku: this API is not yet implemented")

    def write_bit(mut self, value: Bool):
        abort("MojoAkku: this API is not yet implemented")

    def write_bits(mut self, value: UInt64, count: Int) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def align(mut self):
        abort("MojoAkku: this API is not yet implemented")

    def bit_len(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def byte_len(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def to_bytes(mut self) -> List[UInt8]:
        abort("MojoAkku: this API is not yet implemented")

    def order(self) -> BitOrder:
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

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
#   print(w.bit_len())         # -> 4
#   w.write_bit(False)         # writer stays usable
# API-DOCS-END
