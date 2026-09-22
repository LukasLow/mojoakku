# ErrorKind — compile-time discriminant for Base64Error.
struct ErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime INVALID_SYMBOL  = ErrorKind(0)   # byte not in alphabet / not padding, or non-zero trailing bits under STRICT
    comptime INVALID_LENGTH  = ErrorKind(1)   # impossible remainder for the alphabet
    comptime INVALID_PADDING = ErrorKind(2)   # wrong count/placement of '='

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        # Symbolic names, not the numeric _id. An if/elif chain is used because
        # the `comptime NAME[...]` runtime-index form does not compile.
        if self._id == 0:
            writer.write("INVALID_SYMBOL")
        elif self._id == 1:
            writer.write("INVALID_LENGTH")
        else:
            writer.write("INVALID_PADDING")

# API-DOCS-START
# ErrorKind — the machine-testable reason a decode failed.
# Signature:
#   struct ErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime INVALID_SYMBOL  = ErrorKind(0)
#       comptime INVALID_LENGTH  = ErrorKind(1)
#       comptime INVALID_PADDING = ErrorKind(2)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Read from `Base64Error.kind` inside an except block; never constructed or
#   passed by a caller. The three kinds:
#     INVALID_SYMBOL  — a byte outside the alphabet (including whitespace under
#                       Whitespace.REJECT), or, under PaddingMode.STRICT, a
#                       final symbol with non-zero unused trailing bits.
#     INVALID_LENGTH  — the input's remainder is structurally impossible for the
#                       alphabet (e.g. one base64 symbol).
#     INVALID_PADDING — wrong count or placement of '='.
#   It also implements Writable, so `print(err)` shows the symbolic name.
# Returns:
#   A value type (compile-time constants); reading `.kind` returns an ErrorKind
#   owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = decode("Zm!v")
#   except e:
#       print(e.kind == ErrorKind.INVALID_SYMBOL)   # True
#   print(ErrorKind.INVALID_LENGTH)                  # -> INVALID_LENGTH
# API-DOCS-END
