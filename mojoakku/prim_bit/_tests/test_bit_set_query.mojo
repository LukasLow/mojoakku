# Concern: `BitSet` queries — the three deliberately distinct quantities
# `len` / `capacity` / `count`, the emptiness/cardinality predicates
# `is_empty` / `any` / `none` / `all`, and equality (docs block in
# `../bit_set.mojo`).
#
# Covers: `len(bs)` is the logical length (highest set index + 1, 0 when
# empty); `capacity()` is addressable bits allocated (a multiple of 64);
# `count()` is cardinality; `__init__(capacity=...)` reserves room without
# setting a logical length; `all` of an empty set is True (the standard C++
# convention) and `all` only ranges over the logical bits 0..len-1; equality
# ignores capacity and `_len` below the highest set bit.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitSet


def test_bitset_len_capacity_count() raises:
    var bits = BitSet()
    assert_equal(len(bits), 0)
    assert_equal(bits.count(), 0)
    assert_equal(bits.capacity(), 0)

    bits.set(0)
    assert_equal(len(bits), 1)
    assert_equal(bits.count(), 1)
    # Setting one bit allocates at least one 64-bit word.
    assert_true(bits.capacity() >= 64)

    # The three quantities must not collapse into one another: the highest set
    # index (3) is neither the cardinality (2) nor the capacity (>= 64).
    var two = BitSet()
    two.set(0)
    two.set(3)
    assert_equal(len(two), 4)
    assert_equal(two.count(), 2)
    assert_true(two.capacity() >= 64)
    assert_true(two.capacity() != len(two))
    assert_true(two.count() != len(two))


def test_bitset_capacity_ctor_is_a_hint_only() raises:
    # __init__(capacity=...) reserves room up front; it is a growth hint, not a
    # logical length, so len and count stay 0.
    var bits = BitSet(capacity=128)
    assert_equal(len(bits), 0)
    assert_equal(bits.count(), 0)
    # A capacity hint guarantees at least the requested room; an implementation
    # may round up, so assert the lower bound, not an exact value.
    assert_true(bits.capacity() >= 128)
    assert_true(bits.is_empty())


def test_bitset_emptiness_predicates() raises:
    var bits = BitSet()
    assert_true(bits.is_empty())
    assert_true(bits.none())
    assert_false(bits.any())
    # all of an empty set is True (the standard convention).
    assert_true(bits.all())

    bits.set(0)
    assert_false(bits.is_empty())
    assert_false(bits.none())
    assert_true(bits.any())
    # len is 1 and bit 0 is set, so every logical bit is set.
    assert_true(bits.all())

    bits.set(1)
    # len is 2 and both bits are set.
    assert_true(bits.all())
    bits.clear(0)
    # Bit 1 remains set (len is 2), but bit 0 is now clear, so not every
    # logical bit 0..len-1 is set.
    assert_false(bits.all())


def test_bitset_equality_ignores_capacity() raises:
    var small = BitSet()
    small.set(5)
    var large = BitSet(capacity=4096)
    large.set(5)
    # Same set bits; the larger reserved capacity does not participate.
    assert_true(small == large)
    assert_true(large == small)

    # A different set bit is unequal.
    var other = BitSet()
    other.set(6)
    assert_false(small == other)


def test_bitset_write_to_set_notation() raises:
    # write_to prints a compact set notation, e.g. {0, 3, 5}.
    var bits = BitSet()
    bits.set(0)
    bits.set(3)
    bits.set(5)
    var text = String(bits)
    assert_true("0" in text)
    assert_true("3" in text)
    assert_true("5" in text)
    assert_true("{" in text)
    assert_true("}" in text)
    # An empty set prints the empty notation, never a stray index.
    var empty = BitSet()
    var empty_text = String(empty)
    assert_true("{" in empty_text)
    assert_true("}" in empty_text)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
