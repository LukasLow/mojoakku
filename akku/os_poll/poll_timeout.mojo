from std.os import abort


# PollTimeout — a bounded wait, in milliseconds. There is no infinite form.
struct PollTimeout(ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var millis: Int

    comptime MAX_MILLIS = 2_147_483_647
    comptime ZERO = PollTimeout(0)
    comptime MAX  = PollTimeout(2_147_483_647)

    def __init__(out self, millis: Int):
        self.millis = millis

    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    @staticmethod
    def clamped(millis: Int) -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def is_zero(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# PollTimeout — a bounded wait, in milliseconds. There is no infinite form.
# Signature:
#   struct PollTimeout(ImplicitlyCopyable, Deinitable, Equatable, Writable):
#       var millis: Int
#       comptime MAX_MILLIS = 2_147_483_647
#       comptime ZERO = PollTimeout(0)
#       comptime MAX  = PollTimeout(2_147_483_647)
#       def __init__(out self, millis: Int)
#       def __eq__(self, other: Self) -> Bool
#       @staticmethod
#       def clamped(millis: Int) -> Self
#       def is_zero(self) -> Bool
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   The wait duration, always in milliseconds, always bounded: the valid range is
#   0 (poll once and return immediately) up to MAX_MILLIS (2_147_483_647, about
#   24.8 days), which is the largest value poll(2) accepts. ZERO and MAX are the
#   two ends as constants. The constructor stores the value as given; a wait call
#   validates the range and raises PollError(INVALID_TIMEOUT) outside it, so an
#   over-large timeout is never silently treated as "wait forever". clamped(n)
#   saturates instead: a negative n becomes ZERO and anything above MAX_MILLIS
#   becomes MAX, which never fails.
#   There is deliberately no "infinite" timeout: os_poll only offers bounded
#   waits. A caller who wants to wait indefinitely loops until a readiness
#   result is returned.
# Returns:
#   A value type. clamped returns a saturated PollTimeout owned by the caller.
# Errors:
#   The constructor cannot fail. An out-of-range value surfaces later as
#   PollError(INVALID_TIMEOUT) from wait/wait_many; use clamped() to avoid it.
# Example:
#   var quick = PollTimeout(50)          # wait up to 50 ms
#   var probe = PollTimeout.ZERO         # one non-blocking poll
#   var safe = PollTimeout.clamped(step) # never out of range
# API-DOCS-END
