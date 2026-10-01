# Concern: wait_many() over a caller-owned set: ready count, revents written
# back, negative-fd slot skipped, empty set returns 0 without sleeping, and the
# INVALID bit for a closed slot.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.ffi import external_call, OwnedDLHandle, c_int, c_ssize_t, c_size_t
from akku.os_poll import PollEvents, PollFd, PollTimeout, wait_many


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


def test_one_ready_of_two() raises:
    var a = make_pair()
    var b = make_pair()
    assert_equal(write_byte(a[1], 1), 1)
    var fds = List[PollFd]()
    fds.append(PollFd(a[0], PollEvents.READ))
    fds.append(PollFd(b[0], PollEvents.READ))
    var span = MutSpan(fds)
    var count = wait_many(span, PollTimeout(500))
    assert_equal(count, 1)
    assert_true(fds[0].revents.is_readable())
    assert_true(fds[1].revents.is_empty())
    _ = close_fd(a[0]); _ = close_fd(a[1]); _ = close_fd(b[0]); _ = close_fd(b[1])


def test_both_ready() raises:
    var a = make_pair()
    var b = make_pair()
    assert_equal(write_byte(a[1], 1), 1)
    assert_equal(write_byte(b[1], 2), 1)
    var fds = List[PollFd]()
    fds.append(PollFd(a[0], PollEvents.READ))
    fds.append(PollFd(b[0], PollEvents.READ))
    var span = MutSpan(fds)
    var count = wait_many(span, PollTimeout(500))
    assert_equal(count, 2)
    assert_true(fds[0].revents.is_readable())
    assert_true(fds[1].revents.is_readable())
    _ = close_fd(a[0]); _ = close_fd(a[1]); _ = close_fd(b[0]); _ = close_fd(b[1])


def test_negative_fd_slot_is_skipped() raises:
    var a = make_pair()
    assert_equal(write_byte(a[1], 1), 1)
    var fds = List[PollFd]()
    fds.append(PollFd(-1, PollEvents.READ))
    fds.append(PollFd(a[0], PollEvents.READ))
    var span = MutSpan(fds)
    var count = wait_many(span, PollTimeout(500))
    assert_equal(count, 1)
    assert_true(fds[0].revents.is_empty())
    assert_true(fds[1].revents.is_readable())
    _ = close_fd(a[0]); _ = close_fd(a[1])


def test_empty_set_returns_zero() raises:
    var fds = List[PollFd]()
    var span = MutSpan(fds)
    var count = wait_many(span, PollTimeout(500))
    assert_equal(count, 0)


def test_closed_slot_reports_invalid_bit() raises:
    var a = make_pair()
    var closed = a[0]
    var kept = a[1]
    assert_equal(close_fd(closed), 0)
    var fds = List[PollFd]()
    fds.append(PollFd(closed, PollEvents.READ))
    var span = MutSpan(fds)
    var count = wait_many(span, PollTimeout(100))
    assert_equal(count, 1)
    assert_true(fds[0].revents.is_invalid())
    _ = close_fd(kept)


def test_peer_close_reports_hangup() raises:
    var pair = make_pair()
    assert_equal(close_fd(pair[1]), 0)
    var fds = List[PollFd]()
    fds.append(PollFd(pair[0], PollEvents.READ))
    var span = MutSpan(fds)
    var count = wait_many(span, PollTimeout(500))
    assert_equal(count, 1)
    assert_true(fds[0].revents.has_hangup())
    _ = close_fd(pair[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
