from std.format import repr

from akku.text_format._internal.core import (
    group_digits,
    int_to_radix,
    pad_numeric,
)

from .format_error import FormatError
from .format_error_kind import FormatErrorKind
from .format_spec import FormatSpec
from .format_type import FormatType
from .grouping import Grouping
from .sign_mode import SignMode


# _is_numeric_int_form — whether a presentation selects an integer numeric form.
def _is_numeric_int_form(p: FormatType) -> Bool:
    return (
        p == FormatType.DEFAULT
        or p == FormatType.BINARY
        or p == FormatType.OCTAL
        or p == FormatType.DECIMAL
        or p == FormatType.LOWER_HEX
        or p == FormatType.UPPER_HEX
    )


# _sign_prefix — the leading sign string for `value` under `mode`.
def _sign_prefix(value: Int, mode: SignMode) -> String:
    if value < 0:
        return "-"
    if mode == SignMode.ALWAYS:
        return "+"
    if mode == SignMode.SPACE:
        return " "
    return ""


# _radix_prefix — the alternate-form prefix for a radix presentation.
def _radix_prefix(p: FormatType, alt: Bool) -> String:
    if not alt:
        return ""
    if p == FormatType.BINARY:
        return "0b"
    if p == FormatType.OCTAL:
        return "0o"
    if p == FormatType.LOWER_HEX:
        return "0x"
    if p == FormatType.UPPER_HEX:
        return "0X"
    return ""


# format_int — render an integer under a format spec.
def format_int(value: Int, spec: FormatSpec) raises FormatError -> String:
    var pres = spec.presentation

    # Presentation must be a valid integer form.
    if not _is_numeric_int_form(pres) and pres != FormatType.CHAR and pres != FormatType.REPR:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("presentation is not valid for an Int"),
        )

    # Grouping is valid for DEFAULT/DECIMAL only.
    if (
        spec.grouping != Grouping.NONE
        and pres != FormatType.DEFAULT
        and pres != FormatType.DECIMAL
    ):
        raise FormatError(
            FormatErrorKind.INVALID_SPEC, 0,
            String("grouping is not valid for this presentation"),
        )

    # CHAR: the value is a Unicode scalar.
    if pres == FormatType.CHAR:
        if value < 0 or value > 0x10FFFF or (value >= 0xD800 and value <= 0xDFFF):
            raise FormatError(
                FormatErrorKind.TYPE_MISMATCH, 0,
                String("value is not a valid Unicode codepoint"),
            )
        var ch = String(Codepoint(unsafe_unchecked_codepoint=UInt32(value)))
        var char_align = Int(spec.align._id)
        if char_align == 0:
            char_align = 1     # characters default LEFT
        return pad_numeric("", ch, spec.width, spec.fill, char_align, False)

    # REPR.
    if pres == FormatType.REPR:
        return pad_numeric("", repr(value), spec.width, spec.fill, Int(spec.align._id), False)

    # Radix digits from the magnitude.
    var magnitude = UInt(value)
    if value < 0:
        magnitude = UInt(-value)
    var radix = 10
    var upper = False
    if pres == FormatType.BINARY:
        radix = 2
    elif pres == FormatType.OCTAL:
        radix = 8
    elif pres == FormatType.LOWER_HEX:
        radix = 16
    elif pres == FormatType.UPPER_HEX:
        radix = 16
        upper = True

    var digits = int_to_radix(magnitude, radix, upper)

    # Precision: minimum number of digits.
    if spec.precision:
        var want = spec.precision.value()
        while digits.byte_length() < want:
            digits = "0" + digits

    # Grouping: only the digit run is grouped (sign/prefix added afterwards).
    if spec.grouping == Grouping.COMMA:
        digits = group_digits(digits, ",")
    elif spec.grouping == Grouping.UNDERSCORE:
        digits = group_digits(digits, "_")

    var sign = _sign_prefix(value, spec.sign)
    var prefix = _radix_prefix(pres, spec.alt_form)
    return pad_numeric(sign, prefix + digits, spec.width, spec.fill, Int(spec.align._id), spec.zero_pad)

# API-DOCS-START
# format_int — render an integer under a format spec.
# Signature:
#   def format_int(value: Int, spec: FormatSpec) raises FormatError -> String
# What it does:
#   Renders `value` under `spec`. The allowed presentations are DEFAULT, DECIMAL,
#   BINARY, OCTAL, LOWER_HEX, UPPER_HEX, CHAR and REPR. `precision`, when present,
#   is the minimum number of digits (the value is left-padded with zeros to at
#   least that many digits, after the sign and any radix prefix). `grouping`
#   applies to DEFAULT/DECIMAL only. SIGN_AWARE alignment is valid, and alt_form
#   adds the 0b/0o/0x/0X prefix. CHAR renders the value as a Unicode codepoint.
#   The sign, prefix, grouping, zero padding and fill/align are applied in that
#   order, padded to `width` in codepoints.
# Returns:
#   A newly allocated String owned by the caller. For the plain radix forms the
#   digits match hex/oct/bin.
# Errors:
#   raises FormatError:
#     TYPE_MISMATCH — the presentation is a float/string form, or CHAR receives a
#                     codepoint outside the valid Unicode range.
#     INVALID_SPEC  — grouping or alt_form is combined with an incompatible
#                     presentation.
#   All are recoverable.
# Example:
#   print(format_int(255, parse_format_spec("x")))     # -> ff
#   print(format_int(255, parse_format_spec("#x")))    # -> 0xff
#   print(format_int(42, parse_format_spec("08d")))    # -> 00000042
#   print(format_int(65, parse_format_spec("c")))      # -> A
# API-DOCS-END
