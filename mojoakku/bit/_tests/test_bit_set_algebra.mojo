# Concern: `BitSet` set algebra — the four materialising operators
# (`union` / `intersection` / `difference` / `symmetric_difference`), the four
# in-place `*_with` methods, and the relation queries (`is_subset_of` /
# `is_superset_of` / `is_disjoint`) (docs block in `../bit_set.mojo`).
#
# Covers: a hand-checked pair A={0, 2, 3, 70}, B={2, 5, 65, 70}; each
# materialising operator returns a new set and leaves the receiver and the
# argument unchanged; the documented `_len` rules for each `*_with` (union
# grows to the max of the two lengths, the other three collapse to the highest
# surviving set bit) and that capacity is never reduced; subset/superset/disjoint
# including the empty-set edges (the empty set is a subset of everything and
# disjoint with everything).

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from bit import BitSet


def ints_of(*values: Int) -> List[Int]:
    var out = List[Int]()
    for v in values:
        out.append(v)
    return out^


def bits_of(*indices: Int) raises -> BitSet:
    var out = BitSet()
    for i in indices:
        out.set(i)
    return out^


def test_bitset_union() raises:
    var a = bits_of(0, 2, 3, 70)
    var b = bits_of(2, 5, 65, 70)
    var u = a.union(b.copy())
    assert_equal(u.to_list(), ints_of(0, 2, 3, 5, 65, 70))
    # The receiver and argument are unchanged.
    assert_equal(a.to_list(), ints_of(0, 2, 3, 70))
    assert_equal(b.to_list(), ints_of(2, 5, 65, 70))


def test_bitset_intersection() raises:
    var a = bits_of(0, 2, 3, 70)
    var b = bits_of(2, 5, 65, 70)
    var i = a.intersection(b.copy())
    assert_equal(i.to_list(), ints_of(2, 70))
    assert_equal(a.to_list(), ints_of(0, 2, 3, 70))
    assert_equal(b.to_list(), ints_of(2, 5, 65, 70))


def test_bitset_difference() raises:
    var a = bits_of(0, 2, 3, 70)
    var b = bits_of(2, 5, 65, 70)
    # difference is A \ B: bits in the receiver that are absent from other.
    var d = a.difference(b.copy())
    assert_equal(d.to_list(), ints_of(0, 3))
    assert_equal(a.to_list(), ints_of(0, 2, 3, 70))
    assert_equal(b.to_list(), ints_of(2, 5, 65, 70))


def test_bitset_symmetric_difference() raises:
    var a = bits_of(0, 2, 3, 70)
    var b = bits_of(2, 5, 65, 70)
    # XOR: bits in exactly one of the two sets.
    var x = a.symmetric_difference(b.copy())
    assert_equal(x.to_list(), ints_of(0, 3, 5, 65))
    assert_equal(a.to_list(), ints_of(0, 2, 3, 70))
    assert_equal(b.to_list(), ints_of(2, 5, 65, 70))


def test_bitset_with_ops_len_growth() raises:
    # union_with grows self to cover other's highest set bit.
    var u = bits_of(0)
    var u_cap = u.capacity()
    u.union_with(bits_of(2, 5))
    assert_equal(u.to_list(), ints_of(0, 2, 5))
    assert_equal(len(u), 6)      # max(len({0}) = 1, len({2, 5}) = 6)
    assert_true(u.capacity() >= u_cap)

    # intersection_with keeps only shared bits; len collapses to the highest
    # surviving set bit.
    var i = bits_of(2, 70)
    i.intersection_with(bits_of(2, 5, 65))
    assert_equal(i.to_list(), ints_of(2))
    assert_equal(len(i), 3)      # highest surviving bit 2 -> 3

    # difference_with removes other's bits; len collapses likewise.
    var d = bits_of(0, 2, 3, 70)
    d.difference_with(bits_of(2, 70, 65))
    assert_equal(d.to_list(), ints_of(0, 3))
    assert_equal(len(d), 4)      # highest surviving bit 3 -> 4

    # symmetric_difference_with keeps the XOR; len collapses likewise.
    var x = bits_of(0, 2, 3, 70)
    x.symmetric_difference_with(bits_of(2, 5, 65, 70))
    assert_equal(x.to_list(), ints_of(0, 3, 5, 65))
    assert_equal(len(x), 66)     # highest surviving bit 65 -> 66

    # Capacity is never reduced by an in-place operation.
    var grow_before = bits_of(2, 70)
    var before = grow_before.capacity()
    grow_before.intersection_with(bits_of(2))
    assert_true(grow_before.capacity() >= before)
    assert_equal(len(grow_before), 3)


def test_bitset_subset_superset_disjoint() raises:
    var small = bits_of(0, 2, 3)
    var big = bits_of(0, 2, 3, 5, 65, 70)
    assert_true(small.is_subset_of(big.copy()))
    assert_false(big.is_subset_of(small.copy()))
    assert_true(big.is_superset_of(small.copy()))
    assert_false(small.is_superset_of(big.copy()))

    # A set is a subset and a superset of itself.
    assert_true(small.is_subset_of(small.copy()))
    assert_true(small.is_superset_of(small.copy()))

    assert_true(bits_of(0, 2).is_disjoint(bits_of(1, 3)))
    assert_false(bits_of(0, 2).is_disjoint(bits_of(2, 3)))


def test_bitset_empty_set_edges() raises:
    var empty = BitSet()
    var any_set = bits_of(0, 5, 70)

    # The empty set is a subset of everything (including itself) and every set
    # is a superset of the empty set.
    assert_true(empty.is_subset_of(any_set.copy()))
    assert_true(empty.is_subset_of(BitSet()))
    assert_true(any_set.is_superset_of(BitSet()))
    assert_true(empty.is_superset_of(BitSet()))

    # An empty set is disjoint with everything, in both directions.
    assert_true(empty.is_disjoint(any_set.copy()))
    assert_true(any_set.is_disjoint(BitSet()))
    assert_true(empty.is_disjoint(BitSet()))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
