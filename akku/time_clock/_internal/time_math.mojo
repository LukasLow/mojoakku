# time_clock — private checked-arithmetic core.
#
# Shared by `Duration` (add/sub/negate/scaled/divided_by and the unit-scaling
# constructors) and `Deadline` (add/sub of a Duration and the signed difference
# / queries). Every operation is computed once in a 128-bit carrier so an `Int`
# overflow is detected instead of wrapping — Mojo integer arithmetic wraps under
# two's complement and does not trap (`mojov1/reference/numeric-types`,
# "Integer arithmetic wraps on overflow"). The library's contract is to raise
# the single `TimeError` instead.

from akku.time_clock.time_error import TimeError
from akku.time_clock.time_error_kind import TimeErrorKind


# _fits — True when a 128-bit intermediate is a representable `Int`.
def _fits(v: Int128) -> Bool:
    return v >= Int128(Int.MIN) and v <= Int128(Int.MAX)


# checked_add — a + b, raising OVERFLOW when the result leaves the `Int` range.
def checked_add(a: Int, b: Int, op: String) raises TimeError -> Int:
    var wide = Int128(a) + Int128(b)
    if not _fits(wide):
        raise TimeError(TimeErrorKind.OVERFLOW, op)
    return Int(wide)


# checked_sub — a - b, raising OVERFLOW when the result leaves the `Int` range.
def checked_sub(a: Int, b: Int, op: String) raises TimeError -> Int:
    var wide = Int128(a) - Int128(b)
    if not _fits(wide):
        raise TimeError(TimeErrorKind.OVERFLOW, op)
    return Int(wide)


# checked_mul — a * b, raising OVERFLOW when the result leaves the `Int` range.
def checked_mul(a: Int, b: Int, op: String) raises TimeError -> Int:
    var wide = Int128(a) * Int128(b)
    if not _fits(wide):
        raise TimeError(TimeErrorKind.OVERFLOW, op)
    return Int(wide)


# checked_div — a / b (truncating toward zero); DIVISION_BY_ZERO for b == 0 and
# OVERFLOW for MIN / -1, whose true quotient 2^63 has no `Int` representation.
def checked_div(a: Int, b: Int, op: String) raises TimeError -> Int:
    if b == 0:
        raise TimeError(TimeErrorKind.DIVISION_BY_ZERO, op)
    var wide = Int128(a) / Int128(b)
    if not _fits(wide):
        raise TimeError(TimeErrorKind.OVERFLOW, op)
    return Int(wide)
