# API-DOCS-START
# Base64Error — the one typed error every decoder declares via `raises`.
# Status: implemented
# Signature: @fieldwise_init struct Base64Error(Copyable, Deinitable,
#   Writable): var kind: ErrorKind; var position: Int
#   def write_to(self, mut writer: Some[Writer])
# Semantics: constructed by the library; callers read the two fields in an
#   except/try block. `position` is the zero-based index into the original input
#   stream at which the failure was detected (for a streaming Decoder, cumulative
#   across the whole stream, independent of chunking). Under Whitespace.IGNORE
#   skipped whitespace still advances the count. For INVALID_LENGTH position is
#   the first symbol of the impossible remainder; for INVALID_PADDING the start of
#   the offending/partial final quantum; for INVALID_SYMBOL the offending symbol.
#   Value type; Copyable and Deinitable but deliberately not ImplicitlyCopyable,
#   so a re-raise must transfer with `raise e^`.
# Errors: it is the error. All decode failures are data errors and recoverable;
#   none is fatal or unrecoverable.
# Tests: test_base64_errors.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a struct with kind+position because Rust's
#   DecodeError offsets and cppcodec's symbol_error show that a codec must report
#   where and why, and Java's checked IOException and Commons Codec's
#   Object-bridge show how not to type the failure.
# API-DOCS-END

from .error_kind import ErrorKind


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
        writer.write("Base64Error(", self.kind, ", position=", self.position, ")")
