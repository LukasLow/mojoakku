# Concern: `TimeError` and `TimeErrorKind` — the one typed error and its closed
# two-value discriminant (docs blocks in `../time_error.mojo`,
# `../time_error_kind.mojo`; shared in `../__init__.mojo`).
#
# Covers: the two kinds are distinct and equality is discriminant-only;
# write_to prints the symbolic name, never the number; the kind/detail fields
# are readable in an except block; TimeError is Copyable and Deinitable but
# deliberately NOT ImplicitlyCopyable, so a re-raise must transfer with `^`.
#
# Edge-case checklist: EOF/EINTR/EAGAIN/close/timeouts are N/A (a value error
# carries no descriptor). The applicable edge case is the non-copyable-error
# re-raise, covered here through an actual caught error.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.time_clock import Duration, TimeError, TimeErrorKind


def rethrow_error() raises TimeError:
    # A caught error must be re-raised by transfer, not copy.
    try:
        raise TimeError(TimeErrorKind.OVERFLOW, "re-raised")
    except e:
        raise e^


def test_error_kind_distinct_and_eq() raises:
    assert_true(TimeErrorKind.OVERFLOW == TimeErrorKind.OVERFLOW)
    assert_true(TimeErrorKind.DIVISION_BY_ZERO == TimeErrorKind.DIVISION_BY_ZERO)
    assert_false(TimeErrorKind.OVERFLOW == TimeErrorKind.DIVISION_BY_ZERO)
    assert_false(TimeErrorKind.DIVISION_BY_ZERO == TimeErrorKind.OVERFLOW)


def test_error_kind_writable() raises:
    # Symbolic names, never the numeric id.
    assert_true("OVERFLOW" in String(TimeErrorKind.OVERFLOW))
    assert_true("DIVISION_BY_ZERO" in String(TimeErrorKind.DIVISION_BY_ZERO))


def test_error_kind_conformance() raises:
    assert_true(conforms_to(TimeErrorKind, Equatable))
    assert_true(conforms_to(TimeErrorKind, ImplicitlyCopyable))
    assert_true(conforms_to(TimeErrorKind, Writable))


def test_error_fields_kind_detail() raises:
    var err = TimeError(TimeErrorKind.OVERFLOW, "Duration.__add__ overflow")
    assert_equal(err.kind, TimeErrorKind.OVERFLOW)
    assert_equal(err.detail, "Duration.__add__ overflow")


def test_error_writable() raises:
    var err = TimeError(TimeErrorKind.DIVISION_BY_ZERO, "divided_by(0)")
    var text = String(err)
    assert_true("DIVISION_BY_ZERO" in text)


def test_error_copyable_and_deinitable() raises:
    var err = TimeError(TimeErrorKind.OVERFLOW, "detail")
    var copied = err.copy()
    assert_equal(copied.kind, TimeErrorKind.OVERFLOW)
    assert_true(conforms_to(TimeError, Copyable))
    assert_true(conforms_to(TimeError, Deinitable))


def test_error_not_implicitly_copyable() raises:
    assert_false(conforms_to(TimeError, ImplicitlyCopyable))


def test_error_reraise_transfer() raises:
    var caught = False
    try:
        rethrow_error()
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_error_kind_from_real_failure() raises:
    # The kind surfaced by a real failure is the documented one.
    var caught = False
    try:
        _ = Duration.from_nanos(5).divided_by(0)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.DIVISION_BY_ZERO)
        assert_true(e.detail.byte_length() > 0)
    assert_true(caught)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
