# API-DOCS-START
# Padding — compile-time encode padding policy.
# Status: implemented
# Signature: struct Padding(Equatable, ImplicitlyCopyable, Deinitable):
#   var _id: UInt8; @doc_hidden def __init__(out self, id: UInt8)
#   comptime REQUIRED = Padding(0); comptime OMITTED = Padding(1)
# Semantics: used as `[padding: Padding = Padding.REQUIRED]` on
#   encode/encode_into/Encoder. Only the two comptime members are public; _id and
#   its @doc_hidden initializer are implementation details. REQUIRED is only
#   meaningful for base64 and base32; for HEX_LOWER/HEX_UPPER both values produce
#   identical output because base16 has no padding. Controls only what the
#   encoder emits; decode is governed separately by PaddingMode. Value type,
#   compile-time only; no I/O.
# Errors: none.
# Tests: test_base64_padding.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses an explicit Padding value instead of an implicit lax
#   mode because Python's validate=False default, Java's withoutPadding(), Go's
#   WithPadding/NoPadding and Rust's encode_padding all show users expect padding
#   to be a deliberate, visible choice.
# API-DOCS-END


# Padding — compile-time encode padding policy.
#
# Used as `[padding: Padding = Padding.REQUIRED]` on encode/encode_into/Encoder.
# Parameters: none; callers use the two named constants below.
# Return / meaning: controls only what the encoder emits. REQUIRED is meaningful
# for base64 and base32; for HEX_LOWER/HEX_UPPER both values produce identical
# output because base16 has no padding.
# Errors: none.
# Semantics (one line): padding is a deliberate, visible compile-time choice,
# never an implicit lax mode.
struct Padding(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime REQUIRED = Padding(0)   # emit '=' to complete the final quantum
    comptime OMITTED  = Padding(1)   # never emit '='
