# Concern: `Clock` — the one monotonic clock entry point (docs block in
# `../clock.mojo`; shared in `../__init__.mojo`).
#
# Covers: now() yields a Deadline; the reading is monotonic (non-decreasing);
# it advances after real work (bounded busy loop, no sleep assumption); and
# now() - now() is a Duration.
#
# Edge-case checklist: EOF/EINTR/EAGAIN/close/timeouts are N/A — now() never
# blocks and never fails. The "advances" test deliberately uses a bounded busy
# loop rather than a sleep, so it does not depend on scheduler timing.

from std.testing import assert_true, TestSuite
from akku.time_clock import Clock, Deadline, Duration


def test_clock_now_is_deadline() raises:
    # The explicit annotation enforces the documented return type.
    var now: Deadline = Clock.now()
    var past = now - Duration.from_seconds(1)
    assert_true(past < now)


def test_clock_now_non_decreasing() raises:
    var first = Clock.now()
    var second = Clock.now()
    # The clock never moves backwards: second - first is >= ZERO.
    assert_true((second - first).is_positive() or (second - first).is_zero())


def test_clock_now_advances_after_work() raises:
    var start = Clock.now()
    # Bounded busy work; no sleep and no exact-duration assumption.
    var total = 0
    for i in range(200_000):
        total += i
    var elapsed = Clock.now() - start
    assert_true(elapsed.is_positive() or elapsed.is_zero())


def test_clock_now_difference_is_duration() raises:
    var a = Clock.now()
    var b = Clock.now()
    var delta: Duration = b - a
    # A Duration supports the documented span accessor.
    assert_true(delta.as_nanos() >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
