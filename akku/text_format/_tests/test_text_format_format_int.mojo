# Concern: `format_int` — render an integer under a FormatSpec (docs block in
# `../format_int.mojo`).
#
# Covers: the default decimal form; the radix presentations (b/o/d/x/X) agreeing
# with hex/oct/bin; alternate form prefixes; sign control; sign-aware zero pad;
# width/alignment in codepoints; minimum-digit precision; grouping (',' and '_');
# the CHAR presentation; and the documented TYPE_MISMATCH on an incompatible
# presentation. All results are owned Strings.

from std.testing import assert_equal, assert_true, TestSuite
from akku.text_format import (
    FormatErrorKind,
    format_int,
    parse_format_spec,
)


def kind_of_int(text: String, value: Int) raises -> FormatErrorKind:
    try:
        _ = format_int(value, parse_format_spec(text))
    except e:
        return e.kind
    return FormatErrorKind.TYPE_MISMATCH


def test_format_int_default() raises:
    assert_equal(format_int(42, parse_format_spec("")), "42")
    assert_equal(format_int(0, parse_format_spec("")), "0")


def test_format_int_radix_matches_hex_oct_bin() raises:
    assert_equal(format_int(255, parse_format_spec("x")), "ff")
    assert_equal(format_int(255, parse_format_spec("X")), "FF")
    assert_equal(format_int(8, parse_format_spec("o")), "10")
    assert_equal(format_int(5, parse_format_spec("b")), "101")
    assert_equal(format_int(255, parse_format_spec("d")), "255")


def test_format_int_alternate_form_prefixes() raises:
    assert_equal(format_int(255, parse_format_spec("#x")), "0xff")
    assert_equal(format_int(5, parse_format_spec("#b")), "0b101")
    assert_equal(format_int(8, parse_format_spec("#o")), "0o10")


def test_format_int_sign_control() raises:
    assert_equal(format_int(42, parse_format_spec("+d")), "+42")
    assert_equal(format_int(42, parse_format_spec(" d")), " 42")
    assert_equal(format_int(-42, parse_format_spec("d")), "-42")
    assert_equal(format_int(-42, parse_format_spec("+d")), "-42")


def test_format_int_zero_pad_is_sign_aware() raises:
    assert_equal(format_int(42, parse_format_spec("08d")), "00000042")
    # Zeros go after the sign, not before it.
    assert_equal(format_int(-42, parse_format_spec("08d")), "-0000042")


def test_format_int_width_and_alignment() raises:
    assert_equal(format_int(42, parse_format_spec("<5")), "42   ")
    assert_equal(format_int(42, parse_format_spec(">5")), "   42")
    assert_equal(format_int(42, parse_format_spec("^5")), " 42  ")


def test_format_int_sign_aware_pad_places_zeros_after_sign() raises:
    assert_equal(format_int(42, parse_format_spec("=+06d")), "+00042")
    assert_equal(format_int(-42, parse_format_spec("=06d")), "-00042")


def test_format_int_precision_is_minimum_digits() raises:
    assert_equal(format_int(42, parse_format_spec(".6d")), "000042")
    assert_equal(format_int(42, parse_format_spec(".2d")), "42")


def test_format_int_grouping() raises:
    assert_equal(format_int(1234567, parse_format_spec(",d")), "1,234,567")
    assert_equal(format_int(1234567, parse_format_spec("_d")), "1_234_567")


def test_format_int_char_presentation() raises:
    assert_equal(format_int(65, parse_format_spec("c")), "A")


def test_format_int_char_invalid_codepoint_is_type_mismatch() raises:
    assert_equal(kind_of_int("c", -1), FormatErrorKind.TYPE_MISMATCH)


def test_format_int_float_presentation_is_type_mismatch() raises:
    assert_equal(kind_of_int("f", 1), FormatErrorKind.TYPE_MISMATCH)


def test_format_int_grouping_with_binary_is_invalid_spec() raises:
    # grouping is valid for DEFAULT/DECIMAL only; ',' on a binary presentation is
    # an incompatible combination.
    assert_equal(kind_of_int(",b", 5), FormatErrorKind.INVALID_SPEC)


def test_format_int_alt_form_with_char_is_invalid_spec() raises:
    # '#' (alternate form) is valid for the radix presentations only.
    assert_equal(kind_of_int("#c", 65), FormatErrorKind.INVALID_SPEC)


def test_format_int_alt_form_with_decimal_is_invalid_spec() raises:
    # '#' on decimal has no prefix and is an incompatible combination.
    assert_equal(kind_of_int("#d", 42), FormatErrorKind.INVALID_SPEC)


def test_format_int_returns_owned_independent_string() raises:
    # The returned String is independent of the spec/arguments.
    var spec = parse_format_spec("d")
    var out = format_int(7, spec)
    spec.width = 99
    assert_equal(out, "7")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
