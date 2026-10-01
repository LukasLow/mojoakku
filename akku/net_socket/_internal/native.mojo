"""Private platform boundary for net_socket.

Constants, errno access and the bounded-wait bridge to os_poll. Nothing here is
public: the public surface is SocketAddress and Socket. Everything
platform-specific (Linux vs macOS) lives here.
"""

from std.ffi import get_errno as _get_errno

from akku.io_core import IoError as _IoError, IoErrorKind as _IoErrorKind
from akku.os_poll import (
    wait as _poll_wait,
    PollEvents as _PollEvents,
    PollTimeout as _PollTimeout,
)
from akku.time_clock import Deadline as _Deadline
from std.sys import CompilationTarget as _Target


# --- address families, socket types, protocol levels -----------------------
comptime AF_INET = 2
comptime AF_INET6 = 30 if _Target.is_macos() else 10
comptime SOCK_STREAM = 1
comptime IPPROTO_TCP = 6
comptime IPPROTO_IPV6 = 41
comptime IPV6_V6ONLY = 27 if _Target.is_macos() else 26
comptime SOL_SOCKET = 0xFFFF if _Target.is_macos() else 1
comptime SO_NOSIGPIPE = 0x1022
comptime SO_ERROR = 0x1007 if _Target.is_macos() else 4
comptime MSG_NOSIGNAL = 0x4000

# --- shutdown directions ---------------------------------------------------
comptime SHUT_RD = 0
comptime SHUT_WR = 1

# --- descriptor flags ------------------------------------------------------
comptime O_NONBLOCK = 4 if _Target.is_macos() else 2048
comptime SOCK_NONBLOCK = 2048
comptime SOCK_CLOEXEC = 524288
comptime F_GETFD = 1
comptime F_SETFD = 2
comptime FD_CLOEXEC = 1
comptime F_GETFL = 3
comptime F_SETFL = 4

# --- errno values (differ per platform) ------------------------------------
comptime EINTR = 4
comptime EAGAIN = 35 if _Target.is_macos() else 11
comptime ETIMEDOUT = 60 if _Target.is_macos() else 110
comptime EBADF = 9
comptime EINPROGRESS = 36 if _Target.is_macos() else 115
comptime ECONNREFUSED = 61 if _Target.is_macos() else 111


def errno_value() -> Int:
    """Read the thread-local errno immediately after a failed native call."""
    return Int(_get_errno().value)


def map_error(code: Int, op: String) -> _IoError:
    """Map a native errno to the shared io_core error contract."""
    var kind = _IoErrorKind.OTHER
    if code == EINTR:
        kind = _IoErrorKind.INTERRUPTED
    elif code == EAGAIN:
        kind = _IoErrorKind.WOULD_BLOCK
    elif code == ETIMEDOUT:
        kind = _IoErrorKind.TIMED_OUT
    elif code == EBADF:
        kind = _IoErrorKind.CLOSED
    return _IoError(kind, op, String("native errno ", code))


def await_ready(
    fd: Int, events: _PollEvents, deadline: Optional[_Deadline], op: String
) raises _IoError:
    """Wait until `events` is ready on `fd`, honouring an optional deadline.

    Every native poll is bounded: with a deadline the loop stops and raises
    TIMED_OUT; without one it keeps polling a very long slice, which preserves
    ordinary blocking semantics while never issuing an unbounded syscall. A
    closed descriptor surfaces as CLOSED, a deadline as TIMED_OUT, and any
    other poll failure as OTHER.
    """
    while True:
        var ms = -1
        if deadline:
            var d = deadline.value()
            if d.is_expired():
                raise _IoError(_IoErrorKind.TIMED_OUT, op, "deadline exceeded")
            var ns: Int
            try:
                ns = d.remaining().as_nanos()
            except:
                raise _IoError(_IoErrorKind.TIMED_OUT, op, "deadline exceeded")
            ms = (ns + 999_999) // 1_000_000
            if ms == 0:
                raise _IoError(_IoErrorKind.TIMED_OUT, op, "deadline exceeded")
        var timeout = _PollTimeout.MAX if ms < 0 else _PollTimeout.clamped(ms)
        var ready: _PollEvents
        try:
            ready = _poll_wait(fd, events, timeout)
        except:
            raise _IoError(_IoErrorKind.OTHER, op, "readiness wait failed")
        if ready.is_empty():
            if ms < 0:
                continue
            raise _IoError(_IoErrorKind.TIMED_OUT, op, "deadline exceeded")
        if ready.is_invalid():
            raise _IoError(_IoErrorKind.CLOSED, op, "invalid descriptor")
        return
