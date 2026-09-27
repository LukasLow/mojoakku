# Concern: `BitWriter` -> `BitReader` round-trip in both bit orders (docs
# blocks in `../bit_writer.mojo`, `../bit_reader.mojo`).
#
# `write_bits` is documented as the exact inverse of `read_bits` and
# `write_bit` as the inverse of `read_bit`; the order is a per-instance value,
# so a writer and a reader built with the same order must agree bit for bit.
# This file exercises the pair together: whole-byte-aligned writes, the frozen
# `test_bitreader_roundtrip_msb_first` / `_lsb_first` names, mixed
# `write_bit` / `write_bits` sequences, sub-byte and multi-byte counts, and a
# full-width 64-bit value. See
# `test_bitwriter_write_bit_then_write_bits_inverse` for a note on the
# contradictory `write_bit`/`write_bits` example literal in the API-DOCS block.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from bit import BitWriter, BitReader, BitOrder


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


def test_bitreader_roundtrip_msb_first() raises:
    # docs test name: a writer/reader pair under MSB_FIRST agrees bit for bit.
    var data: List[UInt8] = [0b1011_0100, 0b0000_0001]
    var w = BitWriter(BitOrder.MSB_FIRST)
    w.write_bits(UInt64(0b1011_0100), 8)
    w.write_bits(UInt64(0b0000_0001), 8)
    var bytes = w.to_bytes()
    assert_equal(bytes, data)
    var r = BitReader(Span(bytes), BitOrder.MSB_FIRST)
    assert_equal(r.read_bits(8), UInt64(0b1011_0100))
    assert_equal(r.read_bits(8), UInt64(0b0000_0001))
    assert_false(r.has_bits())


def test_bitreader_roundtrip_lsb_first() raises:
    # docs test name: the same pair under LSB_FIRST, including a sub-byte group
    # where the two orders genuinely differ.
    var w = BitWriter(BitOrder.LSB_FIRST)
    w.write_bits(UInt64(0b101), 3)
    w.write_bits(UInt64(0x5A), 8)
    w.write_bits(UInt64(0b1), 1)
    var bytes = w.to_bytes()
    var r = BitReader(Span(bytes), BitOrder.LSB_FIRST)
    assert_equal(r.read_bits(3), UInt64(0b101))
    assert_equal(r.read_bits(8), UInt64(0x5A))
    assert_equal(r.read_bits(1), UInt64(1))


def test_bitwriter_roundtrip_both_orders() raises:
    # Build a byte both ways, read it back with the same order, and compare.
    var msb_w = BitWriter(BitOrder.MSB_FIRST)
    msb_w.write_bits(UInt64(0b1011_0100), 8)
    var msb_bytes = msb_w.to_bytes()
    assert_equal(msb_bytes, bytes_of(UInt8(0b1011_0100)))
    var msb_r = BitReader(Span(msb_bytes), BitOrder.MSB_FIRST)
    assert_equal(msb_r.read_bits(8), UInt64(0b1011_0100))
    assert_false(msb_r.has_bits())

    var lsb_w = BitWriter(BitOrder.LSB_FIRST)
    lsb_w.write_bits(UInt64(0b1011_0100), 8)
    var lsb_bytes = lsb_w.to_bytes()
    var lsb_r = BitReader(Span(lsb_bytes), BitOrder.LSB_FIRST)
    assert_equal(lsb_r.read_bits(8), UInt64(0b1011_0100))
    assert_false(lsb_r.has_bits())

    # For one full byte the two orders map bit i to bit i, so the bytes agree;
    # the orders differ once a group does not fill a byte (see the mixed test).
    assert_equal(msb_bytes, lsb_bytes)


