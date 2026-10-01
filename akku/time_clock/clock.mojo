from std.time import monotonic

from .deadline import Deadline


# Clock — the one monotonic clock entry point.
struct Clock:
    @staticmethod
    def now() -> Deadline:
        return Deadline(monotonic())

# API-DOCS-START
# Clock — the one place to read the monotonic clock.
# Signature:
#   struct Clock:
#       @staticmethod
#       def now() -> Deadline
# What it does:
#   Clock is a stateless namespace with exactly one method: now() returns a
#   Deadline wrapping the current monotonic-clock reading. There is no
#   clock-id argument, no template clock and no second (wall) clock.
#   The clock is monotonic: it never moves backwards. Its origin is undefined
#   and platform-specific — a reading is not a date, not an epoch offset and not
#   comparable across processes or boots. Only the difference of two readings
#   (a Duration) is valid. now() never blocks and never fails.
# Returns:
#   A Deadline by value, owned by the caller.
# Errors:
#   none — reading a monotonic register cannot fail.
# Example:
#   var start = Clock.now()
#   # ... work ...
#   var elapsed = Clock.now() - start      # a Duration
#   var deadline = Clock.now() + Duration.from_millis(250)
#   while Clock.now() < deadline:
#       pass
# API-DOCS-END
