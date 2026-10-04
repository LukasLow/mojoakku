from std.format import repr

from akku.text_format._internal.core import (
    format_fixed,
    format_scientific,
    is_special_float,
    pad_numeric,
    special_float_text,
)

from .format_error import FormatError
from .format_error_kind import FormatErrorKind
from .format_spec import FormatSpec
from .format_type import FormatType
from .grouping import Grouping
from .sign_mode import SignMode


# _is_float_form — whether a presentation selects a float numeric form.
def _is_float_form(p: FormatType) -> Bool:
    return (
        p == FormatType.DEFAULT
        or p == FormatType.FIXED
        or p == FormatType.SCIENTIFIC
        or p == FormatType.UPPER_SCIENTIFIC
    )


# _float_sign_prefix — the leading sign for `value`, using a forced sign only.
def _float_sign_prefix(value: Float64, mode: SignMode, raw: String) -> String:
    # `raw` already carries a '-' for negative values from the digit routine.
    var bytes = raw.as_bytes()
    if len(bytes) > 0 and Int(bytes[0]) == 45:   # already '-'
        return ""
    if value < 0.0:
        return "-"
    if mode == SignMode.ALWAYS:
        return "+"
    if mode == SignMode.SPACE:
        return " "
    return ""


# format_float — render a float under a format spec.
def format_float(value: Float64, spec: FormatSpec) raises FormatError -> String:
    var pres = spec.presentation

    if not _is_float_form(pres) and pres != FormatType.REPR:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("presentation is not valid for a Float64"),
        )

    if spec.grouping != Grouping.NONE:
        raise FormatError(
            FormatErrorKind.INVALID_SPEC, 0,
            String("grouping is not valid for a float"),
        )

    if pres == FormatType.REPR:
        return pad_numeric("", repr(value), spec.width, spec.fill, Int(spec.align._id), False)

    # precision is not applicable to the DEFAULT presentation.
    if pres == FormatType.DEFAULT and spec.precision:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("precision is not valid for the default float form"),
        )

    # --- inf / nan ---
    if is_special_float(value):
        var text = special_float_text(value)
        var align = Int(spec.align._id)
        if align == 0:
            align = 2     # numbers default RIGHT
        return pad_numeric("", text, spec.width, spec.fill, align, False)

    # --- DEFAULT uses the stdlib shortest round-trip form ---
    if pres == FormatType.DEFAULT:
        var raw = String(value)
        var sign = _float_sign_prefix(value, spec.sign, raw)
        return pad_numeric(sign, raw, spec.width, spec.fill, Int(spec.align._id), spec.zero_pad)

    var precision = 6
    if spec.precision:
        precision = spec.precision.value()

    var body: String
    if pres == FormatType.FIXED:
        body = format_fixed(value, precision, spec.alt_form)
    elif pres == FormatType.SCIENTIFIC:
        body = format_scientific(value, precision, False)
    else:
        body = format_scientific(value, precision, True)

    # The digit routine already carries a '-' for negatives; separate it so the
    # sign logic and padding stay in one place.
    var sign = ""
    var bbytes = body.as_bytes()
    if len(bbytes) > 0 and Int(bbytes[0]) == 45:
        sign = "-"
        var tail = String(body[byte=1:])
        body = tail^
    elif spec.sign == SignMode.ALWAYS:
        sign = "+"
    elif spec.sign == SignMode.SPACE:
        sign = " "

    return pad_numeric(sign, body, spec.width, spec.fill, Int(spec.align._id), spec.zero_pad)

# API-DOCS-START
# format_float — render a float under a format spec.
# Signature:
#   def format_float(value: Float64, spec: FormatSpec) raises FormatError -> String
# What it does:
#   Renders `value` under `spec`. The allowed presentations are DEFAULT, FIXED
#   ('f', or 'F' as an alias), SCIENTIFIC ('e'), UPPER_SCIENTIFIC ('E') and REPR.
#   `precision` is the number of digits after the decimal point for FIXED and
#   SCIENTIFIC (default 6); for DEFAULT it must be None. Sign, zero padding,
#   width, SIGN_AWARE alignment and alt_form (forced trailing decimal point) are
#   valid; grouping on a float is not. Rounding is half-to-even. inf/nan render
#   as lowercase inf/nan ('F' is an alias of 'f' and never upper-cases them).
# Returns:
#   A newly allocated String owned by the caller, padded to `width` in codepoints.
# Errors:
#   raises FormatError:
#     TYPE_MISMATCH — an integer/string/char presentation, or precision on
#                     DEFAULT.
#     INVALID_SPEC  — grouping on a float.
#   All are recoverable.
# Example:
#   print(format_float(3.14159, parse_format_spec(".2f")))   # -> 3.14
#   print(format_float(0.125, parse_format_spec(".2f")))     # -> 0.12
#   print(format_float(1234.5, parse_format_spec("e")))      # -> 1.234500e+03
# API-DOCS-END
