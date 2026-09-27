# Concern: `BitReader` — reading individual bits and up to 64-bit groups from a
# borrowed byte span in an explicit `BitOrder` (docs block in
# `../bit_reader.mojo`).
#
# Covers: `read_bit` visits bit 7,6,… under `MSB_FIRST` and bit 0,1,… under
# `LSB_FIRST`, across a byte boundary; `read_bits(count)` reads 1..64 bits with
# the first-read bit as the most significant (`MSB_FIRST`) or least significant
# (`LSB_FIRST`) of the result; `align` skips to the next byte boundary and
# clamps `_bit_pos` to the total bit count so `bits_left` never goes negative;
# `read_bits` is atomic — an `EOF` leaves `_bit_pos` unchanged and the caller
# can retry with a smaller count; `RANGE` for count 0, 65 and negative;
# `bit_pos` / `bits_left` / `has_bits` accounting.
#
# Compile-time property: `test_bitreader_cannot_outlive_span`. The reader holds
# a borrowed `Span[UInt8, _]` and the lifetime checker ties it to the borrowed
# data; a reader that outlives its span does not compile. There is no runtime
# expression of "does not outlive", so this is recorded as a documented
# note (as in `mojoakku/io`), never as a fake runtime assertion.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from bit import BitReader, BitOrder, BitErrorKind


def test_bitreader_read_bit_across_byte() raises:
    # Byte 0 = 0b1011_0100; MSB_FIRST visits bit 7..bit 0 (1,0,1,1,0,1,0,0).
    var data: List[UInt8] = [0b1011_0100, 0b0000_0001]
    var r = BitReader(Span(data), BitOrder.MSB_FIRST)
    assert_true(r.read_bit())     # bit 7
    assert_false(r.read_bit())    # bit 6
    assert_true(r.read_bit())     # bit 5
    assert_true(r.read_bit())     # bit 4
    assert_false(r.read_bit())    # bit 3
    assert_true(r.read_bit())     # bit 2
    assert_false(r.read_bit())    # bit 1
    assert_false(r.read_bit())    # bit 0
    assert_equal(r.bit_pos(), 8)
    # The next read crosses into byte 1 at its most significant bit (clear),
    # then the remaining seven bits spell 0b000_0001.
    assert_false(r.read_bit())    # byte 1, bit 7
    assert_equal(r.read_bits(7), UInt64(1))   # byte 1, bits 6..0
    assert_false(r.has_bits())


def test_bitreader_lsb_first_visits_lsb() raises:
    # Byte 0 = 0b1011_0100; LSB_FIRST visits bit 0..bit 7 (0,0,1,0,1,1,0,1).
    var data: List[UInt8] = [0b1011_0100, 0b0000_0001]
    var r = BitReader(Span(data), BitOrder.LSB_FIRST)
    assert_false(r.read_bit())    # bit 0
    assert_false(r.read_bit())    # bit 1
    assert_true(r.read_bit())     # bit 2
    # bits 3..7 of byte 0, least significant first -> 0b10110 = 22
    assert_equal(r.read_bits(5), UInt64(0b10110))
    assert_equal(r.bit_pos(), 8)
    # Crossing into byte 1 at its least significant bit.
    assert_true(r.read_bit())     # byte 1, bit 0


def test_bitreader_read_bits_up_to_64() raises:
    var data: List[UInt8] = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
    var full = BitReader(Span(data), BitOrder.MSB_FIRST)
    # A single 64-bit read spans all eight bytes in order.
    assert_equal(full.read_bits(64), UInt64(0x0123_4567_89AB_CDEF))
    assert_false(full.has_bits())
    assert_equal(full.bit_pos(), 64)

    var split = BitReader(Span(data), BitOrder.MSB_FIRST)
    assert_equal(split.read_bits(8), UInt64(0x01))
    assert_equal(split.read_bits(16), UInt64(0x2345))
    assert_equal(split.read_bits(32), UInt64(0x6789_ABCD))
    assert_equal(split.read_bits(8), UInt64(0xEF))


