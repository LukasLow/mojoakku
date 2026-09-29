# Concern: `BitSet` indexing and the single-bit mutators — LSB-first,
# zero-based indexing and `test` / `set` / `clear` / `toggle` / `set_to`
# (docs block in `../bit_set.mojo`).
#
# Covers: index 0 is the least significant bit of word 0 and grows through
# word 1 at index 64; `test` is total (False at or beyond `len`, no error);
# `set` / `clear` / `toggle` / `set_to` set and clear the addressed bit;
# `clear` / `set_to(false)` past the end are no-ops; a negative index raises
# `RANGE` for every one of the five documented methods.
#
# LSB-first indexing is asserted behaviourally (set(0) makes bit 0 set and
# leaves bit 63 clear; set(64) moves to the next word), not against storage
# internals.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitSet, BitErrorKind


def test_bitset_lsb_first_indexing() raises:
    # index 0 is bit 0 of word 0, not bit 63.
    var bits = BitSet()
    bits.set(0)
    assert_true(bits.test(0))
    assert_false(bits.test(63))
    assert_equal(len(bits), 1)
    assert_equal(bits.count(), 1)
    assert_true(bits.find_next(0) == 0)

    # index 64 is bit 0 of word 1 (the first bit of the next 64-bit word).
    var next_word = BitSet()
    next_word.set(64)
    assert_true(next_word.test(64))
    assert_false(next_word.test(0))
    assert_false(next_word.test(63))
    assert_equal(len(next_word), 65)
    assert_equal(next_word.count(), 1)
    assert_true(next_word.find_next(0) == 64)


def test_bitset_test_is_total_false_beyond_len() raises:
    # A not-yet-set bit at or beyond `len` is False, never an error.
    var bits = BitSet()
    assert_false(bits.test(0))
    assert_false(bits.test(63))
    assert_false(bits.test(1000))
    bits.set(5)
    assert_true(bits.test(5))
    assert_false(bits.test(6))
    assert_false(bits.test(1000))


def test_bitset_set_clear_toggle() raises:
    var bits = BitSet()
    bits.set(3)
    assert_true(bits.test(3))
    bits.clear(3)
    assert_false(bits.test(3))

    bits.toggle(4)
    assert_true(bits.test(4))
    bits.toggle(4)
    assert_false(bits.test(4))

    # A clear past the end is a defined no-op, not an error.
    bits.clear(999)
    assert_equal(bits.count(), 0)


def test_bitset_set_to() raises:
    var bits = BitSet()
    bits.set_to(7, True)
    assert_true(bits.test(7))
    bits.set_to(7, False)
    assert_false(bits.test(7))
    assert_equal(bits.count(), 0)
    # set_to(False) past the end is the same no-op as clear.
    bits.set_to(999, False)
    assert_equal(len(bits), 0)


def test_bitset_negative_index_raises_range() raises:
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
        bits.clear(-1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        bits.toggle(-1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        bits.set_to(-1, True)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)

    caught = False
    try:
        _ = bits.test(-1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, BitErrorKind.RANGE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
