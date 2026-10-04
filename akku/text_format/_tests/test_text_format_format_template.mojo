# Concern: `format_template` — bind a runtime template and return the formatted
# String (docs block in `../format_template.mojo`).
#
# Covers: auto numbering; explicit zero-based index and reordering; index reuse;
# literal-brace escaping; inline specs; the !s and !r conversions; non-ASCII
# literal passthrough; the owned, independent result; and every documented error:
# unbalanced braces, mixed numbering, missing argument, extra argument and type
# mismatch.

from std.testing import assert_equal, assert_true, TestSuite
from akku.text_format import (
    FormatArgs,
    FormatErrorKind,
    format_template,
)


def args_one_int() raises -> FormatArgs:
    var args = FormatArgs()
    args.push_int(42)
    return args^


def args_two_ints() raises -> FormatArgs:
    var args = FormatArgs()
    args.push_int(1)
    args.push_int(2)
    return args^


def kind_of(template: String, args: FormatArgs) raises -> FormatErrorKind:
    try:
        _ = format_template(template, args)
    except e:
        return e.kind
    return FormatErrorKind.TYPE_MISMATCH


def test_format_template_auto_numbering() raises:
    var args = args_two_ints()
    assert_equal(format_template("{} {}", args), "1 2")


def test_format_template_explicit_index_reorders() raises:
    var args = args_two_ints()
    assert_equal(format_template("{1} {0}", args), "2 1")


def test_format_template_index_reuse() raises:
    var args = args_one_int()
    assert_equal(format_template("{0} {0}", args), "42 42")


def test_format_template_literal_brace_escaping() raises:
    var args = args_one_int()
    assert_equal(format_template("{{literal}} {}", args), "{literal} 42")


def test_format_template_inline_spec() raises:
    var args = args_one_int()
    assert_equal(format_template("{:08d}", args), "00000042")


def test_format_template_conversion_display_and_repr() raises:
    var args = FormatArgs()
    args.push_string(String("hi"))
    assert_equal(format_template("{!s}", args), "hi")
    assert_equal(format_template("{!r}", args), "'hi'")


def test_format_template_non_ascii_literal_passthrough() raises:
    var args = args_one_int()
    assert_equal(format_template("héllo {}", args), "héllo 42")


def test_format_template_returns_owned_independent_string() raises:
    var args = args_one_int()
    var out = format_template("{}", args)
    assert_equal(out, "42")
    assert_equal(args.count(), 1)


def test_format_template_unbalanced_brace_is_malformed() raises:
    var args = args_one_int()
    assert_equal(kind_of("{", args), FormatErrorKind.MALFORMED_TEMPLATE)
    assert_equal(kind_of("}", args), FormatErrorKind.MALFORMED_TEMPLATE)


def test_format_template_mixed_numbering_is_malformed() raises:
    var args = args_two_ints()
    assert_equal(kind_of("{} {0}", args), FormatErrorKind.MALFORMED_TEMPLATE)


def test_format_template_missing_argument() raises:
    var args = args_one_int()
    assert_equal(kind_of("{2}", args), FormatErrorKind.MISSING_ARGUMENT)


def test_format_template_extra_argument() raises:
    var args = args_two_ints()
    assert_equal(kind_of("{}", args), FormatErrorKind.EXTRA_ARGUMENT)


def test_format_template_type_mismatch() raises:
    var args = FormatArgs()
    args.push_string(String("x"))
    assert_equal(kind_of("{:x}", args), FormatErrorKind.TYPE_MISMATCH)


def test_format_template_unknown_conversion_is_malformed() raises:
    # Only !s and !r are documented; an unknown conversion is MALFORMED_TEMPLATE.
    var args = FormatArgs()
    args.push_string(String("x"))
    assert_equal(kind_of("{!a}", args), FormatErrorKind.MALFORMED_TEMPLATE)


def test_format_template_unknown_spec_letter_is_invalid_spec() raises:
    var args = FormatArgs()
    args.push_int(1)
    assert_equal(kind_of("{:q}", args), FormatErrorKind.INVALID_SPEC)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
