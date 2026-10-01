# Concern: `Duration` overflow and division-by-zero — the explicit replacement
# for Go/C/C++ silent wrap (docs block in `../duration.mojo`; shared in
# `../__init__.mojo`).
#
# Covers: __add__/__sub__/__neg__/scaled raise OVERFLOW; from_millis unit
# scaling raises OVERFLOW; abs of the most-negative span raises OVERFLOW;
# divided_by(0) raises DIVISION_BY_ZERO; divided_by(MIN, -1) raises OVERFLOW
# (the true quotient 2^63 has no Int representation).
#
# Edge-case checklist: EINTR/EAGAIN/EOF/close/timeouts are N/A (pure value
# library). The applicable edge cases are the numeric extremes covered here.

from std.testing import assert_equal, assert_true, TestSuite
from akku.time_clock import Duration, TimeErrorKind


def test_duration_add_overflow_raises() raises:
    var caught = False
    try:
        _ = Duration.from_nanos(Int.MAX) + Duration.from_nanos(1)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_duration_sub_overflow_raises() raises:
    var caught = False
    try:
        _ = Duration.from_nanos(Int.MIN) - Duration.from_nanos(1)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_duration_neg_overflow_raises() raises:
    # -MIN is not representable in a two's-complement Int.
    var caught = False
    try:
        _ = -Duration.from_nanos(Int.MIN)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_duration_scaled_overflow_raises() raises:
    var caught = False
    try:
        _ = Duration.from_nanos(Int.MAX).scaled(2)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_duration_from_millis_overflow_raises() raises:
    # 9.3e18 ms * 1e6 does not fit the Int carrier.
    var caught = False
    try:
        _ = Duration.from_millis(9_300_000_000_000_000_000)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_duration_abs_of_min_raises() raises:
    # abs(MIN) needs magnitude 2^63, which is not representable.
    var caught = False
    try:
        _ = Duration.from_nanos(Int.MIN).abs()
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_duration_divided_by_zero_raises() raises:
    var caught = False
    try:
        _ = Duration.from_nanos(5).divided_by(0)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.DIVISION_BY_ZERO)
    assert_true(caught)


def test_duration_divided_by_neg_one_min_raises() raises:
    # MIN / -1 == 2^63, one past Int.MAX; checked, not wrapped.
    var caught = False
    try:
        _ = Duration.from_nanos(Int.MIN).divided_by(-1)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