def test_bitreader_align_to_next_byte() raises:
    var data: List[UInt8] = [0xFF, 0x01]
    var r = BitReader(Span(data), BitOrder.MSB_FIRST)
    assert_equal(r.read_bits(3), UInt64(0b111))
    assert_equal(r.bit_pos(), 3)
    r.align()
    assert_equal(r.bit_pos(), 8)
    # The next byte reads exactly; alignment consumed the rest of byte 0.
    assert_equal(r.read_bits(8), UInt64(0x01))
    assert_false(r.has_bits())

    # align on an already aligned reader is a no-op.
    var aligned = BitReader(Span(data), BitOrder.MSB_FIRST)
    aligned.align()
    assert_equal(aligned.bit_pos(), 0)


def test_bitreader_align_clamps_at_end() raises:
    # A non-whole-byte buffer: 16 bits total, advance to position 9, then align
    # would jump past the last bit and must clamp to the total bit count.
    var data: List[UInt8] = [0xFF, 0x01]
    var r = BitReader(Span(data), BitOrder.MSB_FIRST)
    # The first 9 MSB-first bits are eight 1-bits from 0xFF then a 0-bit from
    # the top of 0x01: 0b1_1111_1110.
    assert_equal(r.read_bits(9), UInt64(0b1_1111_1110))
    assert_equal(r.bit_pos(), 9)
    assert_equal(r.bits_left(), 7)
    r.align()
    assert_equal(r.bit_pos(), 16)
    assert_true(r.bits_left() >= 0)
    assert_equal(r.bits_left(), 0)
    # Aligning again stays clamped and never makes bits_left negative.
    r.align()
    assert_equal(r.bit_pos(), 16)
    assert_true(r.bits_left() >= 0)

    # A single byte, advance to 3, align clamps to 8.
    var one: List[UInt8] = [0xFF]
    var single = BitReader(Span(one), BitOrder.MSB_FIRST)
    _ = single.read_bits(3)
    single.align()
    assert_equal(single.bit_pos(), 8)
    assert_true(single.bits_left() >= 0)


def test_bitreader_eof_atomic() raises:
    var data: List[UInt8] = [0xFF]
    var r = BitReader(Span(data), BitOrder.MSB_FIRST)
    assert_equal(r.read_bits(4), UInt64(0xF))
    assert_equal(r.bit_pos(), 4)

    # Only 4 bits remain; an 8-bit read must raise EOF and consume nothing.
    var caught = False
    try:
        _ = r.read_bits(8)
    except e:
        caught = True
        assert_equal(e.kind, BitErrorKind.EOF)
        assert_equal(e.op, "read_bits")
    assert_true(caught)
    assert_equal(r.bit_pos(), 4)
    assert_equal(r.bits_left(), 4)
    # The reader is unchanged, so a retry with a smaller count succeeds.
    assert_equal(r.read_bits(4), UInt64(0xF))
    assert_false(r.has_bits())

    # read_bit at exhaustion also raises EOF and leaves the position unchanged.
    caught = False
    try:
        _ = r.read_bit()
    except e:
        caught = True
        assert_equal(e.kind, BitErrorKind.EOF)
    assert_true(caught)
    assert_equal(r.bit_pos(), 8)


def test_bitreader_count_range_raises() raises:
    var data: List[UInt8] = [0xFF]
    var r = BitReader(Span(data), BitOrder.MSB_FIRST)

    var caught = False
    var kind = BitErrorKind.OTHER
    var op = ""
    try:
        _ = r.read_bits(0)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)
    assert_equal(op, "read_bits")

    caught = False
    try:
        _ = r.read_bits(65)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = r.read_bits(-1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    # A rejected count does not advance the reader.
    assert_equal(r.bit_pos(), 0)


def test_bitreader_pos_and_left_accounting() raises:
    var data: List[UInt8] = [0x11, 0x22, 0x33]
    var r = BitReader(Span(data), BitOrder.MSB_FIRST)
    assert_equal(r.bit_pos(), 0)
    assert_equal(r.bits_left(), 24)
    assert_true(r.has_bits())

    _ = r.read_bits(5)
    assert_equal(r.bit_pos(), 5)
    assert_equal(r.bits_left(), 19)

    _ = r.read_bit()
    assert_equal(r.bit_pos(), 6)
    assert_equal(r.bits_left(), 18)

    r.align()
    assert_equal(r.bit_pos(), 8)
    assert_equal(r.bits_left(), 16)

    _ = r.read_bits(16)
    assert_equal(r.bit_pos(), 24)
    assert_equal(r.bits_left(), 0)
    assert_false(r.has_bits())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
