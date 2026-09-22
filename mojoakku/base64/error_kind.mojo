# API-DOCS-START
# ErrorKind — compile-time discriminant for Base64Error.
# Status: implemented
# Signature: struct ErrorKind(Equatable, ImplicitlyCopyable, Deinitable,
#   Writable): var _id: UInt8; @doc_hidden def __init__(out self, id: UInt8)
#   comptime INVALID_SYMBOL/INVALID_LENGTH/INVALID_PADDING
#   def write_to(self, mut writer: Some[Writer])
# Semantics: read from `Base64Error.kind`; never passed by a caller to a codec.
#   The machine-testable reason for a decode failure. INVALID_LENGTH is a
#   whole-input structural error (base64 remainder 1, base16 odd length, base32
#   remainder 1/3/6); INVALID_PADDING is a placement/count error; INVALID_SYMBOL
#   is a bad byte. Under PaddingMode.STRICT the same INVALID_SYMBOL kind also
#   covers a final symbol whose unused trailing bits are non-zero, keeping the
#   public discriminant at three values. Value type; compile-time constants.
# Errors: none.
# Tests: test_base64_errors.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a three-value discriminant because Rust and
#   data-encoding both carry a machine-usable kind plus an offset, and Elixir's
#   bare :error and Perl's silently-ignored behaviour are the documented failure
#   modes of collapsing reasons.
# API-DOCS-END


# ErrorKind — compile-time discriminant for Base64Error.
#
# Read from `Base64Error.kind`; never passed by a caller to a codec.
# Parameters: none; callers use the three named constants below.
# Return / meaning: the machine-testable reason for a decode failure.
# INVALID_SYMBOL is a bad byte in the alphabet (including non-zero trailing bits
# under STRICT); INVALID_LENGTH is a whole-input structural error; INVALID_PADDING
# is a placement/count error on the '=' symbol.
# Errors: none.
# Semantics (one line): the three kinds correspond to bad symbol, impossible
# remainder and bad padding, and folding the trailing-bit case into
# INVALID_SYMBOL keeps the public discriminant at three values.
struct ErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime INVALID_SYMBOL  = ErrorKind(0)   # byte not in alphabet / not padding, or non-zero trailing bits under STRICT
    comptime INVALID_LENGTH  = ErrorKind(1)   # impossible remainder for the alphabet
    comptime INVALID_PADDING = ErrorKind(2)   # wrong count/placement of '='

    # write_to — writes the symbolic name, not the numeric _id.
    #
    # Parameters: the writer to write into.
    # Return / meaning: writes "INVALID_SYMBOL", "INVALID_LENGTH" or
    # "INVALID_PADDING", so `print(err)` reads "INVALID_LENGTH" rather than
    # "ErrorKind(_id=1)".
    # Errors: none.
    # Semantics (one line): the diagnostic uses symbolic names for the reader.
    def write_to(self, mut writer: Some[Writer]):
        # Symbolic names, not the numeric _id. An if/elif chain is used because
        # the `comptime NAME[...]` runtime-index form does not compile.
        if self._id == 0:
            writer.write("INVALID_SYMBOL")
        elif self._id == 1:
            writer.write("INVALID_LENGTH")
        else:
            writer.write("INVALID_PADDING")
