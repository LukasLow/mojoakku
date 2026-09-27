from .io_error import IoError
from .io_error_kind import IoErrorKind
from .read_result import ReadResult
from .seek_from import SeekFrom
from .reader import Reader
from .byte_writer import ByteWriter
from .seeker import Seeker


# Cursor — in-memory reader+writer+seeker over an owned List[UInt8].
struct Cursor(Reader, ByteWriter, Seeker):
    var _buffer: List[UInt8]
    var _pos: Int

    def __init__(out self, var buffer: List[UInt8]):
        self._buffer = buffer^
        self._pos = 0

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        var length = len(self._buffer)
        if self._pos >= length:
            return ReadResult(0, True)
        var n = len(buf)
        if length - self._pos < n:
            n = length - self._pos
        for i in range(n):
            buf[i] = self._buffer[self._pos + i]
        self._pos += n
        return ReadResult(n, self._pos >= length)

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        var n = len(data)
        for i in range(n):
            var at = self._pos + i
            if at < len(self._buffer):
                self._buffer[at] = data[i]
            else:
                self._buffer.append(data[i])
        self._pos += n
        return n

    def seek(mut self, whence: SeekFrom) raises IoError -> Int:
        var target: Int
        if whence._id == 0:
            target = whence.offset
        elif whence._id == 1:
            target = self._pos + whence.offset
        else:
            target = len(self._buffer) + whence.offset
        if target < 0:
            raise IoError(
                IoErrorKind.OTHER, "seek", "seek target is before the start"
            )
        self._pos = target
        return target

# API-DOCS-START
# Cursor — read, write and seek over an in-memory buffer you hand over.
# Signature:
#   struct Cursor(Reader, ByteWriter, Seeker):
#       var _buffer: List[UInt8]
#       var _pos: Int
#       def __init__(out self, var buffer: List[UInt8])
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
#       def write(mut self, data: Span[UInt8, _]) raises IoError -> Int
#       def seek(mut self, whence: SeekFrom) raises IoError -> Int
# What it does:
#   Constructed from an owned List[UInt8] and supports reading, writing and
#   seeking. Read and write move an internal position; a read at the end returns
#   {0, eof: True}. The read-only, borrowed counterpart is SpanCursor, a separate
#   type. It owns its List, so the data lives as long as the cursor.
# Returns:
#   `read` returns a ReadResult; `write` returns the number of bytes accepted;
#   `seek` returns the new absolute position.
# Errors:
#   raises IoError — OTHER on an out-of-range seek.
# Example:
#   var cursor = Cursor(List[UInt8](1, 2, 3))
#   var buf = Array[UInt8, 3](fill=0)
#   _ = cursor.read(buf)                  # buf -> [1, 2, 3]
#   _ = cursor.seek(SeekFrom.START)       # -> 0
#   _ = cursor.write(data)                # overwrite from the start
# API-DOCS-END
