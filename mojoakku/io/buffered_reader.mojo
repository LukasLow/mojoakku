from std.os import abort

from .io_error import IoError
from .read_result import ReadResult
from .reader import Reader
from io._internal.bounds import Stream


# BufferedReader — buffered wrapper with an inline, compile-time-sized buffer.
struct BufferedReader[R: Stream, capacity: Int = 4096](Reader):
    var _inner: Self.R
    var _buf: Array[UInt8, Self.capacity]
    var _start: Int
    var _end: Int

    def __init__(out self, var inner: Self.R):
        abort("MojoAkku: this API is not yet implemented")

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# BufferedReader — buffer reads from any Reader to reduce call overhead.
# Signature:
#   struct BufferedReader[R: Stream, capacity: Int = 4096](Reader):
#       var _inner: Self.R
#       var _buf: Array[UInt8, Self.capacity]
#       var _start: Int
#       var _end: Int
#       def __init__(out self, var inner: Self.R)
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
# What it does:
#   Wraps any Reader. `capacity` is a compile-time value parameter with a
#   default of 4096 bytes. Reads are served from the internal buffer, refilling
#   from the inner reader only when the buffer is empty; a short inner read is
#   normal. EOF is reported only when the inner reader reports EOF and the buffer
#   is drained, so no buffered data is silently dropped while the reader is live.
#   It owns its inline buffer and inner reader as a value-semantics struct; there
#   is no close. INTERRUPTED is retried on refill; WOULD_BLOCK is surfaced.
# Returns:
#   A ReadResult per read; the bytes are written into your buffer.
# Errors:
#   raises IoError — passed through from the inner reader; OTHER if the inner
#   reader reports a zero-length non-EOF read.
# Example:
#   var buffered = BufferedReader[SomeReader](inner)
#   var buf = Array[UInt8, 1024](fill=0)
#   var result = buffered.read(buf)
# API-DOCS-END
