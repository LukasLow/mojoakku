# Concern: `format_string` — render text under a FormatSpec (docs block in
# `../format_string.mojo`).
#
# Covers: the text unchanged; left/center padding and a custom fill codepoint;
# width and precision measured in CODEPOINTS; codepoint-boundary-safe precision
# truncation of a multi-byte string; REPR quoting; and the documented
# TYPE_MISMATCH for numeric presentations and for sign/zero-pad on a string.
# The result is an owned String independent of the borrowed input.

from std.testing import assert_equal, assert_true, TestSuite
from akku.text_format import (
    FormatErrorKind,
    format_string,
    parse_format_spec,
)


def kind_of_string(text: String, value: StringSpan) raises -> FormatErrorKind:
    try:
        _ = format_string(value, parse_format_spec(text))
    except e:
        return e.kind
    return FormatErrorKind.TYPE_MISMATCH


def test_format_string_default_unchanged() raises:
    assert_equal(format_string("hello", parse_format_spec("")), "hello")
    assert_equal(format_string("", parse_format_spec("")), "")


def test_format_string_width_padding() raises:
    assert_equal(format_string("hi", parse_format_spec("<5")), "hi   ")
    assert_equal(format_string("hi", parse_format_spec(">5")), "   hi")
    assert_equal(format_string("hi", parse_format_spec("^5")), " hi  ")


def test_format_string_custom_fill_codepoint() raises:
    assert_equal(format_string("hi", parse_format_spec("*>5")), "***hi")
    # A non-ASCII fill codepoint (é, U+00E9) is one codepoint.
    assert_equal(format_string("hi", parse_format_spec("é>4")), "ééhi")


def test_format_string_precision_truncates_codepoints() raises:
    # "héllo" has 5 codepoints; precision 2 keeps the first two: "hé".
    assert_equal(format_string("héllo", parse_format_spec(".2")), "hé")


def test_format_string_precision_never_splits_codepoint() raises:
    # Truncating "é" (two bytes) at 1 codepoint keeps the whole codepoint, so the
    # result is valid UTF-8 and its byte length is 2, not 1.
    var out = format_string("é", parse_format_spec(".1"))
    assert_equal(out, "é")
    assert_equal(out.byte_length(), 2)
    assert_equal(out.count_codepoints(), 1)


def test_format_string_width_counts_codepoints_not_bytes() raises:
    # "é" is one codepoint but two bytes: width 3 pads to three codepoints.
    var out = format_string("é", parse_format_spec(">3"))
    assert_equal(out.count_codepoints(), 3)
    assert_equal(out, "  é")


def test_format_string_repr_quotes() raises:
    assert_equal(format_string("hi", parse_format_spec("r")), "'hi'")
    assert_equal(format_string("hi", parse_format_spec("")), "hi")


def test_format_string_sign_is_type_mismatch() raises:
    assert_equal(kind_of_string("+s", "x"), FormatErrorKind.TYPE_MISMATCH)


def test_format_string_zero_pad_is_type_mismatch() raises:
    assert_equal(kind_of_string("08s", "x"), FormatErrorKind.TYPE_MISMATCH)


def test_format_string_numeric_presentation_is_type_mismatch() raises:
    assert_equal(kind_of_string("d", "x"), FormatErrorKind.TYPE_MISMATCH)


def test_format_string_borrows_input() raises:
    # The input view stays valid; the result is a fresh owned String.
    var input = String("abc")
    var out = format_string(input, parse_format_spec(">5"))
    assert_equal(input, "abc")
    assert_equal(out, "  abc")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
