from std.os import abort

from .io_error import IoError
from .read_result import ReadResult
from .reader import Reader
from io._internal.bounds import Stream


# LimitReader — read at most n bytes from an inner reader.
struct LimitReader[R: Stream](Reader):
    var _inner: Self.R
    var _remaining: Int

    def __init__(out self, var inner: Self.R, limit: Int):
        abort("MojoAkku: this API is not yet implemented")

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# LimitReader — read at most a fixed number of bytes from an inner reader.
# Signature:
#   struct LimitReader[R: Stream](Reader):
#       var _inner: Self.R
#       var _remaining: Int
#       def __init__(out self, var inner: Self.R, limit: Int)
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
# What it does:
#   `limit` is the maximum total number of bytes this reader will ever return.
#   Reads come from the inner reader but never go beyond the remaining bytes; when
#   the limit is exhausted it reports {0, eof: True} without touching the inner
#   reader. A negative limit is defined to behave as limit = 0 (immediate EOF),
#   not a trap. It owns the inner reader and stores the limit as a plain Int.
#   There is no close.
# Returns:
#   A ReadResult per read; the bytes are written into your buffer.
# Errors:
#   raises IoError — as the inner reader.
# Example:
#   var limited = LimitReader[SomeReader](inner, 100)
#   var buf = Array[UInt8, 64](fill=0)
#   _ = limited.read(buf)    # at most 64 bytes
#   _ = limited.read(buf)    # at most 36 more, then EOF
# API-DOCS-END
