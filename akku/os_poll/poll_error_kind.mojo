# PollErrorKind — the closed reason a readiness wait failed.
struct PollErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    def __eq__(self, other: Self) -> Bool:
        return self._id == other._id

    comptime INVALID_TIMEOUT = PollErrorKind(0)   # the timeout is negative or too large
    comptime INVALID_FD      = PollErrorKind(1)   # a single-fd wait was given a negative fd
    comptime SYSCALL         = PollErrorKind(2)   # any other poll(2) failure

    def write_to(self, mut writer: Some[Writer]):
        # Symbolic names, not the numeric _id.
        if self._id == 0:
            writer.write("INVALID_TIMEOUT")
        elif self._id == 1:
            writer.write("INVALID_FD")
        else:
            writer.write("SYSCALL")

# API-DOCS-START
# PollErrorKind — the machine-testable reason a readiness wait failed.
# Signature:
#   struct PollErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime INVALID_TIMEOUT = PollErrorKind(0)
#       comptime INVALID_FD      = PollErrorKind(1)
#       comptime SYSCALL         = PollErrorKind(2)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from PollError.kind inside an except block; it is never
#   constructed or passed by a caller. The three kinds are the complete, closed
#   set:
#     INVALID_TIMEOUT — the timeout is negative or exceeds PollTimeout.MAX_MILLIS.
#     INVALID_FD      — a single-descriptor wait was given a negative fd.
#     SYSCALL         — any other poll(2) failure; the numeric value is in
#                       PollError.detail.
#   There is no INTERRUPTED kind: EINTR is retried inside the library and can
#   never surface. There is no CLOSED kind: a bad or closed descriptor is
#   reported as PollEvents.INVALID in the result, not as a raised error.
#   It also implements Writable, so printing a kind shows its symbolic name.
# Returns:
#   A value type; reading `.kind` returns a PollErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = wait(fd, PollEvents.READ, PollTimeout(50))
#   except e:
#       if e.kind == PollErrorKind.INVALID_FD:
#           print("bad descriptor")
#   print(PollErrorKind.INVALID_TIMEOUT)   # -> INVALID_TIMEOUT
# API-DOCS-END
