# MojoAkku base64 — public error surface (api area: errors).
#
# One typed error for every decoder: `Base64Error`, carrying a machine-testable
# `kind` discriminant and a `position` offset into the original input.

from std.os import abort


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
        abort("MojoAkku: this API is not yet implemented")


# Base64Error — the one typed error every decoder declares via `raises`.
#
# Parameters / preconditions: constructed by the library; callers read the two
# fields in an except/try block. `position` is the zero-based index into the
# original input stream at which the failure was detected (for a streaming
# Decoder, cumulative across the whole stream).
# Return / meaning: carries `kind` (an ErrorKind) and `position` (an Int). It is
# Copyable and Deinitable but deliberately not ImplicitlyCopyable, so a re-raise
# must use `raise e^`.
# Errors: it *is* the error; all decode failures are recoverable data errors.
# Semantics (one line): a readable diagnostic reporting where and why decoding
# failed.
@fieldwise_init
struct Base64Error(Copyable, Deinitable, Writable):
    var kind: ErrorKind
    var position: Int

    # write_to — readable diagnostic: the symbolic `kind` name and `position`.
    #
    # Parameters: the writer to write into.
    # Return / meaning: writes the symbolic ErrorKind and the position, the
    # inherited Writable contract used by `print(err)`.
    # Errors: none.
    # Semantics (one line): `print(err)` yields an allocation-cheap message with
    # the kind and position.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")
