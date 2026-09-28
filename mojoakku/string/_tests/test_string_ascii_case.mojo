# Concern: `to_ascii_lower` / `to_ascii_upper` — deterministic ASCII-only case
# fast paths (docs blocks in `../to_ascii_lower.mojo`, `../to_ascii_upper.mojo`).
#
# Covers: only ASCII A-Z / a-z are mapped; every other byte is copied unchanged,
# so non-ASCII text (including already-encoded multi-byte codepoints) is left
# byte-for-byte identical; the byte length is always preserved; mixed input maps
# only the ASCII letters; the result is a fresh owned String; the two functions
# are not Unicode case mapping.

from std.testing import assert_equal, assert_true, TestSuite
from string import to_ascii_lower, to_ascii_upper


def test_to_ascii_lower_letters() raises:
    assert_true(to_ascii_lower("AbC") == "abc")
    assert_true(to_ascii_lower("ABC") == "abc")
    assert_true(to_ascii_lower("abc") == "abc")


def test_to_ascii_lower_non_ascii_unchanged() raises:
    # Non-ASCII bytes must be copied unchanged, never case-mapped.
    assert_true(to_ascii_lower("ÄBC") == "Äbc")
    assert_true(to_ascii_lower("é") == "é")


def test_to_ascii_lower_length_preserved() raises:
    var src = String("ÄbC")
    assert_equal(to_ascii_lower(src).byte_length(), src.byte_length())


def test_to_ascii_upper_letters() raises:
    assert_true(to_ascii_upper("AbC") == "ABC")
    assert_true(to_ascii_upper("abc") == "ABC")
    assert_true(to_ascii_upper("ABC") == "ABC")


def test_to_ascii_upper_non_ascii_unchanged() raises:
    assert_true(to_ascii_upper("äbc") == "äBC")
    assert_true(to_ascii_upper("é") == "é")


def test_to_ascii_upper_length_preserved() raises:
    var src = String("äbC")
    assert_equal(to_ascii_upper(src).byte_length(), src.byte_length())


def test_to_ascii_returns_owned() raises:
    var src = String("AbC")
    var lo = to_ascii_lower(src)
    assert_true(lo == "abc")
    assert_true(src == "AbC")
    lo += "!"
    assert_true(src == "AbC")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
