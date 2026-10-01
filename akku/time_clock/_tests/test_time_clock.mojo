# Concern: `Clock` — the one monotonic clock entry point (docs block in
# `../clock.mojo`; shared in `../__init__.mojo`).
#
# Covers: now() yields a Deadline; the reading is monotonic (non-decreasing),
# including across real bounded work; and now() - now() is a Duration.
#
# Edge-case checklist: EOF/EINTR/EAGAIN/close/timeouts are N/A — now() never
# blocks and never fails. The work test deliberately uses a bounded busy loop
# rather than a sleep, so it does not depend on scheduler timing. It proves the
# documented non-decreasing contract only; it deliberately does NOT claim that
# the clock strictly advanced (a coarse clock may not tick during short work).

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


def test_clock_now_non_decreasing_across_work() raises:
    # The documented contract is monotonicity (never moves backwards). This
    # exercises that contract across real bounded work, using a busy loop rather
    # than a sleep so it does not depend on scheduler timing. It deliberately
    # does NOT assert strict advance: a coarse clock may not tick during short
    # work, and the docs promise non-decrease, not progress.
    var start = Clock.now()
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
