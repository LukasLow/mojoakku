# Concern: `Duration` — the signed integer-nanosecond span and its full value
# surface (docs block in `../duration.mojo`; shared in `../__init__.mojo`).
#
# Covers: unit constructors + accessors (truncation toward zero), the three sign
# predicates, abs, add/sub/negate, scaled/divided_by, compare plus all six
# comparisons, the ZERO constant, Writable output and value semantics.
#
# Edge-case checklist (honest coverage): EOF, EINTR, EAGAIN, non-blocking
# behaviour, close/ownership and timeouts are N/A for this library. `time_clock`
# is a pure in-memory value library: no operation touches a descriptor, signal,
# socket or blocking resource. The applicable edge cases are the numeric
# extremes (covered in `test_time_duration_overflow.mojo`) and truncation toward
# zero for negatives, covered here.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.time_clock import Duration


def test_duration_from_units_and_accessors() raises:
    assert_equal(Duration.from_nanos(1234).as_nanos(), 1234)
    assert_equal(Duration.from_micros(2).as_nanos(), 2000)
    assert_equal(Duration.from_millis(2).as_nanos(), 2_000_000)
    assert_equal(Duration.from_seconds(2).as_nanos(), 2_000_000_000)
    assert_equal(Duration.from_seconds(2).as_millis(), 2000)
    assert_equal(Duration.from_millis(1500).as_micros(), 1_500_000)


def test_duration_as_truncates_toward_zero() raises:
    # Truncating toward zero, not floor: a fractional negative loses its fraction.
    assert_equal(Duration.from_nanos(999).as_micros(), 0)
    assert_equal(Duration.from_nanos(1_999).as_micros(), 1)
    assert_equal(Duration.from_micros(1_500).as_millis(), 1)
    assert_equal(Duration.from_millis(1500).as_seconds(), 1)
    assert_equal(Duration.from_nanos(-1).as_seconds(), 0)
    assert_equal(Duration.from_nanos(-1_500_000_000).as_seconds(), -1)


def test_duration_sign_predicates() raises:
    assert_true(Duration.ZERO.is_zero())
    assert_false(Duration.ZERO.is_positive())
    assert_false(Duration.ZERO.is_negative())

    var up = Duration.from_nanos(1)
    assert_true(up.is_positive())
    assert_false(up.is_negative())
    assert_false(up.is_zero())

    var down = Duration.from_nanos(-1)
    assert_true(down.is_negative())
    assert_false(down.is_positive())
    assert_false(down.is_zero())


def test_duration_abs() raises:
    assert_equal(Duration.from_nanos(-5).abs().as_nanos(), 5)
    assert_equal(Duration.from_nanos(7).abs().as_nanos(), 7)
    assert_equal(Duration.ZERO.abs().as_nanos(), 0)


def test_duration_add_sub_negate() raises:
    assert_equal((Duration.from_nanos(5) + Duration.from_nanos(3)).as_nanos(), 8)
    assert_equal((Duration.from_nanos(5) - Duration.from_nanos(3)).as_nanos(), 2)
    assert_equal((Duration.from_nanos(3) - Duration.from_nanos(5)).as_nanos(), -2)
    assert_equal((-Duration.from_nanos(5)).as_nanos(), -5)
    assert_equal((Duration.from_nanos(5) + Duration.ZERO).as_nanos(), 5)


def test_duration_scaled_and_divided_by() raises:
    assert_equal(Duration.from_nanos(5).scaled(3).as_nanos(), 15)
    assert_equal(Duration.from_nanos(5).scaled(-2).as_nanos(), -10)
    assert_equal(Duration.from_nanos(15).divided_by(3).as_nanos(), 5)
    # Division truncates toward zero for both signs.
    assert_equal(Duration.from_nanos(7).divided_by(2).as_nanos(), 3)
    assert_equal(Duration.from_nanos(-7).divided_by(2).as_nanos(), -3)


def test_duration_compare_and_operators() raises:
    var a = Duration.from_nanos(1)
    var b = Duration.from_nanos(2)
    assert_equal(a.compare(b), -1)
    assert_equal(a.compare(a), 0)
    assert_equal(b.compare(a), 1)
    assert_true(a < b)
    assert_true(a <= b)
    assert_true(b > a)
    assert_true(b >= a)
    assert_true(a == a)
    assert_false(a == b)


def test_duration_zero_constant() raises:
    assert_equal(Duration.ZERO.as_nanos(), 0)
    assert_true(Duration.ZERO == Duration.from_nanos(0))
    assert_true(Duration.from_nanos(5) - Duration.from_nanos(5) == Duration.ZERO)


def test_duration_write_to_canonical() raises:
    # Writable is part of the documented conformance set. The exact glyphs are
    # not pinned by the docs, so this asserts that write_to produces a non-empty
    # rendering for real values (the canonical span is exercised, not a format).
    assert_true(conforms_to(Duration, Writable))
    assert_true(String(Duration.ZERO).byte_length() > 0)
    assert_true(String(Duration.from_nanos(5)).byte_length() > 0)
    assert_true(String(Duration.from_nanos(-5)).byte_length() > 0)


def test_duration_value_semantics() raises:
    var d = Duration.from_nanos(5)
    var copied = d.copy()
    assert_equal(copied.as_nanos(), 5)
    assert_true(conforms_to(Duration, Copyable))
    assert_true(conforms_to(Duration, ImplicitlyCopyable))
    assert_true(conforms_to(Duration, Equatable))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
