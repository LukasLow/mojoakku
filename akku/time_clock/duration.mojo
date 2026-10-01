from std.os import abort

from .time_error import TimeError


# Duration — a signed integer-nanosecond span with arithmetic and a total order.
struct Duration(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var _nanos: Int

    @doc_hidden
    def __init__(out self, nanos: Int):
        abort("MojoAkku: this API is not yet implemented")

    comptime ZERO = Duration(0)

    @staticmethod
    def from_nanos(n: Int) -> Self:
        abort("MojoAkku: this API is not yet implemented")

    @staticmethod
    def from_micros(n: Int) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    @staticmethod
    def from_millis(n: Int) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    @staticmethod
    def from_seconds(n: Int) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def as_nanos(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def as_micros(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def as_millis(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def as_seconds(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def is_zero(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def is_positive(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def is_negative(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def abs(self) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def __add__(self, rhs: Self) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def __sub__(self, rhs: Self) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def __neg__(self) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def scaled(self, factor: Int) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def divided_by(self, divisor: Int) raises TimeError -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def __lt__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def __le__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def __gt__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def __ge__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def compare(self, other: Self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

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
