# Concern: `EndianOrder` — the byte-order value type (docs block in
# `../endian_order.mojo`; `Conventions` in `../__init__.mojo`).
#
# Covers: LITTLE and BIG are distinct and the complete concrete set; equality
# compares the discriminant only; NATIVE is the compile-time alias resolved to
# the host order and equals host_order(); `print(order)` shows the symbolic
# name, never the number.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_endian import EndianOrder, host_order


def test_endian_order_distinct() raises:
    # LITTLE and BIG are the two concrete members; each equals itself and
    # differs from the other, in both directions.
    assert_true(EndianOrder.LITTLE == EndianOrder.LITTLE)
    assert_true(EndianOrder.BIG == EndianOrder.BIG)
    assert_false(EndianOrder.LITTLE == EndianOrder.BIG)
    assert_false(EndianOrder.BIG == EndianOrder.LITTLE)


def test_endian_order_eq_discriminant_only() raises:
    # __eq__ compares the discriminant only: two values naming the same order
    # are interchangeable, a different order is not.
    var a = EndianOrder.LITTLE
    var b = EndianOrder.LITTLE
    var c = EndianOrder.BIG
    assert_true(a == b)
    assert_false(a == c)
    # NATIVE resolves to one of the two concrete members.
    assert_true(EndianOrder.NATIVE == EndianOrder.LITTLE or EndianOrder.NATIVE == EndianOrder.BIG)


def test_endian_order_native_equals_host_order() raises:
    # NATIVE is the compile-time alias for the host order; host_order() reports
    # the same value.
    assert_equal(EndianOrder.NATIVE, host_order())


def test_endian_order_writable() raises:
    # Writable shows the symbolic name, never the numeric _id.
    assert_true("LITTLE" in String(EndianOrder.LITTLE))
    assert_true("BIG" in String(EndianOrder.BIG))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
