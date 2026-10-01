from std.ffi import c_short as _c_short


# PollEvents — the portable fd-readiness bitmask, used as interest and as result.
struct PollEvents(Copyable, Deinitable, Equatable, Writable):
    var _bits: UInt16

    @doc_hidden
    def __init__(out self, bits: UInt16):
        self._bits = bits

    # The six bit values are identical on Linux and macOS poll(2).
    comptime NONE     = PollEvents(0x0000)
    comptime READ     = PollEvents(0x0001)   # POLLIN
    comptime PRIORITY = PollEvents(0x0002)   # POLLPRI
    comptime WRITE    = PollEvents(0x0004)   # POLLOUT
    comptime ERROR    = PollEvents(0x0008)   # POLLERR
    comptime HANGUP   = PollEvents(0x0010)   # POLLHUP
    comptime INVALID  = PollEvents(0x0020)   # POLLNVAL

    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def bits(self) -> UInt16:
        abort("MojoAkku: this API is not yet implemented")

    def is_empty(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def __bool__(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def contains(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def is_readable(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def is_writable(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def has_error(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def has_hangup(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def is_invalid(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def __or__(self, other: Self) -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def __and__(self, other: Self) -> Self:
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# PollEvents — the portable fd-readiness bitmask, used as interest and as result.
# Signature:
#   struct PollEvents(Copyable, Deinitable, Equatable, Writable):
#       var _bits: UInt16
#       @doc_hidden
#       def __init__(out self, bits: UInt16)
#       comptime NONE     = PollEvents(0x0000)
#       comptime READ     = PollEvents(0x0001)
#       comptime PRIORITY = PollEvents(0x0002)
#       comptime WRITE    = PollEvents(0x0004)
#       comptime ERROR    = PollEvents(0x0008)
#       comptime HANGUP   = PollEvents(0x0010)
#       comptime INVALID  = PollEvents(0x0020)
#       def __eq__(self, other: Self) -> Bool
#       def bits(self) -> UInt16
#       def is_empty(self) -> Bool
#       def __bool__(self) -> Bool
#       def contains(self, other: Self) -> Bool
#       def is_readable(self) -> Bool
#       def is_writable(self) -> Bool
#       def has_error(self) -> Bool
#       def has_hangup(self) -> Bool
#       def is_invalid(self) -> Bool
#       def __or__(self, other: Self) -> Self
#       def __and__(self, other: Self) -> Self
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   One value type is used both as the interest mask (the events you ask wait to
#   watch for) and as the result mask (the events that actually occurred). READ
#   and WRITE are the events you normally request. ERROR, HANGUP and INVALID are
#   always reported by poll(2) even when you did not ask for them, so checking
#   them on a result is always meaningful. PRIORITY is the portable "urgent
#   data" bit. NONE is the empty set; a wait that times out returns NONE.
#   Combine interest bits with `|`, intersect with `&`, and test with
#   `contains(other)` (true when every bit of other is present) or the named
#   predicates is_readable, is_writable, has_error, has_hangup, is_invalid.
#   The six bit values are identical on Linux and macOS, so a mask built on one
#   target means the same thing on the other.
# Returns:
#   A value type. `|` and `&` return a new PollEvents owned by the caller.
# Errors:
#   none — it is a pure value type and cannot fail.
# Example:
#   var want = PollEvents.READ | PollEvents.WRITE
#   if want.contains(PollEvents.READ):
#       print("watching for reads")
#   var ready: PollEvents = wait(fd, want, PollTimeout(100))
#   if ready == PollEvents.NONE:
#       print("timed out")
#   elif ready.has_hangup():
#       print("peer closed")
# API-DOCS-END
