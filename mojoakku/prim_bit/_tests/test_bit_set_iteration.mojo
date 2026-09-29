# Concern: `BitSet` full iteration over set bits — `for i in bits:` via the
# public `BitSetIter` (docs block in `../bit_set.mojo`; contract:
# `_dev/DESIGN.md` § "Release 2 additions").
#
# Covers: `for i in bits:` yields the set indices in strictly ascending order,
# equivalent to `to_list`; an empty set yields nothing (the loop body never
# runs); `BitSetIter` is the public iterator type behind `__iter__`, and its
# `__has_next__()` / `__next__()` pair drives a manual loop; and the snapshot
# semantics — the iterator copies the words at `__iter__` time, so mutating the
# set after obtaining the iterator, or inside the loop, does not change what the
# iterator yields.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitSet, BitSetIter


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


def test_bitset_iter_ascending() raises:
    # Inserted out of order; iteration must still ascend across a word boundary.
    var bits = bits_of(130, 0, 64, 3)
    var seen = List[Int]()
    for i in bits:
        seen.append(i)
    assert_equal(seen, ints_of(0, 3, 64, 130))
    # The iterator agrees with the bulk convenience.
    assert_equal(seen, bits.to_list())


def test_bitset_iter_empty_yields_nothing() raises:
    var empty = BitSet()
    var count = 0
    for i in empty:
        count += 1
        _ = i
    assert_equal(count, 0)

    # A set emptied again also yields nothing.
    var cleared = bits_of(1, 2, 3)
    cleared.clear_all()
    for i in cleared:
        count += 1
        _ = i
    assert_equal(count, 0)


def test_bitsetiter_protocol_manual_loop() raises:
    # `__iter__` returns the public `BitSetIter`, whose `__has_next__` /
    # `__next__` pair yields the same ascending indices.
    var bits = bits_of(2, 9, 63, 64)
    var it: BitSetIter = bits.__iter__()
    var seen = List[Int]()
    while it.__has_next__():
        seen.append(it.__next__())
    assert_equal(seen, ints_of(2, 9, 63, 64))


def test_bitset_iter_snapshot_after_iter() raises:
    # Snapshot semantics: obtain the iterator, then mutate the set. The iterator
    # must still yield the state captured at `__iter__` time.
    var bits = bits_of(0, 2, 4)
    var it: BitSetIter = bits.__iter__()
    bits.set(100)
    bits.clear(2)
    var seen = List[Int]()
    while it.__has_next__():
        seen.append(it.__next__())
    assert_equal(seen, ints_of(0, 2, 4))
    # The set itself did change; only the iterator is a snapshot.
    assert_true(bits.test(100))
    assert_false(bits.test(2))


def test_bitset_iter_snapshot_inside_loop() raises:
    # Mutating the set inside the loop is safe and deterministic: the iterator
    # never sees the bits added after `__iter__` ran.
    var bits = bits_of(0, 2, 4)
    var seen = List[Int]()
    for i in bits:
        seen.append(i)
        bits.set(100)
    assert_equal(seen, ints_of(0, 2, 4))
    assert_true(bits.test(100))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
