from .io_error import IoError
from .io_error_kind import IoErrorKind
from .read_result import ReadResult


# Reader — one required buffer method plus provided helpers.
trait Reader:
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult: ...

    def read_exact(mut self, buf: MutSpan[UInt8, _]) raises IoError:
        # Fill `buf` completely, or raise UNEXPECTED_EOF if the stream ends
        # first. INTERRUPTED is retried; other kinds surface. A `{0, False}`
        # read is a non-conforming no-progress read and becomes OTHER.
        var filled = 0
        var total = len(buf)
        while filled < total:
            var result: ReadResult
            try:
                result = self.read(buf[filled:])
            except e:
                if e.kind == IoErrorKind.INTERRUPTED:
                    continue
                raise e^
            if result.count == 0 and not result.eof:
                raise IoError(
                    IoErrorKind.OTHER, "read", "read made no progress"
                )
            filled += result.count
            if result.eof and filled < total:
                raise IoError(
                    IoErrorKind.UNEXPECTED_EOF,
                    "read",
                    "unexpected end of stream before buffer was filled",
                )

    def read_to_end(mut self) raises IoError -> List[UInt8]:
        # Read until eof, appending every byte to a fresh owned List. On a
        # raise the accumulated list is lost by design (it is a local).
        var out = List[UInt8]()
        var buf = List[UInt8](length=4096, fill=0)
        while True:
            var result: ReadResult
            try:
                result = self.read(MutSpan(buf))
            except e:
                if e.kind == IoErrorKind.INTERRUPTED:
                    continue
                raise e^
            if result.count == 0 and not result.eof:
                raise IoError(
                    IoErrorKind.OTHER, "read", "read made no progress"
                )
            for i in range(result.count):
                out.append(buf[i])
            if result.eof:
                break
        return out^

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
