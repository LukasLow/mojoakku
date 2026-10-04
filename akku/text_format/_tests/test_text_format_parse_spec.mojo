# Concern: `parse_format_spec` — parse and validate a spec string into a
# FormatSpec (docs block in `../parse_format_spec.mojo`).
#
# Covers: an empty string yields the neutral spec; alignment and fill; sign and
# zero pad; alternate form and grouping; precision; the accepted presentation
# letters; and every documented rejection (unknown letter, repeated flag, nested
# brace, bare fill) with the offending byte position.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import (
    Alignment,
    FormatError,
    FormatErrorKind,
    FormatSpec,
    FormatType,
    Grouping,
    SignMode,
    parse_format_spec,
)


def test_parse_empty_is_default() raises:
    var spec = parse_format_spec("")
    assert_true(spec == FormatSpec())


def test_parse_align_and_fill() raises:
    var a = parse_format_spec("*>10")
    assert_true(a.align == Alignment.RIGHT)
    assert_equal(String(a.fill), "*")
    assert_equal(a.width, 10)
    var b = parse_format_spec("^8")
    assert_true(b.align == Alignment.CENTER)
    assert_equal(b.width, 8)


def test_parse_sign_and_zero_pad() raises:
    var a = parse_format_spec("+08d")
    assert_true(a.sign == SignMode.ALWAYS)
    assert_true(a.zero_pad)
    assert_equal(a.width, 8)
    assert_true(a.presentation == FormatType.DECIMAL)
    var b = parse_format_spec(" 5.2f")
    assert_true(b.sign == SignMode.SPACE)
    assert_equal(b.width, 5)
    assert_equal(b.precision.value(), 2)


def test_parse_alternate_form_and_grouping() raises:
    assert_true(parse_format_spec("#x").alt_form)
    assert_true(parse_format_spec(",d").grouping == Grouping.COMMA)
    assert_true(parse_format_spec("_d").grouping == Grouping.UNDERSCORE)


def test_parse_precision() raises:
    var spec = parse_format_spec(".3f")
    assert_equal(spec.precision.value(), 3)
    assert_true(spec.presentation == FormatType.FIXED)


def test_parse_all_letters() raises:
    assert_true(parse_format_spec("b").presentation == FormatType.BINARY)
    assert_true(parse_format_spec("o").presentation == FormatType.OCTAL)
    assert_true(parse_format_spec("c").presentation == FormatType.CHAR)
    assert_true(parse_format_spec("s").presentation == FormatType.STRING)
    assert_true(parse_format_spec("r").presentation == FormatType.REPR)
    assert_true(parse_format_spec("e").presentation == FormatType.SCIENTIFIC)
    assert_true(parse_format_spec("E").presentation == FormatType.UPPER_SCIENTIFIC)


def parse_kind(text: String) raises -> FormatErrorKind:
    try:
        _ = parse_format_spec(text)
    except e:
        return e.kind
    return FormatErrorKind.TYPE_MISMATCH


def parse_position(text: String) raises -> Int:
    try:
        _ = parse_format_spec(text)
    except e:
        return e.position
    return -1


def test_parse_rejects_unknown_letter() raises:
    assert_equal(parse_kind("q"), FormatErrorKind.INVALID_SPEC)


def test_parse_rejects_repeated_flag() raises:
    assert_equal(parse_kind("++d"), FormatErrorKind.INVALID_SPEC)


def test_parse_rejects_nested_brace() raises:
    assert_equal(parse_kind("{width}"), FormatErrorKind.INVALID_SPEC)


def test_parse_rejects_bare_fill_without_align() raises:
    assert_equal(parse_kind("*10"), FormatErrorKind.INVALID_SPEC)


def test_parse_reports_position() raises:
    # The offending character is the unknown letter at byte offset 0.
    assert_equal(parse_position("q"), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
