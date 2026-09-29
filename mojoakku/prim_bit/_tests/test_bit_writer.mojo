# Concern: `BitWriter` — writing individual bits and up to 64-bit groups into
# an owned byte buffer in an explicit `BitOrder` (docs block in
# `../bit_writer.mojo`).
#
# Covers: `write_bit` fills bit 7 of the current byte first under `MSB_FIRST`
# and bit 0 first under `LSB_FIRST`; `write_bits(value, count)` writes the low
# `count` bits; `count == 0` with value 0 is a no-op, `count == 0` with a
# nonzero value raises `OVERFLOW`; a value with bits above `count` raises
# `OVERFLOW` and writes nothing (atomic); `align` zero-fills the remainder of
# the partial byte; `bit_len` / `byte_len` accounting; `to_bytes` returns an
# owned copy whose final partial byte is zero-padded while the writer keeps its
# contents and stays writable; `RANGE` for count 65 and -1.
#
# Byte-literal helpers: the expected full-byte values are written as explicit
# `UInt8` expressions because Mojo integer literals are not `UInt8`-typed
# automatically in every position.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitWriter, BitOrder, BitErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


def test_bitwriter_fill_byte_msb_vs_lsb() raises:
    # One bit set, then aligned: MSB_FIRST fills bit 7 (0x80), LSB_FIRST bit 0
    # (0x01).
    var msb = BitWriter(BitOrder.MSB_FIRST)
    msb.write_bit(True)
    msb.align()
    assert_equal(msb.to_bytes(), bytes_of(UInt8(0x80)))

    var lsb = BitWriter(BitOrder.LSB_FIRST)
    lsb.write_bit(True)
    lsb.align()
    assert_equal(lsb.to_bytes(), bytes_of(UInt8(0x01)))

    # A full byte written bit by bit: 1,0,1,1,0,1,0,0.
    var pattern = BitWriter(BitOrder.MSB_FIRST)
    var bits = List[Bool]()
    bits.append(True)
    bits.append(False)
    bits.append(True)
    bits.append(True)
    bits.append(False)
    bits.append(True)
    bits.append(False)
    bits.append(False)
    for b in bits:
        pattern.write_bit(b)
    assert_equal(pattern.to_bytes(), bytes_of(UInt8(0b1011_0100)))


def test_bitwriter_count_zero_noop() raises:
    var w = BitWriter(BitOrder.MSB_FIRST)
    w.write_bits(UInt64(0), 0)
    assert_equal(w.bit_len(), 0)
    assert_equal(w.byte_len(), 0)
    assert_equal(len(w.to_bytes()), 0)


def test_bitwriter_count_zero_nonzero_overflow() raises:
    var w = BitWriter(BitOrder.MSB_FIRST)
    var caught = False
    var kind = BitErrorKind.OTHER
    var op = ""
    try:
        w.write_bits(UInt64(1), 0)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, BitErrorKind.OVERFLOW)
    assert_equal(op, "write_bits")
    # Nothing was written.
    assert_equal(w.bit_len(), 0)
    assert_equal(w.byte_len(), 0)


def test_bitwriter_overflow_high_bits() raises:
    # 0b1_0000_0000 has a nonzero bit above count = 8.
    var w = BitWriter(BitOrder.MSB_FIRST)
    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        w.write_bits(UInt64(0b1_0000_0000), 8)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.OVERFLOW)
    # A failing write writes nothing (atomic).
    assert_equal(w.bit_len(), 0)
    assert_equal(w.byte_len(), 0)

    # A value that exactly fits does not raise and writes the low bits.
    w.write_bits(UInt64(0xFF), 8)
    assert_equal(w.bit_len(), 8)
    w.align()
    assert_equal(w.to_bytes(), bytes_of(UInt8(0xFF)))


def test_bitwriter_align_zero_fills() raises:
    # Two bits written, then aligned: the remaining six bits of the byte are
    # zero-filled.
    var w = BitWriter(BitOrder.MSB_FIRST)
    w.write_bit(True)
    w.write_bit(True)
    assert_equal(w.bit_len(), 2)
    assert_equal(w.byte_len(), 1)
    w.align()
    assert_equal(w.bit_len(), 8)
    assert_equal(w.byte_len(), 1)
    assert_equal(w.to_bytes(), bytes_of(UInt8(0b1100_0000)))

    # align on an already byte-aligned writer is a no-op.
    w.align()
    assert_equal(w.bit_len(), 8)
    assert_equal(w.byte_len(), 1)


def test_bitwriter_len_accounting() raises:
    var w = BitWriter(BitOrder.MSB_FIRST)
    assert_equal(w.bit_len(), 0)
    assert_equal(w.byte_len(), 0)

    w.write_bits(UInt64(0b101), 3)
    assert_equal(w.bit_len(), 3)
    # The partial byte is already allocated.
    assert_equal(w.byte_len(), 1)

    # Seven more bits fill the first byte and spill one bit into the second.
    w.write_bits(UInt64(0b111_1111), 7)
    assert_equal(w.bit_len(), 10)
    assert_equal(w.byte_len(), 2)

    w.align()
    assert_equal(w.bit_len(), 16)
    assert_equal(w.byte_len(), 2)


def test_bitwriter_to_bytes_pads_and_keeps_writable() raises:
    var w = BitWriter(BitOrder.MSB_FIRST)
    w.write_bits(UInt64(0b101), 3)
    # The final partial byte is zero-padded in its unused bits.
    assert_equal(w.to_bytes(), bytes_of(UInt8(0b1010_0000)))
    # to_bytes returned a copy and left the writer's contents intact.
    assert_equal(w.bit_len(), 3)
    assert_equal(w.byte_len(), 1)
    # The writer stays writable: the next bits continue in the same byte.
    w.write_bit(False)
    w.write_bit(False)
    w.write_bit(False)
    w.write_bit(False)
    w.write_bit(True)
    assert_equal(w.bit_len(), 8)
    assert_equal(w.to_bytes(), bytes_of(UInt8(0b1010_0001)))


def test_bitwriter_count_range_raises() raises:
    var w = BitWriter(BitOrder.MSB_FIRST)

    var caught = False
    var kind = BitErrorKind.OTHER
    var op = ""
    try:
        w.write_bits(UInt64(0), 65)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)
    assert_equal(op, "write_bits")

    caught = False
    try:
        w.write_bits(UInt64(0), -1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    # A rejected count writes nothing.
    assert_equal(w.bit_len(), 0)
    assert_equal(w.byte_len(), 0)


def test_bitwriter_write_to_hex() raises:
    # write_to prints the writer's bytes as hex for debugging.
    var w = BitWriter(BitOrder.MSB_FIRST)
    w.write_bits(UInt64(0xFF), 8)
    var text = String(w)
    # The byte 0xFF appears in some hex form (upper or lower case).
    assert_true("ff" in text or "FF" in text)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
