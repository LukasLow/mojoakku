# Concern: `FormatError` — the single typed error carrying kind + position +
# message (docs block in `../format_error.mojo`; shared error surface in
# `../__init__.mojo`).
#
# Covers: the three fields are readable; `print(err)` reports the symbolic kind,
# the position and the message; the error is Copyable but deliberately not
# ImplicitlyCopyable, so a re-raise transfers with `raise e^`; the position of a
# real failure points into the offending input.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import (
    FormatError,
    FormatErrorKind,
    parse_format_spec,
)


def test_error_fields_are_readable() raises:
    var err = FormatError(FormatErrorKind.TYPE_MISMATCH, 3, String("bad presentation"))
    assert_equal(err.kind, FormatErrorKind.TYPE_MISMATCH)
    assert_equal(err.position, 3)
    assert_equal(err.message, "bad presentation")


def test_error_writable_reports_kind_position_message() raises:
    var err = FormatError(FormatErrorKind.MISSING_ARGUMENT, 7, String("no arg for field"))
    var text = String(err)
    assert_true("MISSING_ARGUMENT" in text)
    assert_true("7" in text)
    assert_true("no arg for field" in text)


def test_error_position_points_into_input() raises:
    var caught = False
    var position = -1
    var kind = FormatErrorKind.TYPE_MISMATCH
    try:
        _ = parse_format_spec("q")
    except e:
        caught = True
        kind = e.kind
        position = e.position
    assert_true(caught)
    assert_equal(kind, FormatErrorKind.INVALID_SPEC)
    assert_equal(position, 0)


def rethrow() raises FormatError:
    try:
        raise FormatError(FormatErrorKind.INVALID_SPEC, 2, String("bad"))
    except e:
        raise e^


def test_error_reraise_by_transfer() raises:
    # FormatError is Copyable but not ImplicitlyCopyable; a re-raise transfers.
    var caught = False
    try:
        rethrow()
    except e:
        caught = True
        assert_equal(e.kind, FormatErrorKind.INVALID_SPEC)
        assert_equal(e.position, 2)
    assert_true(caught)


def test_error_not_implicitly_copyable() raises:
    assert_true(conforms_to(FormatError, Copyable))
    assert_false(conforms_to(FormatError, ImplicitlyCopyable))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
