# MojoAkku os_poll — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from akku.os_poll import ...` works. Nothing else lives here: the public
# surface is defined by the per-entry files and this file only forwards names.

from .poll_events import PollEvents
from .poll_error_kind import PollErrorKind
from .poll_error import PollError
from .poll_timeout import PollTimeout
from .poll_fd import PollFd
from .wait import wait
from .wait_many import wait_many

# API-DOCS-START
# Purpose   — akku/os_poll is the readiness layer for MojoAkku: it answers "which
#   of these file descriptors is readable, writable or broken, waiting at most
#   this long?" by calling POSIX poll(2) through a small, predictable value API.
#   It supplies the readiness primitive the Mojo standard library lacks, so a
#   networking library (for example the future net_socket) can make every wait
#   timeout-bounded in code instead of relying on an external `timeout` binary.
#   It targets Linux and macOS.
# Overview  — one uniform shape. A single bitmask type, PollEvents, is used both
#   as the interest mask and as the result mask. A single timeout type,
#   PollTimeout, carries milliseconds only and is bounded by construction — there
#   is no infinite form. PollFd is one descriptor record (fd, interest, result).
#   Two entry points do the waiting: wait for one descriptor (returns its
#   readiness mask) and wait_many for a caller-owned set (returns the ready
#   count). A timeout is not an error: it is PollEvents.NONE / a count of 0.
#   os_poll is strictly synchronous and single-threaded — no event loop, no
#   callbacks, no registration state and no O_NONBLOCK requirement. It never
#   owns or closes a descriptor; it only reads a borrowed descriptor number.
# Dependencies — none. os_poll is a leaf: it uses only the Mojo standard library
#   (std.ffi for poll(2), std.sys for the Linux/macOS split, std.time for the
#   EINTR timeout recomputation). Later libraries point to os_poll, never the
#   reverse. Consumers that already speak io_core's IoError map PollError at
#   their own boundary.
# Public API — the ordered index (each entry is specified in its own file):
#    1. PollEvents   — the readiness bitmask: READ, WRITE, ERROR, HANGUP,
#                      INVALID, PRIORITY and the empty NONE.
#    2. PollErrorKind — closed reason: INVALID_TIMEOUT, INVALID_FD, SYSCALL.
#    3. PollError    — the one typed error: kind, op, detail.
#    4. PollTimeout  — a bounded timeout in milliseconds (no infinite form).
#    5. PollFd       — one descriptor record: fd, events, revents.
#    6. wait         — bounded wait for one descriptor; returns its readiness.
#    7. wait_many    — bounded wait for a caller-owned set; returns the ready
#                      count.
# Error Surface — exactly one error type, PollError, carrying kind:
#   PollErrorKind, op: String and detail: String. Only wait and wait_many can
#   raise; a timeout is never an error. Interruption (EINTR) is retried inside
#   the library and never surfaces. A closed descriptor is reported as
#   PollEvents.INVALID in the result, not raised.
# Conventions — one timeout unit (milliseconds); masks compose with `|` and are
#   tested with contains/is_*; a wait is bounded by construction; descriptors are
#   borrowed and the library holds no hidden global state; the synchronous core
#   has no async/await.
# API-DOCS-END
