# Concern: `FormatSpec` — the parsed-format value type (docs block in
# `../format_spec.mojo`).
#
# Covers: the no-argument constructor yields the documented neutral defaults;
# the full constructor sets every field; fields are public and mutable; a
# negative width behaves as 0 per the docs; `print(spec)` renders a
# grammar-like form; the type is copyable/implicitly copyable/equatable.

from std.testing import assert_equal, assert_true, TestSuite
from akku.text_format import (
    Alignment,
    FormatSpec,
    FormatType,
    Grouping,
    SignMode,
    format_int,
)


def test_format_spec_defaults_are_neutral() raises:
    var spec = FormatSpec()
    assert_equal(String(spec.fill), " ")
    assert_true(spec.align == Alignment.DEFAULT)
    assert_true(spec.sign == SignMode.NEGATIVE_ONLY)
    assert_true(spec.alt_form == False)
    assert_true(spec.zero_pad == False)
    assert_equal(spec.width, 0)
    assert_true(spec.precision is None)
    assert_true(spec.grouping == Grouping.NONE)
    assert_true(spec.presentation == FormatType.DEFAULT)


def test_format_spec_full_constructor_sets_fields() raises:
    var spec = FormatSpec(
        Codepoint(42), Alignment.CENTER, SignMode.ALWAYS, True, True,
        8, Optional(3), Grouping.UNDERSCORE, FormatType.LOWER_HEX,
    )
    assert_equal(String(spec.fill), "*")
    assert_true(spec.align == Alignment.CENTER)
    assert_true(spec.sign == SignMode.ALWAYS)
    assert_true(spec.alt_form)
    assert_true(spec.zero_pad)
    assert_equal(spec.width, 8)
    assert_equal(spec.precision.value(), 3)
    assert_true(spec.grouping == Grouping.UNDERSCORE)
    assert_true(spec.presentation == FormatType.LOWER_HEX)


def test_format_spec_negative_width_renders_without_padding() raises:
    # A negative width is a caller error treated as 0 (no minimum width), so a
    # value shorter than every field still renders unpadded.
    var spec = FormatSpec()
    spec.width = -5
    assert_equal(format_int(42, spec), "42")


def test_format_spec_is_copyable_and_equatable() raises:
    var a = FormatSpec()
    var b = a
    assert_true(a == b)
    assert_true(conforms_to(FormatSpec, ImplicitlyCopyable))
    assert_true(conforms_to(FormatSpec, Equatable))


def test_format_spec_writable_renders_grammar_form() raises:
    # The docs promise print(spec) renders a grammar-like form, so at least one
    # field marker (e.g. "width") must appear (not merely a non-empty string).
    var spec = FormatSpec()
    var text = String(spec)
    assert_true("width" in text)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
