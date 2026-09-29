# Concern: `BitSet` growth and shrink — the word-list allocation contract
# (docs block in `../bit_set.mojo`).
#
# Covers: `set` grows the word list to cover the highest touched index and
# leaves capacity a multiple of 64; `reserve(bits)` ensures at least `bits`
# addressable bits without changing `len`/`count` (and a non-positive `bits`
# is a no-op); `clear` never shrinks capacity implicitly; `shrink()` releases
# trailing all-zero words down to what `_len` needs without changing
# `len`/`count`. A very large index is documented to request a large
# allocation with no release-1 cap; it is not exercised here.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitSet


def test_bitset_growth_on_set() raises:
    var bits = BitSet()
    assert_equal(bits.capacity(), 0)
    bits.set(0)
    # One 64-bit word covers index 0.
    assert_true(bits.capacity() >= 64)
    assert_equal(bits.capacity() % 64, 0)
    var after_first = bits.capacity()

    # An index beyond the current capacity grows the word list.
    bits.set(200)
    assert_true(bits.capacity() > after_first)
    assert_true(bits.capacity() >= 201)
    assert_equal(bits.capacity() % 64, 0)
    assert_true(bits.test(200))


def test_bitset_reserve_is_a_hint() raises:
    var bits = BitSet()
    bits.reserve(500)
    assert_true(bits.capacity() >= 500)
    # reserve never changes the logical length or cardinality.
    assert_equal(len(bits), 0)
    assert_equal(bits.count(), 0)

    # A non-positive reserve is a no-op.
    var cap = bits.capacity()
    bits.reserve(0)
    bits.reserve(-10)
    assert_equal(bits.capacity(), cap)


def test_bitset_no_implicit_shrink_on_clear() raises:
    var bits = BitSet()
    bits.set(200)
    var cap = bits.capacity()
    bits.clear(200)
    # Clearing the only set bit resets len but keeps capacity.
    assert_equal(len(bits), 0)
    assert_equal(bits.count(), 0)
    assert_equal(bits.capacity(), cap)


def test_bitset_shrink_frees_trailing_words() raises:
    var bits = BitSet()
    bits.set_range(0, 200)
    # Capacity is at least the 201 bits touched, a multiple of 64 (a doubling
    # policy is allowed, so only the lower bound is asserted).
    assert_true(bits.capacity() >= 256)
    bits.clear_range(100, 200)
    var cap_before = bits.capacity()
    assert_true(cap_before >= 256)
    # len is 100 and every word above it is zero, so shrink can release them.
    bits.shrink()
    var cap_after = bits.capacity()
    assert_true(cap_after < cap_before)
    # shrink never changes len or count.
    assert_equal(len(bits), 100)
    assert_equal(bits.count(), 100)
    assert_true(bits.test(99))
    assert_false(bits.test(100))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
