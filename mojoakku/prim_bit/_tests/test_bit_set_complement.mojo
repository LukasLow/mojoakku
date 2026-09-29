# Concern: `BitSet` complement over an explicit universe — `complement`
# (materialising) and `complement_with` (in place) (docs block in
# `../bit_set.mojo`; contract: `_dev/DESIGN.md` § "Release 2 additions").
#
# Covers: `complement(width)` returns a new set of the bits `0..width-1` that
# are NOT set in the receiver, leaving the receiver unchanged;
# `complement_with(width)` does the same in place; `width == 0` yields the empty
# set; a negative `width` raises `RANGE`; `width < len` drops every receiver bit
# at or above `width` (they are outside the universe and become 0);
# `width > len` complements against a universe larger than the set, so every
# extra bit becomes set; and the double-complement identity
# `complement(complement(x, w), w) == x` holds for every bit below `w`.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitSet, BitErrorKind


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


def test_bitset_complement_hand_checked() raises:
    # Universe 0..5; A = {1, 3, 5}; the complement within 6 bits is {0, 2, 4}.
    var a = bits_of(1, 3, 5)
    var c = a.complement(6)
    assert_equal(c.to_list(), ints_of(0, 2, 4))
    assert_equal(c.count(), 3)
    # The materialising form leaves the receiver unchanged.
    assert_equal(a.to_list(), ints_of(1, 3, 5))
    assert_equal(a.count(), 3)


def test_bitset_complement_with_in_place() raises:
    var a = bits_of(1, 3, 5)
    a.complement_with(6)
    assert_equal(a.to_list(), ints_of(0, 2, 4))
    # The highest set bit is 4, so the logical length is 5.
    assert_equal(len(a), 5)


def test_bitset_complement_width_zero() raises:
    var a = bits_of(0, 2)
    var c = a.complement(0)
    assert_true(c.is_empty())
    assert_equal(c.count(), 0)
    assert_equal(c.to_list(), ints_of())
    # The receiver is unchanged.
    assert_equal(a.to_list(), ints_of(0, 2))

    var b = bits_of(0, 2)
    b.complement_with(0)
    assert_true(b.is_empty())
    assert_equal(b.count(), 0)


def test_bitset_complement_negative_width_raises() raises:
    var a = bits_of(0)

    var caught = False
    var kind = BitErrorKind.OTHER
    try:
        _ = a.complement(-1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    var op = ""
    try:
        a.complement_with(-1)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)
    assert_equal(op, "complement_with")


def test_bitset_complement_narrower_than_set() raises:
    # width < len: bits at or above width are outside the universe and drop out
    # of the result (they become 0, not "not set in the universe").
    var a = bits_of(0, 2, 70)      # len 71
    var c = a.complement(4)        # universe 0..3; receiver bits inside {0, 2}
    assert_equal(c.to_list(), ints_of(1, 3))
    assert_false(c.test(70))
    # The materialising form leaves the receiver unchanged.
    assert_equal(a.to_list(), ints_of(0, 2, 70))


def test_bitset_complement_wider_than_set() raises:
    # width > len: the universe reaches past the set's highest bit, so every
    # bit from len up to width-1 is set in the complement.
    var a = bits_of(1, 3)          # len 4
    var c = a.complement(8)
    assert_equal(c.to_list(), ints_of(0, 2, 4, 5, 6, 7))
    assert_equal(len(c), 8)        # highest set bit 7 -> len 8

    # The empty set complements to every bit of the stated universe.
    var empty = BitSet()
    var full = empty.complement(5)
    assert_equal(full.to_list(), ints_of(0, 1, 2, 3, 4))


def test_bitset_complement_roundtrip_identity() raises:
    # Hand-checked: A = {0, 3, 5, 7} within width 8; complementing twice
    # reproduces A exactly.
    var a = bits_of(0, 3, 5, 7)
    var twice = a.complement(8).complement(8)
    assert_equal(twice.to_list(), ints_of(0, 3, 5, 7))

    # The same identity holds for the in-place form.
    var b = bits_of(2, 9)
    b.complement_with(16)
    b.complement_with(16)
    assert_equal(b.to_list(), ints_of(2, 9))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
