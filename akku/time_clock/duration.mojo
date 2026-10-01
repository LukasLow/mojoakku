from akku.time_clock._internal.time_math import checked_add, checked_div, checked_mul, checked_sub
from akku.time_clock.time_error import TimeError


# Duration — a signed integer-nanosecond span with arithmetic and a total order.
struct Duration(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var _nanos: Int

    @doc_hidden
    def __init__(out self, nanos: Int):
        self._nanos = nanos

    comptime ZERO = Duration(0)

    @staticmethod
    def from_nanos(n: Int) -> Self:
        return Self(n)

    @staticmethod
    def from_micros(n: Int) raises TimeError -> Self:
        return Self(checked_mul(n, 1_000, "Duration.from_micros"))

    @staticmethod
    def from_millis(n: Int) raises TimeError -> Self:
        return Self(checked_mul(n, 1_000_000, "Duration.from_millis"))

    @staticmethod
    def from_seconds(n: Int) raises TimeError -> Self:
        return Self(checked_mul(n, 1_000_000_000, "Duration.from_seconds"))

    def as_nanos(self) -> Int:
        return self._nanos

    def as_micros(self) -> Int:
        # Truncates toward zero (Mojo `/` on Int), never floors.
        return self._nanos / 1_000

    def as_millis(self) -> Int:
        return self._nanos / 1_000_000

    def as_seconds(self) -> Int:
        return self._nanos / 1_000_000_000

    def is_zero(self) -> Bool:
        return self._nanos == 0

    def is_positive(self) -> Bool:
        return self._nanos > 0

    def is_negative(self) -> Bool:
        return self._nanos < 0

    def abs(self) raises TimeError -> Self:
        if self._nanos < 0:
            # Negation is checked: abs(MIN) needs 2^63, which is not representable.
            return -self
        return Self(self._nanos)

    def __add__(self, rhs: Self) raises TimeError -> Self:
        return Self(checked_add(self._nanos, rhs._nanos, "Duration.__add__"))

    def __sub__(self, rhs: Self) raises TimeError -> Self:
        return Self(checked_sub(self._nanos, rhs._nanos, "Duration.__sub__"))

    def __neg__(self) raises TimeError -> Self:
        return Self(checked_sub(0, self._nanos, "Duration.__neg__"))

    def scaled(self, factor: Int) raises TimeError -> Self:
        return Self(checked_mul(self._nanos, factor, "Duration.scaled"))

    def divided_by(self, divisor: Int) raises TimeError -> Self:
        return Self(checked_div(self._nanos, divisor, "Duration.divided_by"))

    def __lt__(self, other: Self) -> Bool:
        return self._nanos < other._nanos

    def __le__(self, other: Self) -> Bool:
        return self._nanos <= other._nanos

    def __gt__(self, other: Self) -> Bool:
        return self._nanos > other._nanos

    def __ge__(self, other: Self) -> Bool:
        return self._nanos >= other._nanos

    def compare(self, other: Self) -> Int:
        if self._nanos < other._nanos:
            return -1
        if self._nanos > other._nanos:
            return 1
        return 0

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Duration(", self._nanos, "ns)")

# API-DOCS-START
# Duration — a signed span of time, stored as an integer number of nanoseconds.
# Signature:
#   struct Duration(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
#       var _nanos: Int
#       @doc_hidden
#       def __init__(out self, nanos: Int)
#       comptime ZERO = Duration(0)
#       @staticmethod def from_nanos(n: Int) -> Self
#       @staticmethod def from_micros(n: Int) raises TimeError -> Self
#       @staticmethod def from_millis(n: Int) raises TimeError -> Self
#       @staticmethod def from_seconds(n: Int) raises TimeError -> Self
#       def as_nanos(self) -> Int
#       def as_micros(self) -> Int
#       def as_millis(self) -> Int
#       def as_seconds(self) -> Int
#       def is_zero / is_positive / is_negative(self) -> Bool
#       def abs(self) raises TimeError -> Self
#       def __add__(self, rhs: Self) raises TimeError -> Self
#       def __sub__(self, rhs: Self) raises TimeError -> Self
#       def __neg__(self) raises TimeError -> Self
#       def scaled(self, factor: Int) raises TimeError -> Self
#       def divided_by(self, divisor: Int) raises TimeError -> Self
#       def __lt__ / __le__ / __gt__ / __ge__(self, other: Self) -> Bool
#       def compare(self, other: Self) -> Int
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   A signed span of time in nanoseconds. It is one Int, so there is no float
#   path and no precision loss. Construct it with a unit constructor
#   (from_nanos/from_micros/from_millis/from_seconds); read it back with the
#   matching as_* accessors, which truncate toward zero. Duration.ZERO is the
#   additive identity. The sign predicates classify a span, abs gives its
#   magnitude, and add/sub/negate/scaled/divided_by do the arithmetic. The
#   comparison set is a total order on the nanosecond count.
#   Every fallible operation raises TimeError instead of wrapping: the result
#   never silently overflows.
# Returns:
#   A copyable value type, owned by the caller. from_* return a new Duration;
#   as_* return a plain Int; the predicates and comparisons return a Bool;
#   compare returns -1, 0 or 1.
# Errors:
#   raises TimeError.
#     OVERFLOW         — from_micros/from_millis/from_seconds when the unit
#                        scaling does not fit; __add__/__sub__/__neg__/scaled;
#                        abs of the single most-negative span; and divided_by
#                        for MIN / -1, whose quotient has no Int representation.
#     DIVISION_BY_ZERO — divided_by(0).
#   All are recoverable: retry with smaller operands, a different unit, a
#   non-zero divisor, or a divisor other than -1. No condition is fatal.
# Example:
#   Duration.from_seconds(2).as_millis()          # -> 2000
#   (Duration.from_nanos(5) + Duration.ZERO).as_nanos()   # -> 5
#   Duration.from_millis(1500).divided_by(1000)  # -> 1s (truncating)
#   Duration.from_nanos(-1).as_seconds()         # -> 0 (truncates toward zero)
#   try:
#       _ = Duration.from_millis(9_000_000_000_000_000)
#   except e:
#       print(e.kind)                            # -> OVERFLOW
# API-DOCS-END
