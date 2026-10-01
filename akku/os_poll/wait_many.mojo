from std.ffi import c_int, c_short
from std.time import perf_counter_ns

from .poll_error_kind import PollErrorKind
from .poll_fd import PollFd
from .poll_events import PollEvents
from .poll_timeout import PollTimeout
from .poll_error import PollError
from akku.os_poll._internal.poll_native import RawPollFd, poll_once, read_errno, is_eintr


# wait_many — bounded readiness wait for a caller-owned set of descriptors.
def wait_many(mut fds: MutSpan[PollFd, _], timeout: PollTimeout) raises PollError -> Int:
    if timeout.millis < 0 or timeout.millis > PollTimeout.MAX_MILLIS:
        raise PollError(PollErrorKind.INVALID_TIMEOUT, "wait_many", "timeout out of range")
    var count = len(fds)
    if count == 0:
        return 0
    var raw = List[RawPollFd]()
    for i in range(count):
        fds[i].clear()
        raw.append(RawPollFd(c_int(fds[i].fd), c_short(fds[i].events.bits()), c_short(0)))
    var remaining_ms = timeout.millis
    var deadline_ns = perf_counter_ns() + remaining_ms * 1_000_000
    while True:
        var n = poll_once(raw, remaining_ms)
        if n > 0:
            break
        if n < 0:
            var code = read_errno()
            if not is_eintr(code):
                raise PollError(PollErrorKind.SYSCALL, "wait_many", String("errno ", code))
        var remaining_ns = deadline_ns - perf_counter_ns()
        if remaining_ns <= 0:
            break
        remaining_ms = (remaining_ns + 999_999) // 1_000_000
        if remaining_ms > PollTimeout.MAX_MILLIS:
            remaining_ms = PollTimeout.MAX_MILLIS
    var ready = 0
    for i in range(count):
        fds[i].revents = PollEvents(UInt16(raw[i].revents))
        if not fds[i].revents.is_empty():
            ready += 1
    return ready

# API-DOCS-START
# wait_many — wait at most `timeout` ms for any descriptor in the set to be ready.
# Signature:
#   def wait_many(mut fds: MutSpan[PollFd, _], timeout: PollTimeout) raises PollError -> Int
# What it does:
#   Waits until at least one descriptor in the caller-owned `fds` set is ready,
#   or until `timeout` elapses. It first clears every entry's `revents`, then
#   polls the whole set and writes each result back into the caller's records.
#   It returns the number of entries whose `revents` is non-empty; `0` means the
#   timeout elapsed (not an error). `timeout = PollTimeout.ZERO` performs exactly
#   one non-blocking poll. An empty set returns 0 immediately without sleeping.
#   Entries with a negative fd are skipped. If a signal interrupts the wait, the
#   library retries internally and recomputes the remaining time, so the total
#   wait respects the timeout. The descriptors are borrowed; os_poll never
#   closes, duplicates or retains them, and it allocates no result container of
#   its own.
# Returns:
#   The count of ready entries (0 .. len(fds)); 0 means the timeout elapsed.
# Errors:
#   raises PollError with kind:
#     INVALID_TIMEOUT — timeout is negative or above PollTimeout.MAX_MILLIS.
#     SYSCALL         — poll(2) failed (the numeric code is in PollError.detail).
#   A closed-but-valid descriptor is reported as PollEvents.INVALID in that
#   entry's revents, not as a raised error. All kinds are recoverable.
# Example:
#   var fds = List[PollFd]()
#   fds.append(PollFd(fd_a, PollEvents.READ))
#   fds.append(PollFd(fd_b, PollEvents.WRITE))
#   var n = wait_many(fds, PollTimeout(100))
#   if n == 0:
#       print("nothing ready in 100 ms")
# API-DOCS-END
