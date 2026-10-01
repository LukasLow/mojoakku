# Concern: `swap_bytes` — reverse an integral value's byte order (docs block
# in `../swap_bytes.mojo`).
#
# Covers: known UInt16/UInt32/UInt64 reversals; involution for a multi-byte
# carrier; a signed carrier reverses the same bits; a one-byte carrier
# (UInt8/Int8) is returned unchanged.

from std.testing import assert_equal, assert_true, TestSuite
from akku.prim_endian import swap_bytes


def test_swap_uint16_known() raises:
    assert_equal(swap_bytes(UInt16(0x0102)), UInt16(0x0201))
    assert_equal(swap_bytes(UInt16(0xABCD)), UInt16(0xCDAB))


def test_swap_uint32_known() raises:
    assert_equal(swap_bytes(UInt32(0x01020304)), UInt32(0x04030201))
    assert_equal(swap_bytes(UInt32(0xDEADBEEF)), UInt32(0xEFBEADDE))


def test_swap_uint64_known() raises:
    assert_equal(swap_bytes(UInt64(0x0102030405060708)), UInt64(0x0807060504030201))
    assert_equal(
        swap_bytes(UInt64(0x0123456789ABCDEF)), UInt64(0xEFCDAB8967452301)
    )


def test_swap_involution() raises:
    # Reversing twice restores the original bit pattern.
    var x16: UInt16 = 0x1234
    assert_equal(swap_bytes(swap_bytes(x16)), x16)
    var x32: UInt32 = 0x12345678
    assert_equal(swap_bytes(swap_bytes(x32)), x32)
    var x64: UInt64 = 0x0123456789ABCDEF
    assert_equal(swap_bytes(swap_bytes(x64)), x64)


def test_swap_signed_carrier_same_bits() raises:
    # The carrier may be signed; the bytes are reversed bit-for-bit, so a
    # signed value reverses the same as its unsigned bit pattern.
    assert_equal(swap_bytes(Int16(0x0102)), Int16(0x0201))
    assert_equal(swap_bytes(Int32(0x01020304)), Int32(0x04030201))
    # The explicit dtype parameter may also be named.
    assert_equal(swap_bytes[DType.int16](Int16(0x0102)), Int16(0x0201))


def test_swap_one_byte_identity() raises:
    # A one-byte carrier is already order-independent.
    assert_equal(swap_bytes(UInt8(0x01)), UInt8(0x01))
    assert_equal(swap_bytes(UInt8(0xFF)), UInt8(0xFF))
    assert_equal(swap_bytes(Int8(0x7F)), Int8(0x7F))
    assert_equal(swap_bytes(Int8(-1)), Int8(-1))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
