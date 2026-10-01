# Concern: PollTimeout construction, MAX_MILLIS bounds, clamped() saturation and
# printing; there is no infinite form.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.os_poll import PollTimeout


def test_construct_and_read_millis() raises:
    assert_equal(PollTimeout(50).millis, 50)
    assert_true(PollTimeout.ZERO.is_zero())
    assert_false(PollTimeout(1).is_zero())
    assert_equal(PollTimeout.MAX.millis, PollTimeout.MAX_MILLIS)
    assert_equal(PollTimeout.MAX_MILLIS, 2_147_483_647)


def test_clamped_saturates() raises:
    assert_equal(PollTimeout.clamped(-5).millis, 0)
    assert_equal(PollTimeout.clamped(0).millis, 0)
    assert_equal(PollTimeout.clamped(250).millis, 250)
    assert_equal(PollTimeout.clamped(PollTimeout.MAX_MILLIS + 1).millis, PollTimeout.MAX_MILLIS)
    assert_equal(PollTimeout.clamped(9_999_999_999).millis, PollTimeout.MAX_MILLIS)


def test_equality_and_printing() raises:
    assert_true(PollTimeout(50) == PollTimeout(50))
    assert_false(PollTimeout(50) == PollTimeout(51))
    assert_true("50" in String(PollTimeout(50)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
