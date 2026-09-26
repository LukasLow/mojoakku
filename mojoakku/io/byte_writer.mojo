from std.os import abort

from .io_error import IoError


# ByteWriter — one required buffer method plus provided helpers.
trait ByteWriter:
    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int: ...

    def write_all(mut self, data: Span[UInt8, _]) raises IoError:
        abort("MojoAkku: this API is not yet implemented")

    def flush(mut self) raises IoError:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# ByteWriter — write raw bytes from a borrowed buffer to a stream.
# Signature:
#   trait ByteWriter:
#       def write(mut self, data: Span[UInt8, _]) raises IoError -> Int
#       def write_all(mut self, data: Span[UInt8, _]) raises IoError
#       def flush(mut self) raises IoError
# What it does:
#   `data` is borrowed immutably for the call only; the stream never retains it.
#   `write` accepts a prefix 0 <= n <= len(data) and returns n; a short write is
#   normal and is not an error. `write_all` is a provided helper that loops until
#   every byte is written or raises (kind OTHER, "write zero") if `write` returns
#   0 without an error; it retries INTERRUPTED. `flush` pushes any buffered bytes
#   to the underlying sink and is explicit and fallible — no destructor performs
#   a silent flush. This trait is not an owned handle; CLOSED is raised only when
#   a wrapped handle is closed.
# Returns:
#   `write` returns the number of bytes accepted (an Int); `write_all` and
#   `flush` return nothing.
# Errors:
#   raises IoError. A short return from `write` is not an error; `write_all`
#   raises OTHER on a zero write; `flush` reports errors instead of swallowing
#   them.
# Example:
#   # data is a borrowed Span[UInt8, _] over your bytes
#   var n = writer.write(data)        # accepts a prefix; n <= len(data)
#   writer.write_all(data)            # loops until every byte is written
#   writer.flush()                    # explicit, fallible terminal call
# API-DOCS-END
