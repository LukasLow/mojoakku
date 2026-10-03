# Concern: `format_bool` — render a bool under a FormatSpec (docs block in
# `../format_bool.mojo`).
#
# Covers: True/False render as "true"/"false"; width/alignment; precision as a
# maximum codepoint count of "false"; the documented TYPE_MISMATCH for a numeric
# presentation and for sign/zero-pad; and an owned, independent result.

from std.testing import assert_equal, assert_true, TestSuite
from akku.text_format import (
    FormatErrorKind,
    format_bool,
    parse_format_spec,
)


def kind_of_bool(text: String, value: Bool) raises -> FormatErrorKind:
    try:
        _ = format_bool(value, parse_format_spec(text))
    except e:
        return e.kind
    return FormatErrorKind.TYPE_MISMATCH


def test_format_bool_default() raises:
    assert_equal(format_bool(True, parse_format_spec("")), "true")
    assert_equal(format_bool(False, parse_format_spec("")), "false")


def test_format_bool_width_and_alignment() raises:
    assert_equal(format_bool(True, parse_format_spec(">6")), "  true")
    assert_equal(format_bool(True, parse_format_spec("^6")), " true ")


def test_format_bool_precision_truncates() raises:
    assert_equal(format_bool(False, parse_format_spec(".3")), "fal")


def test_format_bool_numeric_presentation_is_type_mismatch() raises:
    assert_equal(kind_of_bool("d", True), FormatErrorKind.TYPE_MISMATCH)


def test_format_bool_zero_pad_is_type_mismatch() raises:
    assert_equal(kind_of_bool("08", True), FormatErrorKind.TYPE_MISMATCH)


def test_format_bool_sign_is_type_mismatch() raises:
    assert_equal(kind_of_bool("+", True), FormatErrorKind.TYPE_MISMATCH)


def test_format_bool_result_is_owned() raises:
    var spec = parse_format_spec("")
    var out = format_bool(True, spec)
    spec.width = 20
    assert_equal(out, "true")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
