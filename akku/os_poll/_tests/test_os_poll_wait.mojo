# Concern: wait() on a single descriptor against real OS pipes: readiness,
# zero-timeout probe, NONE on timeout, INVALID_TIMEOUT / INVALID_FD errors, and
# the POLLNVAL (INVALID) surface for a closed descriptor.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.ffi import external_call, OwnedDLHandle, c_int, c_ssize_t, c_size_t
from akku.os_poll import PollEvents, PollTimeout, PollErrorKind, wait


def make_pair() raises -> List[Int]:
    var ends = Array[c_int, 2](fill=c_int(-1))
    assert_equal(external_call["pipe", c_int](ends.unsafe_ptr()), c_int(0))
    var out = List[Int]()
    out.append(Int(ends[0]))
    out.append(Int(ends[1]))
    return out^


def close_fd(fd: Int) raises -> Int:
    return Int(external_call["close", c_int](c_int(fd)))


def write_byte(fd: Int, value: UInt8) raises -> Int:
    # `external_call["write", ...]` collides with a `write` signature already in
    # std.ffi, so resolve the libc symbol through a dynamic handle instead.
    var byte = value
    var libc = OwnedDLHandle()
    var write_fn = libc.get_function[c_ssize_t]("write")
    return Int(write_fn(c_int(fd), Pointer(to=byte).unsafe_bitcast[NoneType](), c_size_t(1)))


def test_write_end_is_writable() raises:
    var pair = make_pair()
    var ready = wait(pair[1], PollEvents.WRITE, PollTimeout(500))
    assert_true(ready.is_writable())
    _ = close_fd(pair[0])
    _ = close_fd(pair[1])


def test_zero_timeout_then_data_becomes_readable() raises:
    var pair = make_pair()
    var first = wait(pair[0], PollEvents.READ, PollTimeout.ZERO)
    assert_true(first.is_empty())
    assert_equal(write_byte(pair[1], 42), 1)
    var second = wait(pair[0], PollEvents.READ, PollTimeout(500))
    assert_true(second.is_readable())
    _ = close_fd(pair[0])
    _ = close_fd(pair[1])


def test_negative_fd_raises_invalid_fd() raises:
    var kind = PollErrorKind.SYSCALL
    var caught = False
    var op = ""
    try:
        _ = wait(-1, PollEvents.READ, PollTimeout(10))
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_true(kind == PollErrorKind.INVALID_FD)
    assert_equal(op, "wait")


def test_negative_timeout_raises_invalid_timeout() raises:
    var pair = make_pair()
    var kind = PollErrorKind.SYSCALL
    var caught = False
    try:
        _ = wait(pair[0], PollEvents.READ, PollTimeout(-1))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_true(kind == PollErrorKind.INVALID_TIMEOUT)
    _ = close_fd(pair[0])
    _ = close_fd(pair[1])


def test_closed_descriptor_reports_invalid_bit() raises:
    var pair = make_pair()
    var closed = pair[0]
    var kept = pair[1]
    assert_equal(close_fd(closed), 0)
    var ready = wait(closed, PollEvents.READ, PollTimeout(100))
    assert_true(ready.is_invalid())
    _ = close_fd(kept)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
