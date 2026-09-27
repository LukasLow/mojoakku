from .io_error import IoError
from .io_error_kind import IoErrorKind
from .read_result import ReadResult
from .reader import Reader
from io._internal.bounds import Stream


# MultiReader — concatenate a homogeneous set of readers.
struct MultiReader[R: Stream](Reader):
    var _readers: List[Self.R]
    var _index: Int

    def __init__(out self, var *readers: Self.R):
        # The variadic pack must be owned (`var`) so its elements can be moved
        # into the List storage. `*readers^` transfers the whole pack.
        self._readers = List[Self.R](*readers^, __list_literal__=None)
        self._index = 0

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        # Fill `buf` from successive readers, advancing whenever the active
        # reader reports eof. Data is always returned with eof = False; the
        # {0, eof: True} result is produced only once every reader has ended.
        var total = 0
        while True:
            if self._index >= len(self._readers):
                return ReadResult(total, True)
            var result = self._readers[self._index].read(buf[total:])
            total += result.count
            if result.count > 0:
                if result.eof:
                    self._index += 1
                return ReadResult(total, False)
            if result.eof:
                self._index += 1
                continue
            raise IoError(
                IoErrorKind.OTHER, "read", "active reader made no progress"
            )

# API-DOCS-START
# MultiReader — read several readers in order as if they were one.
# Signature:
#   struct MultiReader[R: Stream](Reader):
#       var _readers: List[Self.R]
#       var _index: Int
#       def __init__(out self, *readers: Self.R)
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
# What it does:
#   Constructed from one or more readers with a variadic constructor
#   (MultiReader(r1, r2, r3)). The readers are homogeneous — all the same type R
#   — and are stored in a List, so the count is a runtime value and there is no
#   boxing. A heterogeneous set is out of scope for this release. Reads come from
#   the current reader; when it reports eof, the reader advances to the next and
#   retries, and only after the last reader ends does it report {0, eof: True}.
#   It owns all readers. There is no close.
# Returns:
#   A ReadResult per read; the bytes are written into your buffer.
# Errors:
#   raises IoError — from the active reader.
# Example:
#   var multi = MultiReader[SomeReader](r1, r2, r3)
#   var buf = Array[UInt8, 1024](fill=0)
#   var result = multi.read(buf)    # reads r1, then r2, then r3
# API-DOCS-END
