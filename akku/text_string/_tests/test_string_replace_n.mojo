# Concern: `replace_n` — replace the first `count` non-overlapping occurrences
# (or all) of a needle in a copy (docs block in `../replace_n.mojo`).
#
# Covers: a positive `count` replaces only the leftmost occurrences; a negative
# `count` replaces all; `count == 0` returns the input unchanged; `count` larger
# than the number of occurrences replaces all it can find; matching is
# leftmost-non-overlapping; an empty `old` raises BAD_RANGE; the result is a
# fresh owned String independent of the inputs.

from std.testing import assert_true, TestSuite
from akku.text_string import replace_n, StringErrorKind


def test_replace_n_counted() raises:
    assert_true(replace_n("aaa", "a", "b", 2) == "bba")


def test_replace_n_negative_all() raises:
    assert_true(replace_n("aaa", "a", "b", -1) == "bbb")


def test_replace_n_zero_unchanged() raises:
    assert_true(replace_n("aaa", "a", "b", 0) == "aaa")


def test_replace_n_count_beyond_occurrences() raises:
    # A count larger than the number of matches replaces them all, not an error.
    assert_true(replace_n("ab", "a", "x", 100) == "xb")


def test_replace_n_nonoverlapping() raises:
    # Overlapping potential matches advance past each replacement.
    assert_true(replace_n("aaa", "aa", "b", -1) == "ba")


def test_replace_n_empty_old_raises_bad_range() raises:
    var kind = StringErrorKind.INVALID_UTF8
    var caught = False
    try:
        _ = replace_n("abc", "", "x", -1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_true(kind == StringErrorKind.BAD_RANGE)


def test_replace_n_returns_owned() raises:
    var src = String("aaa")
    var out = replace_n(src, "a", "b", 1)
    assert_true(out == "baa")
    assert_true(src == "aaa")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