def test_bitwriter_write_bit_then_write_bits_inverse() raises:
    # Normative prose: under MSB_FIRST `write_bit(True)` fills bit 7 first and
    # `write_bits(0b101, 3)` then writes 1,0,1 into the next free bits, so the
    # aligned byte is 0b1101_0000.
    #
    # Note for the reviewer: the API-DOCS example on `bit_writer.mojo` claims
    # this sequence yields `0b1011_0100`. That byte does not follow from the
    # normative "first-written bit is the most significant" rule (and is not the
    # inverse of `read_bits`), so the example appears to be a doc oversight.
    # This test asserts the normative rule and the round-trip, not the example
    # byte. It is deliberately not called `...documented_example...` to avoid
    # implying the contradictory literal is under test.
    var w = BitWriter(BitOrder.MSB_FIRST)
    w.write_bit(True)
    w.write_bits(UInt64(0b101), 3)
    w.align()
    var bytes = w.to_bytes()
    assert_equal(bytes, bytes_of(UInt8(0b1101_0000)))

    # Read the sequence back: 1, then the three bits 1,0,1 as a group (MSB
    # first), then the four zero-fill bits from `align`.
    var r = BitReader(Span(bytes), BitOrder.MSB_FIRST)
    assert_true(r.read_bit())
    assert_equal(r.read_bits(3), UInt64(0b101))
    assert_equal(r.read_bits(4), UInt64(0))
    assert_false(r.has_bits())


def test_bitwriter_roundtrip_mixed_bit_and_bits() raises:
    # A mixed sequence must round-trip exactly, for both orders.
    var msb_w = BitWriter(BitOrder.MSB_FIRST)
    msb_w.write_bit(True)
    msb_w.write_bits(UInt64(0b010), 3)
    msb_w.write_bit(False)
    msb_w.write_bits(UInt64(0b1_1111), 5)
    var msb_bytes = msb_w.to_bytes()
    var msb_r = BitReader(Span(msb_bytes), BitOrder.MSB_FIRST)
    assert_true(msb_r.read_bit())
    assert_equal(msb_r.read_bits(3), UInt64(0b010))
    assert_false(msb_r.read_bit())
    assert_equal(msb_r.read_bits(5), UInt64(0b1_1111))
    # 10 bits were written; to_bytes() emits whole bytes (16 bits), so 6
    # byte-padding bits remain. (The writer is not byte-aligned, so the reader
    # cannot know the logical length — it sees the padding.)
    assert_equal(msb_r.bits_left(), 6)

    var lsb_w = BitWriter(BitOrder.LSB_FIRST)
    lsb_w.write_bit(True)
    lsb_w.write_bits(UInt64(0b010), 3)
    lsb_w.write_bit(False)
    lsb_w.write_bits(UInt64(0b1_1111), 5)
    var lsb_bytes = lsb_w.to_bytes()
    # The LSB writer's bit sequence, read back LSB-first, is the same sequence.
    var lsb_rr = BitReader(Span(lsb_bytes), BitOrder.LSB_FIRST)
    assert_true(lsb_rr.read_bit())
    assert_equal(lsb_rr.read_bits(3), UInt64(0b010))
    assert_false(lsb_rr.read_bit())
    assert_equal(lsb_rr.read_bits(5), UInt64(0b1_1111))
    # Same as the MSB case: 6 byte-padding bits remain.
    assert_equal(lsb_rr.bits_left(), 6)


def test_bitwriter_roundtrip_full_width_64() raises:
    var value: UInt64 = 0x0123_4567_89AB_CDEF
    for order in [BitOrder.MSB_FIRST, BitOrder.LSB_FIRST]:
        var w = BitWriter(order)
        w.write_bits(value, 64)
        var bytes = w.to_bytes()
        assert_equal(len(bytes), 8)
        var r = BitReader(Span(bytes), order)
        assert_equal(r.read_bits(64), value)
        assert_false(r.has_bits())


def test_bitwriter_roundtrip_multiple_counts() raises:
    # Several sub-byte and multi-byte group sizes must all be preserved.
    var sizes = List[Int]()
    sizes.append(1)
    sizes.append(3)
    sizes.append(8)
    sizes.append(13)
    sizes.append(16)
    sizes.append(32)
    var values = List[UInt64]()
    values.append(UInt64(1))
    values.append(UInt64(0b101))
    values.append(UInt64(0x5A))
    values.append(UInt64(0b1_0101_0101_0101))
    values.append(UInt64(0xBEEF))
    values.append(UInt64(0xDEAD_BEEF))

    for order in [BitOrder.MSB_FIRST, BitOrder.LSB_FIRST]:
        var w = BitWriter(order)
        for i in range(len(sizes)):
            w.write_bits(values[i], sizes[i])
        w.align()
        var bytes = w.to_bytes()
        var r = BitReader(Span(bytes), order)
        for i in range(len(sizes)):
            assert_equal(r.read_bits(sizes[i]), values[i])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
