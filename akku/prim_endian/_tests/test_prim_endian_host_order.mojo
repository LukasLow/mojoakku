# Concern: `host_order` — the host's byte order, resolved at compile time
# (docs block in `../host_order.mojo`).
#
# Covers: the result is LITTLE or BIG (never a third value) and equals
# EndianOrder.NATIVE. `host_order` is a total query: it raises nothing.

from std.testing import assert_equal, assert_true, TestSuite
from akku.prim_endian import EndianOrder, host_order


def test_host_order_is_little_or_big() raises:
    # The result is one of the two concrete members; mixed-endian is not a
    # supported target, so no third value exists.
    var order = host_order()
    assert_true(order == EndianOrder.LITTLE or order == EndianOrder.BIG)


def test_host_order_equals_native() raises:
    # host_order() equals the compile-time NATIVE alias.
    assert_equal(host_order(), EndianOrder.NATIVE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
