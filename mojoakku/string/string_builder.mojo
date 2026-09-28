from std.os import abort

from .string_error import StringError


# StringBuilder — an owning incremental text buffer with an explicit flush.
struct StringBuilder(Deinitable, Writable, Writer):
    var _buf: String

    def __init__(out self):
        abort("MojoAkku: this API is not yet implemented")

    def __init__(out self, capacity_bytes: Int):
        abort("MojoAkku: this API is not yet implemented")

    def append(mut self, text: StringSpan):
        abort("MojoAkku: this API is not yet implemented")

    def append_codepoint(mut self, codepoint: Codepoint):
        abort("MojoAkku: this API is not yet implemented")

    def append_bytes(mut self, bytes: Span[UInt8, _]) raises StringError:
        abort("MojoAkku: this API is not yet implemented")

    def reserve(mut self, capacity_bytes: Int):
        abort("MojoAkku: this API is not yet implemented")

    def clear(mut self):
        abort("MojoAkku: this API is not yet implemented")

    def byte_length(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def capacity(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def to_string(self) -> String:
        abort("MojoAkku: this API is not yet implemented")

    def finish(deinit self) -> String:
        abort("MojoAkku: this API is not yet implemented")

    def write_string(mut self, string: StringSpan):
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# StringBuilder — an owning incremental text buffer with an explicit flush.
# Signature:
#   struct StringBuilder(Deinitable, Writable, Writer):
#       var _buf: String
#       def __init__(out self)
#       def __init__(out self, capacity_bytes: Int)
#       def append(mut self, text: StringSpan)
#       def append_codepoint(mut self, codepoint: Codepoint)
#       def append_bytes(mut self, bytes: Span[UInt8, _]) raises StringError
#       def reserve(mut self, capacity_bytes: Int)
#       def clear(mut self)
#       def byte_length(self) -> Int
#       def capacity(self) -> Int
#       def to_string(self) -> String
#       def finish(deinit self) -> String
#       def write_string(mut self, string: StringSpan)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Builds text incrementally without repeated concatenation. `__init__()` starts
#   empty; `__init__(capacity_bytes=...)` is a growth hint only (the builder is
#   still empty). `append(text)` adds the UTF-8 bytes of a borrowed view,
#   `append_codepoint(cp)` adds one Codepoint, and `append_bytes(bytes)` adds raw
#   bytes after validating UTF-8. `reserve` grows the buffer and `clear` resets
#   the content while keeping capacity. `byte_length()` is the current content
#   length; `capacity()` is the buffer's addressable byte count.
#   Materialise with `to_string()` (returns a copy, builder stays usable) or
#   `finish` (transfers the buffer out and consumes the builder). `finish` takes
#   `deinit self`, so the call site must transfer with `^`: `b^.finish()`; after
#   it the builder is dead. Because it also conforms to Writer, `builder.write(a,
#   b, c)` accepts formatted output directly.
# Returns:
#   `to_string` returns a copy and leaves the builder usable; `finish` returns the
#   owned buffer and consumes the builder. `byte_length`/`capacity` return Int.
# Errors:
#   raises StringError — append_bytes raises INVALID_UTF8 for bytes that are not
#   valid UTF-8 and appends nothing. Every other method cannot fail.
# Example:
#   var b = StringBuilder()
#   b.append("Hello")
#   b.append_codepoint(Codepoint(44))   # ','
#   b.append(" world")
#   print(b.byte_length())              # -> 12
#   print(b)                            # -> Hello, world
#   var s = b^.finish()                 # transfers out; b is consumed
# API-DOCS-END
