from .poll_error_kind import PollErrorKind


# PollError — the one typed error every fallible readiness call declares.
@fieldwise_init
struct PollError(Copyable, Deinitable, Writable):
    var kind: PollErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# PollError — the one typed error every fallible readiness call declares.
# Signature:
#   @fieldwise_init
#   struct PollError(Copyable, Deinitable, Writable):
#       var kind: PollErrorKind
#       var op: String
#       var detail: String
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when a wait fails; you read it in an except/try
#   block. It carries:
#     kind   — what went wrong (see PollErrorKind).
#     op     — a short operation name ("wait" or "wait_many"), so you can tell
#              which call failed.
#     detail — an opaque, human-readable string. It must not be parsed; it is not
#              part of the API surface.
#   A timeout is NOT a PollError: it is an empty result (PollEvents.NONE or a
#   ready count of 0). It implements Writable, so `print(e)` yields a readable
#   kind + operation + detail message. It is Copyable but deliberately not
#   ImplicitlyCopyable, so a re-raise must transfer with `raise e^`.
# Returns:
#   Raised, never returned. Every condition is recoverable: correct the timeout
#   or the descriptor, or handle the raw syscall failure.
# Errors:
#   none — PollError *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = wait(fd, PollEvents.READ, PollTimeout(50))
#   except e:
#       print(e.kind)      # -> INVALID_TIMEOUT
#       print(e.op)        # -> wait
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
