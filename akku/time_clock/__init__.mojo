# MojoAkku time — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from akku.time_clock import ...` works. Nothing else lives here: the public
# surface is defined by the per-entry files and this file only forwards names.

from .time_error_kind import TimeErrorKind
from .time_error import TimeError
from .duration import Duration
from .deadline import Deadline
from .clock import Clock

# API-DOCS-START
# Purpose   — akku/time_clock is the time layer for MojoAkku: a monotonic Clock,
#   a signed integer-nanosecond Duration (a span with arithmetic) and an opaque
#   Deadline (an instant on that clock with arithmetic), plus the clock/time
#   error surface. It is pure and in-process — no files, sockets, threads or
#   global state — and it supplies the typed span/instant arithmetic the Mojo
#   standard library's raw time.monotonic() nanoseconds lack. Release 1 is
#   monotonic time only; wall-clock time, calendar dates and blocking sleep are
#   deliberately deferred.
# Overview  — three public value types and one typed error, all built on a single
#   primitive. The mental model is three sentences:
#     1. Clock.now() gives a Deadline whose absolute value is meaningless — the
#        origin is undefined and platform-specific, so only differences are valid.
#     2. Deadline + Duration is the canonical timeout composition, and
#        Clock.now() >= deadline is the canonical expiry test.
#     3. Duration is what you get from Deadline - Deadline, and it is signed, so a
#        negative result is the ordinary "it is already too late" case, not an
#        error.
#   All durations are integer nanoseconds; there is no float path. Every fallible
#   arithmetic operation raises instead of silently wrapping. All three value
#   types are copyable, and Clock is a stateless static entry point.
# Dependencies — none. time_clock is a leaf: it depends only on the Mojo standard
#   library (Int, UInt8, Bool, String, Some[Writer], std.time.monotonic). Later
#   libraries (net_socket, async_scheduler, ...) point to time_clock, never the
#   reverse.
# Public API — the ordered index (each entry is specified in its own file):
#    1. Duration      — a signed integer-nanosecond span with unit constructors
#                       and accessors, sign predicates, abs, raising
#                       add/sub/negate/scaled/divided_by and a total order.
#    2. Deadline      — an opaque monotonic instant (one Int, no raw accessor)
#                       with +/- Duration, Deadline - Deadline -> Duration, a
#                       total order and the is_expired/remaining/elapsed queries.
#    3. Clock         — the one monotonic clock entry point: static now() ->
#                       Deadline backed by std.time.monotonic().
#    4. TimeErrorKind — the closed two-value discriminant for TimeError:
#                       OVERFLOW, DIVISION_BY_ZERO.
#    5. TimeError     — the one typed error: kind: TimeErrorKind, detail: String;
#                       Writable.
# Error Surface — exactly one error type, TimeError, carrying kind: TimeErrorKind
#   and detail: String. Which API raises what:
#     Duration.from_micros / from_millis / from_seconds  — OVERFLOW
#     Duration.__add__ / __sub__ / __neg__ / scaled      — OVERFLOW
#     Duration.divided_by                                — DIVISION_BY_ZERO
#                                                          (divisor 0); OVERFLOW
#                                                          (MIN / -1)
#     Duration.abs                                       — OVERFLOW (only the
#                                                          single most-negative
#                                                          span)
#     Deadline.__add__ and __sub__(Duration)             — OVERFLOW
#     Deadline.__sub__(Deadline)                         — OVERFLOW (only at the
#                                                          Int extreme)
#     Deadline.remaining / elapsed                       — OVERFLOW (only at the
#                                                          Int extreme)
#     Duration.as_* / is_*, all comparisons,
#       Deadline.is_expired, all comparisons,
#       Clock.now, TimeErrorKind / TimeError construction — none
#   All conditions are recoverable data errors: retry with smaller operands, a
#   different unit, or a non-zero divisor. Expiry is not an error; it is reported
#   by Deadline.is_expired() and a non-positive remaining(). Callers branch on
#   `kind`, never on the opaque `detail` string. `print(e)` gives a readable
#   kind + detail message.
# Conventions — names are stable; the span is one signed Int in nanoseconds and
#   the instant is one opaque Int. All as_*/divided_by accessors truncate toward
#   zero. Ranges and comparison results follow compare() returning -1/0/1. One
#   monotonic clock only; the instant is opaque (no raw-tick accessor). Value
#   semantics throughout with no hidden global state; TimeError is Copyable but
#   not ImplicitlyCopyable, so a re-raise transfers with `raise e^`.
# API-DOCS-END
