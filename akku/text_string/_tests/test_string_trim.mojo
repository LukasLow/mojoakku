# Concern: `trim` — strip leading/trailing Unicode whitespace, or an explicit
# character SET (docs block in `../trim.mojo`).
#
# Covers: the one-argument form strips Unicode whitespace including NBSP
# (U+00A0) and U+3000, which the stdlib `strip` does NOT strip; tabs/CR/LF are
# stripped; inner whitespace is preserved; an all-whitespace input yields the
# empty view; an input with no surrounding whitespace is returned unchanged; the
# two-argument form treats `chars` as a SET (not a prefix/suffix), so any member
# codepoint is stripped from both ends; an empty `chars` set strips nothing.

from std.testing import assert_equal, assert_true, TestSuite
from akku.text_string import trim


def test_trim_ascii_whitespace() raises:
    assert_true(String(trim("  hi  ")) == "hi")
    assert_true(String(trim("\t\nhi\r\n")) == "hi")
    assert_true(String(trim("hi")) == "hi")


def test_trim_unicode_whitespace() raises:
    # NBSP (U+00A0) and U+3000 are stripped, unlike the stdlib's ASCII-only
    # `strip`.
    assert_true(String(trim("\u00A0hi\u00A0")) == "hi")
    assert_true(String(trim("\u3000hi\u3000")) == "hi")


def test_trim_preserves_inner_whitespace() raises:
    assert_true(String(trim("  a b  ")) == "a b")


def test_trim_all_whitespace_empty() raises:
    assert_equal(trim("   ").byte_length(), 0)
    assert_equal(trim("").byte_length(), 0)


def test_trim_chars_is_a_set() raises:
    # `chars` is a set of codepoints, not a prefix/suffix that must match whole.
    assert_true(String(trim("xxaxx", "x")) == "a")
    assert_true(String(trim("xyaxy", "xy")) == "a")


def test_trim_chars_empty_set_strips_nothing() raises:
    assert_true(String(trim("abc", "")) == "abc")
    assert_true(String(trim("  abc  ", "")) == "  abc  ")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
