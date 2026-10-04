from .alignment import Alignment
from .format_error import FormatError
from .format_error_kind import FormatErrorKind
from .format_spec import FormatSpec
from .format_type import FormatType
from .grouping import Grouping
from .sign_mode import SignMode


# is_align_letter — whether `c` is one of '<', '>', '^', '='.
def _is_align_letter(c: Int) -> Bool:
    return c == 60 or c == 62 or c == 94 or c == 61


# align_of — the Alignment member for an alignment byte.
def _align_of(c: Int) -> Alignment:
    if c == 60:
        return Alignment.LEFT
    if c == 62:
        return Alignment.RIGHT
    if c == 94:
        return Alignment.CENTER
    return Alignment.SIGN_AWARE


# parse_format_spec — parse and validate a spec string into a FormatSpec.
def parse_format_spec(text: StringSpan) raises FormatError -> FormatSpec:
    var spec = FormatSpec()
    var bytes = text.as_bytes()
    var n = len(bytes)
    var i = 0

    if n == 0:
        return spec^

    # Nested replacement fields are not accepted in release 1.
    for k in range(n):
        if bytes[k] == 123 or bytes[k] == 125:   # '{' or '}'
            raise FormatError(
                FormatErrorKind.INVALID_SPEC, k, String("nested braces are not supported")
            )

    # --- optional fill + alignment ---
    if i < n and _is_align_letter(Int(bytes[i])):
        spec.align = _align_of(Int(bytes[i]))
        i += 1
    elif i < n:
        # The first element may be one fill codepoint followed by an alignment
        # letter (the fill may itself be multi-byte, e.g. 'é').
        var cp_end = _codepoint_end(bytes, i)
        if cp_end < n and _is_align_letter(Int(bytes[cp_end])):
            spec.fill = _decode_codepoint(bytes, i)
            spec.align = _align_of(Int(bytes[cp_end]))
            i = cp_end + 1

    # --- optional sign ---
    if i < n:
        var c = Int(bytes[i])
        if c == 43:      # '+'
            spec.sign = SignMode.ALWAYS
            i += 1
        elif c == 45:    # '-'
            spec.sign = SignMode.NEGATIVE_ONLY
            i += 1
        elif c == 32:    # ' '
            spec.sign = SignMode.SPACE
            i += 1

    # --- optional '#' then optional '0' (in either documented order '#' '0') ---
    if i < n and bytes[i] == 35:     # '#'
        spec.alt_form = True
        i += 1
    if i < n and bytes[i] == 48:     # '0'
        spec.zero_pad = True
        i += 1

    # --- optional width (digits) ---
    var width = 0
    var width_digits = 0
    while i < n and bytes[i] >= 48 and bytes[i] <= 57:
        width = width * 10 + (Int(bytes[i]) - 48)
        i += 1
        width_digits += 1
    if width_digits > 0:
        spec.width = width

    # --- optional grouping ---
    if i < n and bytes[i] == 44:     # ','
        spec.grouping = Grouping.COMMA
        i += 1
    elif i < n and bytes[i] == 95:   # '_'
        spec.grouping = Grouping.UNDERSCORE
        i += 1

    # --- optional precision ('.' then digits) ---
    if i < n and bytes[i] == 46:     # '.'
        i += 1
        var precision = 0
        var precision_digits = 0
        while i < n and bytes[i] >= 48 and bytes[i] <= 57:
            precision = precision * 10 + (Int(bytes[i]) - 48)
            i += 1
            precision_digits += 1
        if precision_digits == 0:
            raise FormatError(
                FormatErrorKind.INVALID_SPEC, i,
                String("'.' must be followed by digits"),
            )
        spec.precision = Optional(precision)

    # --- optional presentation ---
    if i < n:
        var c = Int(bytes[i])
        if c == 98:        # 'b'
            spec.presentation = FormatType.BINARY
        elif c == 111:     # 'o'
            spec.presentation = FormatType.OCTAL
        elif c == 100:     # 'd'
            spec.presentation = FormatType.DECIMAL
        elif c == 120:     # 'x'
            spec.presentation = FormatType.LOWER_HEX
        elif c == 88:      # 'X'
            spec.presentation = FormatType.UPPER_HEX
        elif c == 99:      # 'c'
            spec.presentation = FormatType.CHAR
        elif c == 115:     # 's'
            spec.presentation = FormatType.STRING
        elif c == 114:     # 'r'
            spec.presentation = FormatType.REPR
        elif c == 102 or c == 70:   # 'f' / 'F' (F is an alias of f)
            spec.presentation = FormatType.FIXED
        elif c == 101:     # 'e'
            spec.presentation = FormatType.SCIENTIFIC
        elif c == 69:      # 'E'
            spec.presentation = FormatType.UPPER_SCIENTIFIC
        else:
            raise FormatError(
                FormatErrorKind.INVALID_SPEC, i,
                String("unknown presentation letter"),
            )
        i += 1

    # --- a bare fill (no alignment) was rejected above by falling through; any
    #     leftover byte is an invalid spec ('*10' leaves '*' here). ---
    if i < n:
        raise FormatError(
            FormatErrorKind.INVALID_SPEC, i, String("unexpected character in spec")
        )

    return spec^


