# Concern: `BitSet` range mutations — `set_range` / `clear_range` /
# `toggle_range` over an inclusive `[lo, hi]`, `clear_all`, and the range
# error contract (docs block in `../bit_set.mojo`).
#
# Covers: an inclusive range spanning a 64-bit word boundary sets exactly the
# addressed bits across both words; `set_range(0, 0)` is a one-bit range and
# `lo == hi == 64` is the first bit of word 1; `toggle_range` flips and grows
# only where it sets; `clear_range` beyond `len` is a no-op that leaves `_len`
# at the highest remaining set bit (0 when none remain); `clear_all` clears
# every bit, resets `len` to 0 and keeps capacity; a negative `lo` raises
# `RANGE`; `lo > hi` raises `BAD_RANGE`.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from bit import BitSet, BitErrorKind


def ints_of(*values: Int) -> List[Int]:
    var out = List[Int]()
    for v in values:
        out.append(v)
    return out^


def test_bitset_set_range_word_boundary() raises:
    # [62, 66] spans the 64-bit word boundary: bits 62, 63 in word 0 and bits
    # 0, 1 in word 1 (index 64, 65).
    var bits = BitSet()
    bits.set_range(62, 66)
    assert_false(bits.test(61))
    assert_true(bits.test(62))
    assert_true(bits.test(63))
    assert_true(bits.test(64))
    assert_true(bits.test(65))
    # Inclusive [62, 66] sets bit 66 too; bit 67 is beyond the addressed range.
    assert_true(bits.test(66))
    assert_false(bits.test(67))
    assert_equal(bits.count(), 5)
    assert_equal(len(bits), 67)
    assert_equal(bits.to_list(), ints_of(62, 63, 64, 65, 66))


def test_bitset_set_range_edges() raises:
    # lo == hi is a valid one-bit range, both at word 0 bit 0 and at the first
    # bit of the next word.
    var low = BitSet()
    low.set_range(0, 0)
    assert_true(low.test(0))
    assert_equal(low.count(), 1)
    assert_equal(len(low), 1)

    var high = BitSet()
    high.set_range(64, 64)
    assert_true(high.test(64))
    assert_false(high.test(63))
    assert_equal(high.count(), 1)
    assert_equal(len(high), 65)


def test_bitset_toggle_range_flips_and_grows() raises:
    var bits = BitSet()
    bits.set_range(2, 3)
    bits.toggle_range(3, 5)
    # 2 stays set; 3 flips off; 4 and 5 flip on.
    assert_true(bits.test(2))
    assert_false(bits.test(3))
    assert_true(bits.test(4))
    assert_true(bits.test(5))
    assert_equal(bits.count(), 3)
    assert_equal(len(bits), 6)
    # Toggling the same range again restores the original bits.
    bits.toggle_range(3, 5)
    assert_equal(bits.to_list(), ints_of(2, 3))


def test_bitset_clear_range_beyond_len() raises:
    # clear_range with hi >= len is defined: it clears every in-range bit and
    # leaves _len at the highest remaining set bit (0 when none remain).
    var bits = BitSet()
    bits.set_range(0, 70)
    assert_equal(len(bits), 71)
    bits.clear_range(10, 1000)
    # Bits 10..70 are cleared; 0..9 remain, so len is 10.
    assert_equal(len(bits), 10)
    assert_equal(bits.count(), 10)
    assert_false(bits.test(10))
    assert_true(bits.test(9))

    # A clear that removes every remaining bit resets len to 0.
    bits.clear_range(0, 1000)
    assert_equal(len(bits), 0)
    assert_equal(bits.count(), 0)


def test_bitset_clear_all_resets_len() raises:
    var bits = BitSet()
    bits.set_range(0, 200)
    var cap = bits.capacity()
    assert_true(len(bits) > 0)
    bits.clear_all()
    assert_equal(len(bits), 0)
    assert_equal(bits.count(), 0)
    assert_true(bits.is_empty())
    # Capacity is kept.
    assert_equal(bits.capacity(), cap)


def test_bitset_negative_lo_raises_range() raises:
    var bits = BitSet()

    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        bits.set_range(-1, 3)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        bits.clear_range(-1, 3)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        bits.toggle_range(-1, 3)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)


def test_bitset_reversed_range_raises_bad_range() raises:
    var bits = BitSet()

    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        bits.set_range(5, 3)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.BAD_RANGE)

    caught = False
    try:
        bits.clear_range(5, 3)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.BAD_RANGE)

    caught = False
    try:
        bits.toggle_range(5, 3)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.BAD_RANGE)


def test_bitset_negative_index_and_reverse_range_raise() raises:
    # The frozen combined name: a negative index/lo is RANGE, a backwards range
    # is BAD_RANGE (both on the addressing mutators).
    var bits = BitSet()

    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        bits.set(-1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        bits.set_range(-1, 4)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        bits.set_range(4, 1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.BAD_RANGE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
