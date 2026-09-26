from std.os import abort

from .io_error import IoError
from .read_result import ReadResult
from .seek_from import SeekFrom
from .reader import Reader
from .seeker import Seeker


# SpanCursor — read+seek only over a borrowed Span[UInt8, _].
struct SpanCursor[origin: Origin[mut=False]](Reader, Seeker):
    var _buffer: Span[UInt8, Self.origin]
    var _pos: Int

    def __init__(out self, buffer: Span[UInt8, Self.origin]):
        abort("MojoAkku: this API is not yet implemented")

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        abort("MojoAkku: this API is not yet implemented")

    def seek(mut self, whence: SeekFrom) raises IoError -> Int:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# SpanCursor — read and seek over a borrowed, read-only byte span.
# Signature:
#   struct SpanCursor[origin: Origin[mut=False]](Reader, Seeker):
#       var _buffer: Span[UInt8, Self.origin]
#       var _pos: Int
#       def __init__(out self, buffer: Span[UInt8, Self.origin])
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
#       def seek(mut self, whence: SeekFrom) raises IoError -> Int
# What it does:
#   Constructed from a borrowed Span[UInt8, _] — a read-only view of someone
#   else's data. It supports only reading and seeking; there is no write, so
#   "read-only" is a type-level property, not a runtime error. Read moves an
#   internal position; a read at the end returns {0, eof: True}. It never owns or
#   mutates the data, and the lifetime checker ties the cursor's validity to the
#   borrowed data so it cannot outlive its owner.
# Returns:
#   `read` returns a ReadResult; `seek` returns the new absolute position.
# Errors:
#   raises IoError — OTHER on an out-of-range seek. It cannot raise a
#   "write to a read-only buffer" error because it has no write method.
# Example:
#   var data: List[UInt8] = [1, 2, 3]
#   var cursor = SpanCursor(Span(data))
#   var buf = Array[UInt8, 3](fill=0)
#   _ = cursor.read(buf)                  # buf -> [1, 2, 3]
#   _ = cursor.seek(SeekFrom.START)       # -> 0
# API-DOCS-END
