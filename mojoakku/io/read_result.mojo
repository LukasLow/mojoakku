# ReadResult — explicit read outcome: bytes written plus an EOF flag.
@fieldwise_init
struct ReadResult(Copyable, Deinitable, Writable):
    var count: Int
    var eof: Bool

    def write_to(self, mut writer: Some[Writer]):
        writer.write("ReadResult(count=", self.count, ", eof=", self.eof, ")")

# API-DOCS-START
# ReadResult — the explicit outcome of one read: how many bytes and whether the
# input ended.
# Signature:
#   @fieldwise_init
#   struct ReadResult(Copyable, Deinitable, Writable):
#       var count: Int
#       var eof: Bool
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Returned by every Reader.read. `count` is the number of bytes written into
#   the caller's buffer (0 <= count <= len(buf)); `eof` marks the logical end of
#   input. A short read (count smaller than the buffer) is normal and is neither
#   EOF nor an error. End of stream is reported here, never as a magic -1/0/null
#   and never as an IoError. A conforming read produces exactly one of three
#   shapes:
#     count > 0, eof = False — a normal (possibly short) read; more may follow.
#     count > 0, eof = True  — the final bytes, and the source ended in the call.
#     count = 0, eof = True  — end of input, no bytes.
#   `count = 0, eof = False` is not part of the contract; the provided
#   read_exact/read_to_end treat a repeated such read as a failure rather than
#   spinning. It implements Writable for diagnostics.
# Returns:
#   A value type, returned by value and owned by the caller.
# Errors:
#   none — it is a value. A read that would otherwise produce `0, False` must
#   instead make progress, set `eof`, or raise IoError.
# Example:
#   var buf = Array[UInt8, 8](fill=0)
#   var result = reader.read(buf)
#   if result.eof:
#       print("end after", result.count, "bytes")
#   else:
#       print("read", result.count, "bytes")
# API-DOCS-END
