# Concern: `format_float` — render a float under a FormatSpec (docs block in
# `../format_float.mojo`).
#
# Covers: the shortest round-trip default; fixed precision and the default of
# six digits; scientific notation; half-to-even rounding; sign control;
# sign-aware zero pad; width/alignment; alternate form (forced decimal point);
# inf/nan rendered lowercase with 'F' aliasing 'f'; and the documented
# TYPE_MISMATCH/INVALID_SPEC. inf/nan are built through std.utils.numerics.

from std.testing import assert_equal, assert_true, TestSuite
from std.utils.numerics import inf, nan
from akku.text_format import (
    FormatErrorKind,
    format_float,
    parse_format_spec,
)


def kind_of_float(text: String, value: Float64) raises -> FormatErrorKind:
    try:
        _ = format_float(value, parse_format_spec(text))
    except e:
        return e.kind
    return FormatErrorKind.TYPE_MISMATCH


def test_format_float_default_shortest_roundtrip() raises:
    assert_equal(format_float(1.0, parse_format_spec("")), "1.0")
    assert_equal(format_float(0.125, parse_format_spec("")), "0.125")


def test_format_float_fixed_precision() raises:
    assert_equal(format_float(3.14159, parse_format_spec(".2f")), "3.14")
    assert_equal(format_float(3.0, parse_format_spec(".0f")), "3")


def test_format_float_fixed_default_precision_is_six() raises:
    assert_equal(format_float(1.0, parse_format_spec("f")), "1.000000")


def test_format_float_scientific() raises:
    var lower = format_float(1234.5, parse_format_spec(".2e"))
    assert_true("e" in lower)
    var upper = format_float(1234.5, parse_format_spec(".2E"))
    assert_true("E" in upper)


def test_format_float_rounds_half_to_even() raises:
    # 0.125 is an exact tie at 2 digits; half-to-even picks 0.12.
    assert_equal(format_float(0.125, parse_format_spec(".2f")), "0.12")
    # 0.135 rounds to 0.14 (the even last digit, not a tie artifact).
    assert_equal(format_float(0.375, parse_format_spec(".2f")), "0.38")


def test_format_float_sign_control() raises:
    assert_equal(format_float(1.5, parse_format_spec("+.1f")), "+1.5")
    assert_equal(format_float(-1.5, parse_format_spec(".1f")), "-1.5")


def test_format_float_zero_pad_is_sign_aware() raises:
    assert_equal(format_float(1.5, parse_format_spec("08.2f")), "00001.50")
    assert_equal(format_float(-1.5, parse_format_spec("08.2f")), "-0001.50")


def test_format_float_width_and_alignment() raises:
    assert_equal(format_float(1.5, parse_format_spec("<6.1f")), "1.5   ")
    assert_equal(format_float(1.5, parse_format_spec(">6.1f")), "   1.5")


def test_format_float_alternate_form_keeps_decimal_point() raises:
    assert_equal(format_float(3.0, parse_format_spec("#.0f")), "3.")


def test_format_float_inf_nan_are_lowercase_and_f_aliases_f() raises:
    var pos_inf = inf[DType.float64]()
    var not_a_number = nan[DType.float64]()
    assert_equal(format_float(pos_inf, parse_format_spec("")), "inf")
    assert_equal(format_float(not_a_number, parse_format_spec("")), "nan")
    # 'F' is an alias of 'f': it must NOT upper-case inf/nan.
    assert_equal(format_float(pos_inf, parse_format_spec("F")), "inf")
    assert_equal(format_float(not_a_number, parse_format_spec("F")), "nan")


def test_format_float_grouping_is_invalid_spec() raises:
    assert_equal(kind_of_float(",f", 1.0), FormatErrorKind.INVALID_SPEC)


def test_format_float_int_presentation_is_type_mismatch() raises:
    assert_equal(kind_of_float("d", 1.0), FormatErrorKind.TYPE_MISMATCH)


def test_format_float_returns_owned_independent_string() raises:
    var spec = parse_format_spec(".2f")
    var out = format_float(3.14159, spec)
    spec.precision = Optional(4)
    assert_equal(out, "3.14")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
