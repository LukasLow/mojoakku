from std.ffi import c_int, c_short
from std.time import perf_counter_ns

from .poll_error_kind import PollErrorKind
from .poll_events import PollEvents
from .poll_timeout import PollTimeout
from .poll_error import PollError
from akku.os_poll._internal.poll_native import RawPollFd, poll_once, read_errno, is_eintr


# wait — bounded readiness wait for one descriptor.
def wait(fd: Int, events: PollEvents, timeout: PollTimeout) raises PollError -> PollEvents:
    if fd < 0:
        raise PollError(PollErrorKind.INVALID_FD, "wait", "fd is negative")
    if timeout.millis < 0 or timeout.millis > PollTimeout.MAX_MILLIS:
        raise PollError(PollErrorKind.INVALID_TIMEOUT, "wait", "timeout out of range")
    var raw = List[RawPollFd]()
    raw.append(RawPollFd(c_int(fd), c_short(events.bits()), c_short(0)))
    var remaining_ms = timeout.millis
    var deadline_ns = perf_counter_ns() + remaining_ms * 1_000_000
    while True:
        var n = poll_once(raw, remaining_ms)
        if n > 0:
            return PollEvents(UInt16(raw[0].revents))
        if n < 0:
            var code = read_errno()
            if not is_eintr(code):
                raise PollError(PollErrorKind.SYSCALL, "wait", String("errno ", code))
        # n == 0 (timeout) or EINTR: recompute the remaining bound.
        var remaining_ns = deadline_ns - perf_counter_ns()
        if remaining_ns <= 0:
            return PollEvents.NONE
        remaining_ms = (remaining_ns + 999_999) // 1_000_000
        if remaining_ms > PollTimeout.MAX_MILLIS:
            remaining_ms = PollTimeout.MAX_MILLIS

# API-DOCS-START
# wait — wait at most `timeout` milliseconds for one descriptor to become ready.
# Signature:
#   def wait(fd: Int, events: PollEvents, timeout: PollTimeout) raises PollError -> PollEvents
# What it does:
#   Blocks the calling thread until at least one of the requested `events` is
#   ready on `fd`, or until `timeout` elapses, whichever comes first. It never
#   blocks longer than the timeout. `timeout = PollTimeout.ZERO` performs
#   exactly one non-blocking poll and returns immediately. On a timeout it
#   returns PollEvents.NONE.
#   The returned mask reports what actually happened: the requested READ/WRITE
#   bits when satisfied, plus ERROR, HANGUP or INVALID, which poll(2) always
#   reports even when they were not requested. A bad or closed descriptor
#   surfaces as PollEvents.INVALID in the result, never as a raised error.
#   If a signal interrupts the wait, the library retries internally and
#   recomputes the remaining time, so the total wait still respects the timeout.
#   The descriptor is borrowed: os_poll never closes, duplicates or retains it.
# Returns:
#   The readiness bits as a PollEvents owned by the caller; PollEvents.NONE when
#   the timeout elapsed with nothing ready.
# Errors:
#   raises PollError with kind:
#     INVALID_TIMEOUT — timeout is negative or above PollTimeout.MAX_MILLIS.
#     INVALID_FD      — fd is negative.
#     SYSCALL         — poll(2) failed for another reason (the numeric code is in
#                       PollError.detail). All kinds are recoverable.
# Example:
#   var r = wait(fd, PollEvents.READ, PollTimeout(100))
#   if r == PollEvents.NONE:
#       print("nothing became ready in 100 ms")
#   elif r.is_readable():
#       print("readable")
# API-DOCS-END
