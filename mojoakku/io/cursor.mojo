from std.os import abort

from .io_error import IoError
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
        abort("MojoAkku: this API is not yet implemented")

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        abort("MojoAkku: this API is not yet implemented")

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def seek(mut self, whence: SeekFrom) raises IoError -> Int:
        abort("MojoAkku: this API is not yet implemented")

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
