from std.os import abort

from .io_error import IoError
from .read_result import ReadResult


# Reader — one required buffer method plus provided helpers.
trait Reader:
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult: ...

    def read_exact(mut self, buf: MutSpan[UInt8, _]) raises IoError:
        abort("MojoAkku: this API is not yet implemented")

    def read_to_end(mut self) raises IoError -> List[UInt8]:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# Reader — read raw bytes from a stream into a caller-owned buffer.
# Signature:
#   trait Reader:
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
#       def read_exact(mut self, buf: MutSpan[UInt8, _]) raises IoError
#       def read_to_end(mut self) raises IoError -> List[UInt8]
# What it does:
#   `buf` is your destination, borrowed mutably for the call only. The
#   implementation writes at most len(buf) bytes and never touches bytes outside
#   the region it reports in the returned count. A short read (fewer bytes than
#   the buffer holds) is normal and is neither EOF nor an error. The library
#   never retains or allocates the buffer.
#   `read_exact` is a provided helper: it fills `buf` completely or raises
#   IoError (kind UNEXPECTED_EOF) if the stream ends first. `read_to_end` reads
#   until eof and returns a freshly owned List[UInt8]; when it raises, the
#   partially-read bytes are lost by design, so a caller who needs them should
#   use `read` into their own MutSpan instead. Both helpers retry INTERRUPTED
#   internally. This layer defines no close; a Reader is a value, not an owned
#   handle.
# Returns:
#   `read` returns a ReadResult; `read_to_end` returns an owned List[UInt8];
#   `read_exact` returns nothing. The buffer is always yours.
# Errors:
#   raises IoError. INTERRUPTED and WOULD_BLOCK are retryable; CLOSED and
#   TIMED_OUT are resolved by reopening or adjusting; UNEXPECTED_EOF (from
#   read_exact only) means the requested bytes were not available and the
#   consumed prefix cannot be recovered.
# Example:
#   var buf = Array[UInt8, 1024](fill=0)
#   var result = reader.read(buf)
#   while not result.eof:
#       consume(buf[0:result.count])
#       result = reader.read(buf)
# API-DOCS-END
