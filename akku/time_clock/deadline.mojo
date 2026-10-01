from akku.time_clock._internal.time_math import checked_add, checked_sub
from akku.time_clock.clock import Clock
from akku.time_clock.duration import Duration
from akku.time_clock.time_error import TimeError


# Deadline — an opaque monotonic instant; only differences are meaningful.
struct Deadline(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var _t: Int

    @doc_hidden
    def __init__(out self, t: Int):
        self._t = t

    def __add__(self, rhs: Duration) raises TimeError -> Self:
        return Self(checked_add(self._t, rhs.as_nanos(), "Deadline.__add__"))

    def __sub__(self, rhs: Duration) raises TimeError -> Self:
        return Self(checked_sub(self._t, rhs.as_nanos(), "Deadline.__sub__"))

    def __sub__(self, rhs: Self) raises TimeError -> Duration:
        return Duration.from_nanos(checked_sub(self._t, rhs._t, "Deadline.__sub__"))

    def __lt__(self, other: Self) -> Bool:
        return self._t < other._t

    def __le__(self, other: Self) -> Bool:
        return self._t <= other._t

    def __gt__(self, other: Self) -> Bool:
        return self._t > other._t

    def __ge__(self, other: Self) -> Bool:
        return self._t >= other._t

    def compare(self, other: Self) -> Int:
        if self._t < other._t:
            return -1
        if self._t > other._t:
            return 1
        return 0

    def is_expired(self) -> Bool:
        # Clock.now() >= self, with NO addition: overflow-safe.
        return Clock.now()._t >= self._t

    def remaining(self) raises TimeError -> Duration:
        return Duration.from_nanos(
            checked_sub(self._t, Clock.now()._t, "Deadline.remaining")
        )

    def elapsed(self) raises TimeError -> Duration:
        return Duration.from_nanos(
            checked_sub(Clock.now()._t, self._t, "Deadline.elapsed")
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Deadline(", self._t, ")")

# API-DOCS-START
# Deadline — a point on the monotonic timeline; its absolute value is meaningless.
# Signature:
#   struct Deadline(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
#       var _t: Int
#       @doc_hidden
#       def __init__(out self, t: Int)
#       def __add__(self, rhs: Duration) raises TimeError -> Self
#       def __sub__(self, rhs: Duration) raises TimeError -> Self
#       def __sub__(self, rhs: Self) raises TimeError -> Duration
#       def __lt__ / __le__ / __gt__ / __ge__(self, other: Self) -> Bool
#       def compare(self, other: Self) -> Int
#       def is_expired(self) -> Bool
#       def remaining(self) raises TimeError -> Duration
#       def elapsed(self) raises TimeError -> Duration
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   An instant on the monotonic clock with no raw-tick accessor: only
#   differences between two Deadlines are meaningful. A Deadline is never
#   constructed by a caller; the producers are Clock.now() and Deadline +/-
#   Duration. `deadline + duration` shifts it forward, `deadline - duration`
#   shifts it backward — the canonical timeout is Clock.now() + timeout. A
#   difference `a - b` is a signed Duration: positive when a is later, negative
#   when a is earlier. Comparisons form a total order and involve no addition,
#   so they are overflow-safe. is_expired() is Clock.now() >= self and never
#   raises; remaining() is self - Clock.now() (positive while time is left,
#   negative once expired) and elapsed() is its mirror image.
# Returns:
#   A copyable value type, owned by the caller. +/- Duration and Deadline -
#   Deadline return a new value; is_expired returns a Bool; compare returns
#   -1, 0 or 1; remaining/elapsed return a signed Duration.
# Errors:
#   raises TimeError.
#     OVERFLOW — __add__/__sub__(Duration), and (only at the Int extreme)
#                __sub__(Deadline), remaining() and elapsed().
#   Recoverable: clamp the duration or choose a nearer deadline. is_expired and
#   the whole comparison set never raise. An expired deadline is a normal
#   outcome, not an error.
# Example:
#   var deadline = Clock.now() + Duration.from_seconds(30)
#   deadline.is_expired()                     # -> False
#   deadline.remaining().is_positive()       # -> True
#   (deadline + Duration.from_seconds(1)) > deadline   # -> True
#   (Clock.now() - deadline).is_negative()   # -> True (already elapsed)
# API-DOCS-END
