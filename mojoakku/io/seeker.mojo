from .io_error import IoError
from .seek_from import SeekFrom


# Seeker — move the stream position to a new absolute position.
trait Seeker:
    def seek(mut self, whence: SeekFrom) raises IoError -> Int: ...

# API-DOCS-START
# Seeker — move a stream to a new position.
# Signature:
#   trait Seeker:
#       def seek(mut self, whence: SeekFrom) raises IoError -> Int
# What it does:
#   `whence` names the origin and signed offset (see SeekFrom). The parameter is
#   named `whence`, not `from`, because `from` is a reserved Mojo keyword.
#   Seeking past the end may be allowed, and the resulting position is returned.
#   A stream that cannot seek at all raises IoError with kind OTHER; an
#   open-but-unseekable stream is not CLOSED — CLOSED is only produced by a
#   stream whose underlying handle is closed. This layer defines no close.
# Returns:
#   The new absolute position from the start of the stream (an Int).
# Errors:
#   raises IoError — OTHER for an invalid or negative target and for a
#   non-seekable stream; CLOSED only when the underlying handle is closed. Both
#   are recoverable (adjust the target / reopen).
# Example:
#   var pos = searcher.seek(SeekFrom.START)   # -> 0
#   pos = searcher.seek(SeekFrom.end(0))      # -> length
#   pos = searcher.seek(SeekFrom.current(-1)) # -> length - 1
# API-DOCS-END
