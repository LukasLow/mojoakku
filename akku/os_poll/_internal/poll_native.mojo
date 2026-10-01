# poll_native — the private FFI boundary for os_poll. Not public API.
#
# poll(2) is called directly through std.ffi. Platform differences live here:
#   - nfds_t is c_ulong on Linux and c_uint on macOS.
#   - errno is read through __errno_location() on Linux and __error() on macOS.
# The library never retains a pointer across a call and never caches errno.

from std.ffi import external_call, c_int, c_short, c_uint, c_ulong
from std.sys import CompilationTarget as _Target


# RawPollFd mirrors C's struct pollfd exactly (int fd, short events, short revents).
struct RawPollFd(Copyable, Deinitable):
    var fd: c_int
    var events: c_short
    var revents: c_short

    def __init__(out self, fd: c_int, events: c_short, revents: c_short):
        self.fd = fd
        self.events = events
        self.revents = revents


comptime EINTR_VALUE = c_int(4)   # same numeric value on Linux and macOS


def read_errno() -> c_int:
    comptime if _Target.is_macos():
        return external_call["__error", Pointer[c_int, MutUntrackedOrigin]]()[]
    else:
        return external_call["__errno_location", Pointer[c_int, MutUntrackedOrigin]]()[]


def is_eintr(code: c_int) -> Bool:
    return code == EINTR_VALUE


# poll_once — one poll(2) call over the raw records in `raw` (milliseconds; 0 = probe).
# Returns the ready count (>=0) or -1 on failure (errno is left for read_errno()).
def poll_once(mut raw: List[RawPollFd], millis: Int) -> Int:
    comptime if _Target.is_macos():
        return Int(external_call["poll", c_int](
            raw.unsafe_ptr().unsafe_bitcast[NoneType](), c_uint(len(raw)), c_int(millis)
        ))
    else:
        return Int(external_call["poll", c_int](
            raw.unsafe_ptr().unsafe_bitcast[NoneType](), c_ulong(len(raw)), c_int(millis)
        ))