# _codepoint_end — the byte offset just after the codepoint starting at `i`.
def _codepoint_end(bytes: Span[UInt8, _], i: Int) -> Int:
    var b = bytes[i]
    if b < 0x80:
        return i + 1
    if b >= 0xC2 and b <= 0xDF:
        return i + 2
    if b >= 0xE0 and b <= 0xEF:
        return i + 3
    return i + 4


# _decode_codepoint — the Codepoint starting at byte `i`.
def _decode_codepoint(bytes: Span[UInt8, _], i: Int) -> Codepoint:
    var b0 = Int(bytes[i])
    if b0 < 0x80:
        return Codepoint(unsafe_unchecked_codepoint=UInt32(b0))
    if b0 >= 0xC2 and b0 <= 0xDF:
        return Codepoint(unsafe_unchecked_codepoint=UInt32(((b0 & 0x1F) << 6) | (Int(bytes[i + 1]) & 0x3F)))
    if b0 >= 0xE0 and b0 <= 0xEF:
        return Codepoint(unsafe_unchecked_codepoint=UInt32(
            ((b0 & 0x0F) << 12)
            | ((Int(bytes[i + 1]) & 0x3F) << 6)
            | (Int(bytes[i + 2]) & 0x3F)
        ))
    return Codepoint(unsafe_unchecked_codepoint=UInt32(
        ((b0 & 0x07) << 18)
        | ((Int(bytes[i + 1]) & 0x3F) << 12)
        | ((Int(bytes[i + 2]) & 0x3F) << 6)
        | (Int(bytes[i + 3]) & 0x3F)
    ))


# API-DOCS-START
# parse_format_spec — parse and validate a spec string into a FormatSpec.
# Signature:
#   def parse_format_spec(text: StringSpan) raises FormatError -> FormatSpec
# What it does:
#   Parses `text` against the format-spec grammar
#     [[fill]align][sign][#][0][width][grouping][.precision][presentation]
#   and returns the validated value. `text` is the spec content WITHOUT the
#   surrounding braces or the leading ':'; an empty string yields the neutral
#   spec. A fill codepoint is accepted only when it is followed by an alignment
#   character (<, >, ^ or =). Leading '-' is accepted as an explicit
#   NEGATIVE_ONLY sign; 'F' is an alias of 'f' (FIXED, identical lowercase
#   output). `,`/`_` select integer grouping and `.` introduces precision.
#   `text` is borrowed and may be dropped after the call.
# Returns:
#   A FormatSpec owned by the caller, with every element resolved.
# Errors:
#   raises FormatError with kind INVALID_SPEC — a repeated flag, an unknown
#   presentation letter, a '.' with no digits, a negative width, a bare fill
#   without alignment, or a nested '{...}'. The error's position is the byte
#   offset in `text` of the offending character. Recoverable by correcting the
#   text.
# Example:
#   var spec = parse_format_spec("*>10")
#   print(spec.width)                # -> 10
#   print(spec.align)                # -> RIGHT
#   var hex = parse_format_spec("#08x")
#   print(hex.presentation)          # -> LOWER_HEX
#   _ = parse_format_spec("q")       # raises INVALID_SPEC
# API-DOCS-END
