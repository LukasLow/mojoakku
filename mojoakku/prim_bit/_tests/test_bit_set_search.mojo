# Concern: `BitSet` search and iteration — `find_next` (ascending, total) and
# `to_list` (docs block in `../bit_set.mojo`).
#
# Covers: `find_next(from_index)` returns the lowest set index `>= from_index`
# and ascends across a 64-bit word boundary; it returns `None` past the last
# set bit (an `Optional`, never a -1 sentinel); a negative `from_index` behaves
# as 0 rather than raising, so the iteration idiom `from_index = -1` needs no
# special first step; `find_next` on an empty set is `None`; `to_list` returns
# the set indices in strictly ascending order and an empty list for an empty
# set.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitSet


def ints_of(*values: Int) -> List[Int]:
    var out = List[Int]()
    for v in values:
        out.append(v)
    return out^


def test_bitset_find_next_ascending() raises:
    var bits = BitSet()
    bits.set(0)
    bits.set(3)
    bits.set(64)
    bits.set(130)
    assert_true(bits.find_next(0) == 0)
    assert_true(bits.find_next(1) == 3)
    assert_true(bits.find_next(3) == 3)
    assert_true(bits.find_next(4) == 64)
    assert_true(bits.find_next(64) == 64)
    assert_true(bits.find_next(65) == 130)
    assert_true(bits.find_next(130) == 130)
    assert_true(bits.find_next(131) == None)


def test_bitset_find_next_none_past_end() raises:
    var empty = BitSet()
    assert_true(empty.find_next(0) == None)
    assert_true(empty.find_next(1000) == None)

    var bits = BitSet()
    bits.set(5)
    assert_true(bits.find_next(5) == 5)
    assert_true(bits.find_next(6) == None)
    assert_true(bits.find_next(1000) == None)


def test_bitset_find_next_negative_is_zero() raises:
    # A negative from_index is defined as 0: find_next is a total query, so
    # the lowest set bit is returned, not an error and not -1.
    var bits = BitSet()
    bits.set(4)
    bits.set(70)
    assert_true(bits.find_next(-1) == 4)
    assert_true(bits.find_next(-100) == 4)
    # Empty set: the result is Optional None, never -1.
    var empty = BitSet()
    assert_true(empty.find_next(-1) == None)


def test_bitset_find_next_iteration_idiom() raises:
    # Ascending iteration with from_index = last_found + 1 and no special
    # first step, because a negative from_index is treated as 0.
    var bits = BitSet()
    bits.set(2)
    bits.set(9)
    bits.set(63)
    bits.set(64)
    var seen = List[Int]()
    var cursor = -1
    while True:
        var found = bits.find_next(cursor)
        if found == None:
            break
        var index = found.value()
        seen.append(index)
        cursor = index + 1
    assert_equal(seen, ints_of(2, 9, 63, 64))


def test_bitset_to_list_ordering() raises:
    var bits = BitSet()
    bits.set(130)
    bits.set(0)
    bits.set(64)
    bits.set(3)
    assert_equal(bits.to_list(), ints_of(0, 3, 64, 130))

    var empty = BitSet()
    assert_equal(empty.to_list(), ints_of())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
