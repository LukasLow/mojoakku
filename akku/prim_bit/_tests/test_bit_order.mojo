# Concern: `BitOrder` — the explicit bit sequence passed to `BitReader` /
# `BitWriter` (docs block in `../bit_order.mojo`).
#
# Covers: the two members are distinct; equality is discriminant-only;
# `print(order)` shows the symbolic name, never the number; a reader/writer
# reports back the order it was constructed with, so order is a per-instance
# value, never a global switch.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_bit import BitOrder, BitReader, BitWriter


def test_bit_order_distinct() raises:
    assert_true(BitOrder.MSB_FIRST == BitOrder.MSB_FIRST)
    assert_true(BitOrder.LSB_FIRST == BitOrder.LSB_FIRST)
    assert_false(BitOrder.MSB_FIRST == BitOrder.LSB_FIRST)
    assert_false(BitOrder.LSB_FIRST == BitOrder.MSB_FIRST)


def test_bit_order_eq() raises:
    # __eq__ compares _id only; equal members are interchangeable.
    var a = BitOrder.MSB_FIRST
    var b = BitOrder.MSB_FIRST
    var c = BitOrder.LSB_FIRST
    assert_true(a == b)
    assert_false(a == c)


def test_bit_order_writable() raises:
    assert_true("MSB_FIRST" in String(BitOrder.MSB_FIRST))
    assert_true("LSB_FIRST" in String(BitOrder.LSB_FIRST))


def test_bit_order_reported_by_reader() raises:
    # Order is a stored value, returned by the reader's `order()` accessor.
    var data: List[UInt8] = [0b0000_0001]
    var msb_reader = BitReader(Span(data), BitOrder.MSB_FIRST)
    var lsb_reader = BitReader(Span(data), BitOrder.LSB_FIRST)
    assert_equal(msb_reader.order(), BitOrder.MSB_FIRST)
    assert_equal(lsb_reader.order(), BitOrder.LSB_FIRST)


def test_bit_order_reported_by_writer() raises:
    var msb_writer = BitWriter(BitOrder.MSB_FIRST)
    var lsb_writer = BitWriter(BitOrder.LSB_FIRST)
    assert_equal(msb_writer.order(), BitOrder.MSB_FIRST)
    assert_equal(lsb_writer.order(), BitOrder.LSB_FIRST)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
