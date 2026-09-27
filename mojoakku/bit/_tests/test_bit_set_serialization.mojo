# Concern: `BitSet` byte serialisation — `to_bytes` and `from_bytes`
# (docs block in `../bit_set.mojo`; contract: `_dev/DESIGN.md` § "Release 2
# additions").
#
# The fixed layout is little-endian, LSB-first, minimal length: byte 0 bit 0 is
# bit index 0, and the length is `ceil(len / 8)` (0 bytes for the empty set).
#
# Covers: the empty set serialises to 0 bytes; bit 0 -> [1]; bit 7 -> [0x80];
# bit 8 -> [0, 1]; the 63/64 word-boundary crossing; `from_bytes` reverses
# `to_bytes` exactly (`from_bytes(to_bytes(x)) == x`) for several hand-checked
# sets; an empty span and an all-zero span decode to the empty set; and
# `from_bytes` reads byte `i` bit `j` as index `i * 8 + j`.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from bit import BitSet


def ints_of(*values: Int) -> List[Int]:
    var out = List[Int]()
    for v in values:
        out.append(v)
    return out^


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


def bits_of(*indices: Int) raises -> BitSet:
    var out = BitSet()
    for i in indices:
        out.set(i)
    return out^


def test_bitset_to_bytes_empty_is_zero_bytes() raises:
    var empty = BitSet()
    assert_equal(empty.to_bytes(), bytes_of())
    assert_equal(len(empty.to_bytes()), 0)


def test_bitset_to_bytes_single_bits() raises:
    # Bit 0 is byte 0 bit 0 (LSB-first): a single byte 1.
    var bit0 = BitSet()
    bit0.set(0)
    assert_equal(bit0.to_bytes(), bytes_of(UInt8(1)))
    assert_equal(len(bit0.to_bytes()), 1)

    # Bit 7 is the top bit of the first byte: 0x80.
    var bit7 = BitSet()
    bit7.set(7)
    assert_equal(bit7.to_bytes(), bytes_of(UInt8(0x80)))

    # Bit 8 starts byte 1: minimal length is 2 bytes, low byte zero.
    var bit8 = BitSet()
    bit8.set(8)
    assert_equal(bit8.to_bytes(), bytes_of(UInt8(0), UInt8(1)))
    assert_equal(len(bit8.to_bytes()), 2)


def test_bitset_to_bytes_word_boundary_crossing() raises:
    # Bit 63 is the top bit of byte 7; bit 64 is bit 0 of byte 8.
    var high = BitSet()
    high.set(63)
    var high_bytes = high.to_bytes()
    assert_equal(len(high_bytes), 8)          # ceil(64 / 8)
    assert_equal(high_bytes[0], UInt8(0))
    assert_equal(high_bytes[7], UInt8(0x80))

    var next = BitSet()
    next.set(64)
    var next_bytes = next.to_bytes()
    assert_equal(len(next_bytes), 9)          # ceil(65 / 8)
    assert_equal(next_bytes[7], UInt8(0))
    assert_equal(next_bytes[8], UInt8(1))

    # Both bits at once: byte 7 carries 0x80 and byte 8 carries 0x01.
    var both = BitSet()
    both.set(63)
    both.set(64)
    var both_bytes = both.to_bytes()
    assert_equal(len(both_bytes), 9)
    assert_equal(both_bytes[7], UInt8(0x80))
    assert_equal(both_bytes[8], UInt8(1))


def test_bitset_from_bytes_lsb_first() raises:
    # byte 0 bit 1 -> index 1; byte 1 bit 0 -> index 8.
    var data: List[UInt8] = [UInt8(0b0000_0010), UInt8(0b0000_0001)]
    var decoded = BitSet.from_bytes(Span(data))
    assert_equal(decoded.to_list(), ints_of(1, 8))


def test_bitset_from_bytes_roundtrip() raises:
    var sample = bits_of(0, 3, 8, 63, 64, 130)
    var encoded = sample.to_bytes()
    var decoded = BitSet.from_bytes(Span(encoded))
    assert_equal(decoded.to_list(), sample.to_list())

    var single = bits_of(7)
    var single_bytes = single.to_bytes()
    var single_decoded = BitSet.from_bytes(Span(single_bytes))
    assert_equal(single_decoded.to_list(), ints_of(7))

    var empty = BitSet()
    var empty_bytes = empty.to_bytes()
    var empty_decoded = BitSet.from_bytes(Span(empty_bytes))
    assert_true(empty_decoded.is_empty())


def test_bitset_from_bytes_empty_and_zero_spans() raises:
    var empty: List[UInt8] = []
    var decoded = BitSet.from_bytes(Span(empty))
    assert_true(decoded.is_empty())
    assert_equal(decoded.count(), 0)
    assert_equal(decoded.to_list(), ints_of())

    # A span of zero bytes holds no set bit and decodes to the empty set.
    var zeros: List[UInt8] = [UInt8(0), UInt8(0)]
    var from_zeros = BitSet.from_bytes(Span(zeros))
    assert_true(from_zeros.is_empty())
    assert_equal(from_zeros.to_list(), ints_of())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
