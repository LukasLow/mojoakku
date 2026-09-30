# Concern: the bitfield layer — `get_bits` and `set_bits` over an inclusive
# `[hi:lo]` field of a `UInt64` (docs blocks in `../get_bits.mojo`,
# `../set_bits.mojo`).
#
# Covers `get_bits`: a single-bit field (`hi == lo`), a field crossing a nibble
# boundary, and the full-width `[63:0]` case including the `hi == 63` mask
# special-case (a `1 << 64` shift would be undefined); `RANGE` for `lo < 0` or
# `hi > 63` and `BAD_RANGE` for `hi < lo`.
#
# Covers `set_bits`: insert then clear a field; bits outside `[hi:lo]` stay
# unchanged; a single-bit insert (`hi == lo` with field 0 or 1); a field that
# exactly fills its width passes; a field one bit too wide raises `OVERFLOW`
# with no truncation; `RANGE` / `BAD_RANGE` for the same bounds as `get_bits`.
#
# Field carriers are written as explicit `UInt64` values/hex to avoid any
# integer-literal type ambiguity.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_bit import get_bits, set_bits, BitErrorKind


def test_get_bits_single_bit_field() raises:
    # 0b1011_0100: bit 2 is 1, bit 4 is 1.
    var x: UInt64 = 0b1011_0100
    assert_equal(get_bits(x, 2, 2), UInt64(1))
    assert_equal(get_bits(x, 4, 4), UInt64(1))
    assert_equal(get_bits(x, 3, 3), UInt64(0))
    assert_equal(get_bits(x, 7, 7), UInt64(1))


def test_get_bits_crossing_nibble() raises:
    # 0b1011_0100 read as [5:2] crosses the nibble boundary: 0b1101 = 13.
    var x: UInt64 = 0b1011_0100
    assert_equal(get_bits(x, 5, 2), UInt64(0b1101))
    # [5:4] is 0b11 = 3; [7:4] is 0b1011 = 11 (a whole nibble).
    assert_equal(get_bits(x, 5, 4), UInt64(3))
    assert_equal(get_bits(x, 7, 4), UInt64(0b1011))


def test_get_bits_full_width() raises:
    # [63:0] returns the whole value; the hi == 63 mask case must not shift by
    # 64 (undefined), so it is exercised with bits in the top bytes set.
    var x: UInt64 = 0xFEDC_BA98_7654_3210
    assert_equal(get_bits(x, 63, 0), x)
    var top: UInt64 = 0x8000_0000_0000_0000
    assert_equal(get_bits(top, 63, 0), top)
    assert_equal(get_bits(top, 63, 63), UInt64(1))
    # The result is right-aligned: a high field never keeps its original place.
    assert_equal(get_bits(top, 63, 60), UInt64(0b1000))


def test_get_bits_out_of_range_raises() raises:
    var x: UInt64 = 0b1011_0100

    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        _ = get_bits(x, 4, -1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = get_bits(x, 64, 0)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)


def test_get_bits_reversed_raises() raises:
    var x: UInt64 = 0b1011_0100
    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        _ = get_bits(x, 2, 5)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.BAD_RANGE)


def test_set_bits_insert_clear() raises:
    var x: UInt64 = 0
    var y = set_bits(x, 3, 0, UInt64(0b1010))
    assert_equal(y, UInt64(0b1010))
    # field 0 clears the field.
    var z = set_bits(y, 3, 0, UInt64(0))
    assert_equal(z, UInt64(0))


def test_set_bits_preserves_surrounding() raises:
    # Start with bits outside [3:0] set; inserting must touch only [3:0].
    var x: UInt64 = 0b1111_0000
    var y = set_bits(x, 3, 0, UInt64(0b1010))
    assert_equal(y, UInt64(0b1111_1010))
    # Clearing [3:0] leaves the surrounding bits exactly as they were.
    var z = set_bits(y, 3, 0, UInt64(0))
    assert_equal(z, UInt64(0b1111_0000))


def test_set_bits_single_bit() raises:
    var x: UInt64 = 0
    var on = set_bits(x, 5, 5, UInt64(1))
    assert_equal(on, UInt64(0b0010_0000))
    var off = set_bits(on, 5, 5, UInt64(0))
    assert_equal(off, UInt64(0))
    # hi == lo == 63 is the top bit.
    var top = set_bits(x, 63, 63, UInt64(1))
    assert_equal(top, UInt64(0x8000_0000_0000_0000))


def test_set_bits_exact_capacity_ok() raises:
    # A field that exactly fills its width passes; no OVERFLOW.
    var x: UInt64 = 0
    # [7:4] is 4 bits wide; 0b1111 exactly fills it.
    var y = set_bits(x, 7, 4, UInt64(0b1111))
    assert_equal(y, UInt64(0b1111_0000))
    # [63:60] is the 4-bit top nibble; 0b1010 exactly fills it.
    var top = set_bits(x, 63, 60, UInt64(0b1010))
    assert_equal(top, UInt64(0xA000_0000_0000_0000))
    # A 1-bit field exactly accepts 1.
    assert_equal(set_bits(x, 0, 0, UInt64(1)), UInt64(1))


def test_set_bits_overflow_raises() raises:
    # [3:0] is 4 bits; 0b1_0000 has bit 4 set and does not fit.
    var x: UInt64 = 0
    var caught = False
    var kind = BitErrorKind.OTHER
    var op = ""
    try:
        _ = set_bits(x, 3, 0, UInt64(0b1_0000))
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, BitErrorKind.OVERFLOW)
    assert_equal(op, "set_bits")

    # A single-bit field only accepts 0 or 1.
    caught = False
    try:
        _ = set_bits(x, 5, 5, UInt64(2))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.OVERFLOW)


def test_set_bits_out_of_range_and_reversed_raise() raises:
    var x: UInt64 = 0

    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        _ = set_bits(x, 3, -1, UInt64(0))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = set_bits(x, 64, 0, UInt64(0))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = set_bits(x, 2, 5, UInt64(0))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.BAD_RANGE)


def test_get_set_roundtrip() raises:
    # A field extracted and re-inserted into a zero carrier reproduces the
    # field's placement.
    var x: UInt64 = 0xDEAD_BEEF_CAFE_BABE
    var field = get_bits(x, 23, 8)
    var rebuilt = set_bits(UInt64(0), 23, 8, field)
    assert_equal(get_bits(rebuilt, 23, 8), field)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
