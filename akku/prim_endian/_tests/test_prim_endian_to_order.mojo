# Concern: `to_order` — convert a host-order value into a named byte order
# (docs block in `../to_order.mojo`).
#
# Covers: BIG on a little host swaps; LITTLE is the no-op on a little host;
# NATIVE is always identity; a one-byte carrier is a no-op for every order;
# the result is the swap exactly when `order` differs from the host order;
# and from_order(to_order(x, order), order) round-trips.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_endian import EndianOrder, host_order, swap_bytes, to_order, from_order


def test_to_order_big_on_little_host_swaps() raises:
    # On a little-endian host, BIG is the opposite order and swaps the bytes.
    if host_order() == EndianOrder.LITTLE:
        assert_equal(to_order(UInt16(0x0102), EndianOrder.BIG), UInt16(0x0201))
        assert_equal(
            to_order(UInt32(0x01020304), EndianOrder.BIG), UInt32(0x04030201)
        )


def test_to_order_matches_host_order_rule() raises:
    # The documented rule: identity when order == host order, otherwise the
    # bytes are swapped. Checked for both concrete orders on any host.
    var host = host_order()
    var x: UInt32 = 0x01020304
    var little = to_order(x, EndianOrder.LITTLE)
    var big = to_order(x, EndianOrder.BIG)
    if host == EndianOrder.LITTLE:
        assert_equal(little, x)
        assert_equal(big, swap_bytes(x))
    else:
        assert_equal(little, swap_bytes(x))
        assert_equal(big, x)


def test_to_order_native_identity() raises:
    # NATIVE resolves to the host order, so it is always the identity.
    assert_equal(to_order(UInt16(0xBEEF), EndianOrder.NATIVE), UInt16(0xBEEF))
    assert_equal(
        to_order(UInt64(0x0123456789ABCDEF), EndianOrder.NATIVE),
        UInt64(0x0123456789ABCDEF),
    )


def test_to_order_one_byte_noop() raises:
    # A one-byte carrier is a no-op for every order.
    assert_equal(to_order(UInt8(0x7A), EndianOrder.LITTLE), UInt8(0x7A))
    assert_equal(to_order(UInt8(0x7A), EndianOrder.BIG), UInt8(0x7A))
    assert_equal(to_order(UInt8(0x7A), EndianOrder.NATIVE), UInt8(0x7A))
    assert_equal(to_order(Int8(-1), EndianOrder.BIG), Int8(-1))


def test_to_order_roundtrip_from_order() raises:
    # from_order is the inverse of to_order for every explicit order.
    var x: UInt32 = 0x01020304
    for order in [EndianOrder.LITTLE, EndianOrder.BIG]:
        assert_equal(from_order(to_order(x, order), order), x)
    assert_equal(from_order(to_order(x, EndianOrder.NATIVE), EndianOrder.NATIVE), x)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
