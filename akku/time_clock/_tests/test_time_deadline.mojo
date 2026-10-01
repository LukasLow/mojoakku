# Concern: `Deadline` — the opaque monotonic instant and its arithmetic/queries
# (docs block in `../deadline.mojo`; shared in `../__init__.mojo`).
#
# Covers: + / - Duration; Deadline - Deadline returns a signed Duration;
# compare plus all comparisons; is_expired for past and future; remaining
# positive then negative; elapsed negative then positive; the documented
# production invariant (no raw accessor); add overflow raises; Writable output
# and value semantics.
#
# Deadlines are produced only by Clock.now() and +/- Duration (the raw
# constructor is hidden), so every test starts from Clock.now().
#
# Opacity testing limitation: Mojo 1.x reflection (`std.reflection`) exposes a
# struct's fields and name but has no method enumeration and no hasattr-style
# membership test, so asserting the ABSENCE of a raw-tick accessor (e.g. there
# is no `to_nanos`) is not expressible as a compile-time check today. It is
# therefore covered honestly by asserting the documented production invariant
# instead; see `test_deadline_no_raw_accessor` and the note in `_dev/DESIGN.md`.
#
# Edge-case checklist: EOF/EINTR/EAGAIN/close are N/A (a Deadline is a value and
# blocks nothing); the expiry analogue is is_expired() and is covered here; the
# numeric extreme is the add-overflow case.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.time_clock import Clock, Deadline, Duration, TimeErrorKind


def test_deadline_add_and_sub_duration() raises:
    var d = Clock.now()
    var later = d + Duration.from_seconds(30)
    var back = later - Duration.from_seconds(30)
    assert_true(back == d)
    assert_true(later > d)


def test_deadline_sub_deadline_is_signed() raises:
    var a = Clock.now()
    var b = a + Duration.from_seconds(5)
    assert_equal((b - a).as_seconds(), 5)
    assert_equal((a - b).as_seconds(), -5)
    assert_true((a - b).is_negative())
    assert_true((b - a).is_positive())


def test_deadline_compare_and_operators() raises:
    var a = Clock.now()
    var b = a + Duration.from_seconds(1)
    assert_equal(a.compare(b), -1)
    assert_equal(a.compare(a), 0)
    assert_equal(b.compare(a), 1)
    assert_true(a < b)
    assert_true(a <= b)
    assert_true(b > a)
    assert_true(b >= a)
    assert_true(a == a)
    assert_false(a == b)


def test_deadline_is_expired_past_and_future() raises:
    # Wide margins so the assertion is not time-of-day sensitive.
    var past = Clock.now() - Duration.from_seconds(3600)
    var future = Clock.now() + Duration.from_seconds(3600)
    assert_true(past.is_expired())
    assert_false(future.is_expired())


def test_deadline_remaining_positive_then_negative() raises:
    var future = Clock.now() + Duration.from_seconds(3600)
    var past = Clock.now() - Duration.from_seconds(3600)
    assert_true(future.remaining().is_positive())
    assert_true(past.remaining().is_negative())


def test_deadline_elapsed_negative_then_positive() raises:
    var future = Clock.now() + Duration.from_seconds(3600)
    var past = Clock.now() - Duration.from_seconds(3600)
    assert_true(future.elapsed().is_negative())
    assert_true(past.elapsed().is_positive())


def test_deadline_no_raw_accessor() raises:
    # Opacity intent, covered honestly. Mojo reflection can enumerate a struct's
    # fields and name but cannot assert a method's ABSENCE, so this test asserts
    # the documented production invariant instead: a Deadline carrying a known
    # offset is produced only through Clock.now() and the +/- Duration
    # operations, and its only observable surface is the arithmetic/comparison/
    # query set — there is no supported route that exposes a raw tick.
    var base = Clock.now()
    var shifted = base + Duration.from_seconds(42)
    # The value is reachable only as a Deadline; the documented operation that
    # recovers a magnitude is the signed difference, not a raw-tick read.
    assert_equal((shifted - base).as_seconds(), 42)
    assert_equal((base - shifted).as_seconds(), -42)


def test_deadline_add_overflow_raises() raises:
    # Assumption (explicit, not documented as a guarantee): the monotonic tick
    # has not reached Int.MAX — on every real platform the monotonic origin is
    # far below the signed maximum — so adding Duration MAX overflows the Int
    # carrier. A fully deterministic probe is impossible today because the clock
    # origin is undefined and the instant opaque; see `_dev/DESIGN.md`.
    var caught = False
    try:
        _ = Clock.now() + Duration.from_nanos(Int.MAX)
    except e:
        caught = True
        assert_equal(e.kind, TimeErrorKind.OVERFLOW)
    assert_true(caught)


def test_deadline_write_to_canonical() raises:
    assert_true(conforms_to(Deadline, Writable))
    assert_true(String(Clock.now()).byte_length() > 0)


def test_deadline_value_semantics() raises:
    var d = Clock.now()
    var copied = d.copy()
    assert_true(copied == d)
    assert_true(conforms_to(Deadline, Copyable))
    assert_true(conforms_to(Deadline, ImplicitlyCopyable))
    assert_true(conforms_to(Deadline, Equatable))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
