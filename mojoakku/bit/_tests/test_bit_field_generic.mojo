# Concern: the generic bitfield layer — `get_bits` / `set_bits` over a
# `Scalar[dtype]` carrier for any unsigned integral `dtype` (docs blocks in
# `../get_bits.mojo`, `../set_bits.mojo`; contract: `_dev/DESIGN.md`
# § "Release 2 additions").
#
# The carrier is parameterized on `dtype: DType` (inferred from the argument, or
# passed explicitly as `get_bits[DType.uint8](...)`); the field bound is the
# carrier's own width, `hi <= bit_width - 1`. `UInt8` fields go to 7, `UInt16`
# to 15, `UInt32` to 31, `UInt64` to 63 — every existing `UInt64` call keeps its
# exact behaviour and error kinds.
#
# Covers: get_bits / set_bits on UInt8, UInt16, UInt32 and UInt64; the field
# value is returned in the carrier's own type; per-width bounds (UInt8 `hi <= 7`;
# `hi > 7` raises RANGE, likewise 15/31/63 for the wider carriers); the existing
# UInt64 edge behaviour (full-width `[63:0]` mask special-case, OVERFLOW on a
# too-wide field); a per-width get/set round-trip; and the explicit `[dtype]`
# parameter form.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from bit import get_bits, set_bits, BitErrorKind


def test_get_bits_uint8() raises:
    var x = UInt8(0b1011_0100)
    # `hi <= 7` is the UInt8 bound; the result comes back as a UInt8.
    assert_equal(get_bits(x, 7, 0), UInt8(0b1011_0100))
    assert_equal(get_bits(x, 5, 4), UInt8(0b11))
    assert_equal(get_bits(x, 2, 2), UInt8(1))
    assert_equal(get_bits(x, 7, 7), UInt8(1))
    # A field crossing the nibble boundary, right-aligned.
    assert_equal(get_bits(x, 5, 2), UInt8(0b1101))


def test_get_bits_uint16_uint32() raises:
    var x16 = UInt16(0xBEEF)
    assert_equal(get_bits(x16, 15, 8), UInt16(0xBE))
    assert_equal(get_bits(x16, 7, 0), UInt16(0xEF))
    assert_equal(get_bits(x16, 15, 0), UInt16(0xBEEF))

    var x32 = UInt32(0xDEAD_BEEF)
    assert_equal(get_bits(x32, 31, 16), UInt32(0xDEAD))
    assert_equal(get_bits(x32, 15, 0), UInt32(0xBEEF))
    assert_equal(get_bits(x32, 31, 0), UInt32(0xDEAD_BEEF))


def test_get_bits_uint64_unchanged() raises:
    # Every release-1 UInt64 call keeps its exact behaviour.
    var x: UInt64 = 0b1011_0100
    assert_equal(get_bits(x, 5, 2), UInt64(0b1101))
    assert_equal(get_bits(x, 7, 0), x)
    # The full-width `[63:0]` mask special-case (a `1 << 64` shift is avoided).
    var top: UInt64 = 0x8000_0000_0000_0000
    assert_equal(get_bits(top, 63, 0), top)
    assert_equal(get_bits(top, 63, 63), UInt64(1))


def test_get_bits_per_width_bounds_raise_range() raises:
    # The bound is the carrier width: UInt8 accepts hi <= 7, not 63.
    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        _ = get_bits(UInt8(0xFF), 8, 0)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = get_bits(UInt16(0xFFFF), 16, 0)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = get_bits(UInt32(0xFFFF_FFFF), 32, 0)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = get_bits(UInt64(0), 64, 0)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    # A negative lo is still RANGE, and a reversed range still BAD_RANGE.
    caught = False
    try:
        _ = get_bits(UInt8(0), 4, -1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = get_bits(UInt8(0), 2, 5)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.BAD_RANGE)


def test_set_bits_uint8() raises:
    # Insert then clear a 4-bit field: the result is a UInt8.
    var zero = UInt8(0)
    var y = set_bits(zero, 3, 0, UInt8(0b1010))
    assert_equal(y, UInt8(0b1010))
    assert_equal(set_bits(y, 3, 0, UInt8(0)), UInt8(0))
    # Bits outside [hi:lo] are preserved.
    assert_equal(set_bits(UInt8(0b1111_0000), 3, 0, UInt8(0b1010)), UInt8(0b1111_1010))
    # The top UInt8 bit is a valid single-bit field.
    assert_equal(set_bits(zero, 7, 7, UInt8(1)), UInt8(0b1000_0000))


