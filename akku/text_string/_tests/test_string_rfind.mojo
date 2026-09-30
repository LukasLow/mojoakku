# Concern: `rfind` — the last occurrence of a needle at or after `start`, as an
# Optional byte offset (docs block in `../rfind.mojo`).
#
# Covers: the highest offset at or after `start` is returned inside Optional;
# absence is None (no -1 sentinel); `start` is a lower bound so matches wholly
# before it are ignored; `start` past the end is None.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_string import rfind


def test_rfind_last_occurrence() raises:
    var r = rfind("abab", "a")
    assert_true(r)
    assert_equal(r.value(), 2)


def test_rfind_absent_is_none() raises:
    assert_false(rfind("hello", "zz"))
    assert_false(rfind("", "a"))


def test_rfind_start_lower_bound() raises:
    # start is a lower bound: matches wholly below it are ignored.
    assert_equal(rfind("abab", "a", 2).value(), 2)
    assert_equal(rfind("abab", "b", 3).value(), 3)
    # All matches are below start -> None.
    assert_false(rfind("abab", "a", 4))
    assert_false(rfind("abab", "b", 4))


def test_rfind_start_past_end_is_none() raises:
    assert_false(rfind("abc", "a", 10))


def test_rfind_offset_is_byte_offset() raises:
    assert_equal(rfind("él", "l").value(), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
