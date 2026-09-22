# API-DOCS-START
# PaddingMode — compile-time decode padding policy.
# Status: implemented
# Signature: struct PaddingMode(Equatable, ImplicitlyCopyable, Deinitable):
#   var _id: UInt8; @doc_hidden def __init__(out self, id: UInt8)
#   comptime STRICT = PaddingMode(0); comptime TOLERANT = PaddingMode(1)
# Semantics: used as `[padding_mode: PaddingMode = PaddingMode.STRICT]` on
#   decode/decode_into/Decoder/is_valid. STRICT requires RFC 4648 canonical input
#   (exact padding if the final quantum is partial, none if it is full) and
#   rejects non-zero trailing bits as INVALID_SYMBOL. TOLERANT accepts a padded or
#   unpadded final quantum; if padding is present its count must still be exactly
#   right, padding may only occur at the end and no symbol may follow it;
#   TOLERANT also accepts non-zero trailing bits. For HEX_LOWER/HEX_UPPER there is
#   no padding symbol at all, so STRICT and TOLERANT are equivalent; the
#   parameter remains for API uniformity. Value type, compile-time only.
# Errors: invalid padding under either mode raises INVALID_PADDING (or
#   INVALID_LENGTH for a structurally impossible remainder); a recoverable data
#   error.
# Tests: test_base64_padding_mode.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a two-value PaddingMode because Rust's
#   Indifferent/RequireCanonical pair and Commons Codec's CodecPolicy show that
#   "padding present/absent" is a decode policy distinct from the encode policy,
#   while Java shows the tolerant mode is useful for real-world interop.
#   RequireNone (padding forbidden) is deliberately not represented: a caller who
#   must reject '=' scans for it before choosing TOLERANT, and STRICT is the
#   complement and the default.
# API-DOCS-END


# PaddingMode — compile-time decode padding policy.
#
# Used as `[padding_mode: PaddingMode = PaddingMode.STRICT]` on
# decode/decode_into/Decoder/is_valid.
# Parameters: none; callers use the two named constants below.
# Return / meaning: STRICT requires RFC 4648 canonical input (exact padding, and
# zero trailing bits in the final symbol); TOLERANT accepts a padded or unpadded
# final quantum, but if padding is present its count must still be exact.
# Errors: invalid padding under either mode raises INVALID_PADDING (or
# INVALID_LENGTH for a structurally impossible remainder).
# Semantics (one line): the decode policy is separate from the encode policy and
# defaults to strict canonicality.
struct PaddingMode(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime STRICT   = PaddingMode(0)   # require canonical padding / no padding
    comptime TOLERANT = PaddingMode(1)   # padding optional, but consistent if present
