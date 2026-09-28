# Concern: `find` — the first occurrence of a needle as an Optional byte offset
# (docs block in `../find.mojo`).
#
# Covers: the first offset is returned as an Int inside Optional (NOT a -1
# sentinel); absence yields None; `start` shifts the search window; a `start`
# below 0 behaves as 0; a `start` past the end yields None; an empty needle
# matches at `start`; the offset counts UTF-8 bytes, not codepoints.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from string import find


def test_find_first_occurrence() raises:
    var r = find("hello world", "world")
    assert_true(r)
    assert_equal(r.value(), 6)


def test_find_returns_offset_not_sentinel() raises:
    # The hit is an Optional[Int] carrying the offset; not a bare -1 protocol.
    var r = find("abcabc", "bc")
    assert_true(r)
    assert_equal(r.value(), 1)


def test_find_absent_is_none() raises:
    # Absence is None, never a -1 sentinel.
    var r = find("hello", "zz")
    assert_false(r)


def test_find_start_offsets_search() raises:
    # A later start skips the earlier match.
    assert_equal(find("abab", "a").value(), 0)
    assert_equal(find("abab", "a", 1).value(), 2)
    assert_equal(find("abab", "a", 3).value(), 3)


def test_find_start_below_zero_behaves_as_zero() raises:
    assert_equal(find("abab", "a", -5).value(), 0)


def test_find_start_past_end_is_none() raises:
    assert_false(find("abc", "a", 10))


def test_find_empty_needle_matches_at_start() raises:
    assert_equal(find("abc", "").value(), 0)
    assert_equal(find("abc", "", 1).value(), 1)
    assert_equal(find("", "").value(), 0)


def test_find_offset_is_byte_offset() raises:
    # "é" is two UTF-8 bytes, so "l" starts at byte offset 2, not codepoint 1.
    assert_equal(find("él", "l").value(), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
