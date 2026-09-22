# API-DOCS-START
# Whitespace — compile-time decode whitespace policy.
# Status: implemented
# Signature: struct Whitespace(Equatable, ImplicitlyCopyable, Deinitable):
#   var _id: UInt8; @doc_hidden def __init__(out self, id: UInt8)
#   comptime REJECT = Whitespace(0); comptime IGNORE = Whitespace(1)
# Semantics: used as `[whitespace: Whitespace = Whitespace.REJECT]` on
#   decode/decode_into/Decoder/is_valid. Makes whitespace tolerance explicit.
#   REJECT (default) makes any whitespace byte an INVALID_SYMBOL. IGNORE skips
#   space, tab, CR, LF, FF and VT; skipped whitespace still advances the
#   original-stream index used for `position`, but is not part of any quantum.
#   REJECT differs from the Mojo stdlib, which ignores whitespace in b64decode;
#   IGNORE preserves that behaviour as an opt-in. Value type, compile-time only.
# Errors: under REJECT a whitespace byte raises INVALID_SYMBOL; under IGNORE
#   whitespace never fails.
# Tests: test_base64_whitespace.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses an explicit Whitespace value because libsodium's
#   `ignore` string with NULL meaning strict is the cleanest precedent for
#   caller-chosen skipping, while Go silently ignores CR/LF even under Strict()
#   and is explicitly rejected as a non-copy.
# API-DOCS-END


# Whitespace — compile-time decode whitespace policy.
#
# Used as `[whitespace: Whitespace = Whitespace.REJECT]` on
# decode/decode_into/Decoder/is_valid.
# Parameters: none; callers use the two named constants below.
# Return / meaning: REJECT makes any whitespace byte an INVALID_SYMBOL; IGNORE
# skips space, tab, CR, LF, FF and VT, advancing the original-stream index used
# for `position`.
# Errors: under REJECT a whitespace byte raises INVALID_SYMBOL; under IGNORE
# whitespace never fails.
# Semantics (one line): whitespace tolerance is explicit and opt-in, never
# silently applied.
struct Whitespace(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime REJECT = Whitespace(0)   # default: any whitespace is INVALID_SYMBOL
    comptime IGNORE = Whitespace(1)   # skip space, tab, CR, LF, FF, VT
