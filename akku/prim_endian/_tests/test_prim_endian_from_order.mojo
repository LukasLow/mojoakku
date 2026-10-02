# Concern: `from_order` — convert a value that is in a named byte order back
# to host order (docs block in `../from_order.mojo`).
#
# Covers: the inverse direction of to_order; a no-op when order == host order;
# NATIVE is always identity; a one-byte carrier is a no-op for every order;
# and off-host it matches swap_bytes.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_endian import EndianOrder, host_order, swap_bytes, from_order, to_order


def test_from_order_matches_host_order_rule() raises:
    # Identity when order == host order, otherwise the bytes are swapped.
    var host = host_order()
    var x: UInt32 = 0xDEADBEEF
    var little = from_order(x, EndianOrder.LITTLE)
    var big = from_order(x, EndianOrder.BIG)
    if host == EndianOrder.LITTLE:
        assert_equal(little, x)
        assert_equal(big, swap_bytes(x))
    else:
        assert_equal(little, swap_bytes(x))
        assert_equal(big, x)


def test_from_order_off_host_matches_swap_bytes() raises:
    # Explicitly exercise the swap branch by choosing the order opposite to
    # the host.
    var host = host_order()
    var other = EndianOrder.BIG if host == EndianOrder.LITTLE else EndianOrder.LITTLE
    var x: UInt16 = 0x0102
    assert_equal(from_order(x, other), swap_bytes(x))


def test_from_order_native_identity() raises:
    # NATIVE resolves to the host order, so it is always the identity.
    assert_equal(from_order(UInt16(0xBEEF), EndianOrder.NATIVE), UInt16(0xBEEF))
    assert_equal(
        from_order(UInt64(0x0123456789ABCDEF), EndianOrder.NATIVE),
        UInt64(0x0123456789ABCDEF),
    )


def test_from_order_one_byte_noop() raises:
    # A one-byte carrier is a no-op for every order.
    assert_equal(from_order(UInt8(0x7A), EndianOrder.LITTLE), UInt8(0x7A))
    assert_equal(from_order(UInt8(0x7A), EndianOrder.BIG), UInt8(0x7A))
    assert_equal(from_order(UInt8(0x7A), EndianOrder.NATIVE), UInt8(0x7A))


def test_from_order_inverse_of_to_order() raises:
    # The two operations are documented as inverses for every explicit order.
    var x: UInt32 = 0x01020304
    for order in [EndianOrder.LITTLE, EndianOrder.BIG]:
        assert_equal(from_order(to_order(x, order), order), x)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
