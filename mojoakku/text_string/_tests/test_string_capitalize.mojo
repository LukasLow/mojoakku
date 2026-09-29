# Concern: `capitalize` — uppercase the first codepoint, lowercase the rest
# (docs block in `../capitalize.mojo`).
#
# Covers: the first codepoint is upper-cased and the tail lower-cased; an empty
# input returns an empty String; an already-capitalized input is unchanged; an
# all-uppercase input is lowered except the first letter; a non-ASCII first
# codepoint is handled; the result is a fresh owned String independent of the
# input.

from std.testing import assert_true, TestSuite
from text_string import capitalize


def test_capitalize_basic() raises:
    assert_true(capitalize("abc") == "Abc")


def test_capitalize_upper_tail() raises:
    assert_true(capitalize("hELLO") == "Hello")
    assert_true(capitalize("HELLO") == "Hello")


def test_capitalize_empty() raises:
    assert_true(capitalize("") == "")


def test_capitalize_already_capital() raises:
    assert_true(capitalize("Abc") == "Abc")


def test_capitalize_first_non_ascii() raises:
    var r = capitalize("élan")
    # The first codepoint is upper-cased, the remainder lower-cased.
    assert_true(String(r) == "Élan")


def test_capitalize_returns_owned() raises:
    # The returned String is independent of the input.
    var src = String("abc")
    var out = capitalize(src)
    assert_true(out == "Abc")
    assert_true(src == "abc")
    out += "!"
    assert_true(out == "Abc!")
    assert_true(src == "abc")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
