from std.os import abort

from .io_error import IoError
from io._internal.bounds import Stream, Sink


# copy — pump a reader into a writer until the reader reports EOF.
def copy[R: Stream, W: Sink](mut reader: R, mut writer: W) raises IoError -> Int:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# copy — pump every remaining byte from a reader into a writer.
# Signature:
#   def copy[R: Stream, W: Sink](mut reader: R, mut writer: W) raises IoError -> Int
# What it does:
#   Both arguments are mutable references; the reader is drained into the writer
#   until it reports eof. Short reads and short writes are handled internally
#   (the loop continues until done), and INTERRUPTED is retried. It borrows both
#   stream handles for the call and allocates only its own small internal
#   transfer buffer. There is no close.
# Returns:
#   The total number of bytes copied (an Int). When it raises mid-copy, the count
#   of bytes already written is not returned — a caller who needs the partial
#   progress should compare the writer's observed length before and after, or
#   drive the loop with read/write directly.
# Errors:
#   raises IoError — from either side; `op` names which side failed.
# Example:
#   var n = copy(reader, writer)    # drains reader into writer
#   print("copied", n, "bytes")
# API-DOCS-END
