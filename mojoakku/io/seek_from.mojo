from std.os import abort


# SeekFrom — where a seek starts: a named origin plus a signed byte offset.
struct SeekFrom(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8
    var offset: Int

    @doc_hidden
    def __init__(out self, id: UInt8, offset: Int):
        self._id = id
        self.offset = offset

    # Written explicitly so equality compares both the origin and the offset.
    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    comptime START   = SeekFrom(0, 0)   # offset from the start of the stream
    comptime CURRENT = SeekFrom(1, 0)   # offset from the current position
    comptime END     = SeekFrom(2, 0)   # offset from the end of the stream

    @staticmethod
    def start(offset: Int) -> SeekFrom:
        abort("MojoAkku: this API is not yet implemented")

    @staticmethod
    def current(offset: Int) -> SeekFrom:
        abort("MojoAkku: this API is not yet implemented")

    @staticmethod
    def end(offset: Int) -> SeekFrom:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# SeekFrom — where a seek starts: one of three origins plus a signed byte offset.
# Signature:
#   struct SeekFrom(Equatable, ImplicitlyCopyable, Deinitable):
#       var _id: UInt8
#       var offset: Int
#       @doc_hidden
#       def __init__(out self, id: UInt8, offset: Int)
#       def __eq__(self, other: Self) -> Bool
#       comptime START   = SeekFrom(0, 0)
#       comptime CURRENT = SeekFrom(1, 0)
#       comptime END     = SeekFrom(2, 0)
#       @staticmethod
#       def start(offset: Int) -> SeekFrom
#       @staticmethod
#       def current(offset: Int) -> SeekFrom
#       @staticmethod
#       def end(offset: Int) -> SeekFrom
# What it does:
#   Used as the argument of Seeker.seek. The three comptime bases name the
#   reference point; supply a non-zero signed offset through the start/current/
#   end constructors. The offset is signed, so `SeekFrom.end(-1)` means "one byte
#   before the end". Equality compares both the origin and the offset, so
#   SeekFrom.start(5) == SeekFrom.START is False.
# Returns:
#   A value type, copied by value. The resulting stream position is returned by
#   Seeker.seek as an Int.
# Errors:
#   none — it is a value, not a stream.
# Example:
#   _ = searcher.seek(SeekFrom.START)        # position 0
#   _ = searcher.seek(SeekFrom.start(8))     # absolute position 8
#   _ = searcher.seek(SeekFrom.current(-2))  # back two bytes
#   _ = searcher.seek(SeekFrom.end(-1))      # last byte
# API-DOCS-END