def test_set_bits_uint16_uint32() raises:
    assert_equal(set_bits(UInt16(0), 15, 8, UInt16(0xBE)), UInt16(0xBE00))
    assert_equal(set_bits(UInt16(0xBEEF), 15, 8, UInt16(0)), UInt16(0x00EF))
    assert_equal(set_bits(UInt32(0), 31, 16, UInt32(0xDEAD)), UInt32(0xDEAD_0000))
    assert_equal(set_bits(UInt32(0xDEAD_BEEF), 31, 16, UInt32(0)), UInt32(0x0000_BEEF))


def test_set_bits_uint64_unchanged() raises:
    var x: UInt64 = 0
    assert_equal(set_bits(x, 3, 0, UInt64(0b1010)), UInt64(0b1010))
    # A 4-bit top-nibble field exactly fills [63:60].
    assert_equal(set_bits(x, 63, 60, UInt64(0b1010)), UInt64(0xA000_0000_0000_0000))
    assert_equal(set_bits(x, 63, 63, UInt64(1)), UInt64(0x8000_0000_0000_0000))


def test_set_bits_overflow_per_width() raises:
    # UInt8: [3:0] is 4 bits; 0b1_0000 has bit 4 set and does not fit.
    var caught = False
    var kind = BitErrorKind.OTHER
    var op = ""
    try:
        _ = set_bits(UInt8(0), 3, 0, UInt8(0b1_0000))
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, BitErrorKind.OVERFLOW)
    assert_equal(op, "set_bits")

    # UInt16: [7:0] is 8 bits; 0x100 does not fit.
    caught = False
    try:
        _ = set_bits(UInt16(0), 7, 0, UInt16(0x100))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.OVERFLOW)

    # UInt64: the release-1 overflow case is unchanged.
    caught = False
    try:
        _ = set_bits(UInt64(0), 3, 0, UInt64(0b1_0000))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.OVERFLOW)

    # An out-of-width field bound is RANGE, not OVERFLOW.
    caught = False
    try:
        _ = set_bits(UInt8(0), 8, 0, UInt8(0))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)


def test_get_set_roundtrip_per_width() raises:
    # Extract a field and re-insert it into a zero carrier: the field is
    # reproduced in place.
    var x8 = UInt8(0b1011_0100)
    assert_equal(set_bits(UInt8(0), 5, 2, get_bits(x8, 5, 2)), UInt8(0b0011_0100))

    var x16 = UInt16(0xBEEF)
    assert_equal(set_bits(UInt16(0), 15, 8, get_bits(x16, 15, 8)), UInt16(0xBE00))

    var x32 = UInt32(0xDEAD_BEEF)
    assert_equal(set_bits(UInt32(0), 31, 16, get_bits(x32, 31, 16)), UInt32(0xDEAD_0000))

    var x64: UInt64 = 0xDEAD_BEEF_CAFE_BABE
    var field = get_bits(x64, 23, 8)
    # Bits 8..23 of 0x…CAFE_BABE are 0xFEBA (byte 1 = 0xFE, byte 0's high byte =
    # 0xBA); re-inserted at [23:8] the carrier is 0x00FEBA00.
    assert_equal(field, UInt64(0xFEBA))
    assert_equal(set_bits(UInt64(0), 23, 8, field), UInt64(0x00FEBA00))


def test_explicit_dtype_parameter() raises:
    # The `[dtype: DType]` parameter is part of the public surface and can be
    # supplied explicitly instead of being inferred from the carrier.
    assert_equal(get_bits[DType.uint8](UInt8(0b1011_0100), 5, 4), UInt8(0b11))
    assert_equal(set_bits[DType.uint8](UInt8(0), 3, 0, UInt8(0b1010)), UInt8(0b1010))
    assert_equal(get_bits[DType.uint64](UInt64(0xFF), 7, 0), UInt64(0xFF))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
