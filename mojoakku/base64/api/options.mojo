# MojoAkku base64 — public option types (api area: options).
#
# Compile-time option model. Every option is a small value type with a private
# `_id` field and named `comptime` constants. Callers use the named constants;
# the initializer is @doc_hidden and is an implementation detail.


# Alphabet — compile-time value type selecting the symbol table.
#
# Used as a value parameter `[alphabet: Alphabet = Alphabet.B64_STANDARD]` on
# the codec entries. It identifies the symbol table, the symbols-per-quantum
# ratio and whether padding exists.
# Parameters: none; callers use the six named constants below.
# Return / meaning: an opaque compile-time value; the library defines behaviour
# only for ids 0-5. Values outside that set are outside the public contract.
# Errors: none in practice; the six named constants are the only public values.
# Semantics (one line): the alphabet is chosen at compile time, so table
# lookups and branches resolve while compiling.
struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime B64_STANDARD = Alphabet(0)   # RFC 4648 §4,  A-Z a-z 0-9 + /
    comptime B64_URL      = Alphabet(1)   # RFC 4648 §5,  A-Z a-z 0-9 - _
    comptime B32_STANDARD = Alphabet(2)   # RFC 4648 §6,  A-Z 2-7
    comptime B32_HEX      = Alphabet(3)   # RFC 4648 §7,  0-9 A-V
    comptime HEX_LOWER    = Alphabet(4)   # RFC 4648 §8,  0-9 a-f
    comptime HEX_UPPER    = Alphabet(5)   # RFC 4648 §8,  0-9 A-F


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
