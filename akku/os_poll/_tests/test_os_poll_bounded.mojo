# Concern: every wait is bounded — a wait with nothing ready returns after about
# the timeout (never indefinitely), and ZERO returns immediately.
from std.testing import assert_equal, assert_true, TestSuite
from std.time import perf_counter_ns
from std.ffi import external_call, c_int
from akku.os_poll import PollEvents, PollTimeout, wait


def make_pair() raises -> List[Int]:
    var ends = Array[c_int, 2](fill=c_int(-1))
    assert_equal(external_call["pipe", c_int](ends.unsafe_ptr()), c_int(0))
    var out = List[Int]()
    out.append(Int(ends[0]))
    out.append(Int(ends[1]))
    return out^


def close_fd(fd: Int) raises -> Int:
    return Int(external_call["close", c_int](c_int(fd)))


def test_bounded_wait_returns_after_timeout() raises:
    var pair = make_pair()
    var start = perf_counter_ns()
    var ready = wait(pair[0], PollEvents.READ, PollTimeout(50))
    var elapsed_ms = (perf_counter_ns() - start) // 1_000_000
    assert_true(ready.is_empty())
    assert_true(elapsed_ms >= 40)
    assert_true(elapsed_ms < 2000)
    _ = close_fd(pair[0])
    _ = close_fd(pair[1])


def test_zero_timeout_returns_immediately() raises:
    var pair = make_pair()
    var start = perf_counter_ns()
    _ = wait(pair[0], PollEvents.READ, PollTimeout.ZERO)
    var elapsed_ms = (perf_counter_ns() - start) // 1_000_000
    assert_true(elapsed_ms < 1000)
    _ = close_fd(pair[0])
    _ = close_fd(pair[1])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
