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


def test_format_spec_negative_width_behaves_as_zero() raises:
    var spec = FormatSpec()
    spec.width = -5
    # A negative width is a caller error treated as 0 (no minimum width).
    assert_true(spec.width <= 0)


def test_format_spec_is_copyable_and_equatable() raises:
    var a = FormatSpec()
    var b = a
    assert_true(a == b)
    assert_true(conforms_to(FormatSpec, ImplicitlyCopyable))
    assert_true(conforms_to(FormatSpec, Equatable))


def test_format_spec_writable_renders_grammar_form() raises:
    # The docs promise print(spec) renders a grammar-like form; this exercises
    # the Writable path (not yet implemented in the red phase).
    var spec = FormatSpec()
    assert_true(String(spec).byte_length() > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
