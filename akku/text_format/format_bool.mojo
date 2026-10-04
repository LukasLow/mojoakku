from std.format import repr

from akku.text_format._internal.core import byte_offset_for_codepoints, pad

from .alignment import Alignment
from .format_error import FormatError
from .format_error_kind import FormatErrorKind
from .format_spec import FormatSpec
from .format_type import FormatType
from .grouping import Grouping
from .sign_mode import SignMode


# format_bool — render a bool under a format spec.
def format_bool(value: Bool, spec: FormatSpec) raises FormatError -> String:
    var pres = spec.presentation
    if (
        pres != FormatType.DEFAULT
        and pres != FormatType.STRING
        and pres != FormatType.REPR
    ):
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("presentation is not valid for a Bool"),
        )
    if spec.sign != SignMode.NEGATIVE_ONLY:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("a sign is not valid for a Bool"),
        )
    if spec.grouping != Grouping.NONE:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("grouping is not valid for a Bool"),
        )
    if spec.alt_form:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("alternate form is not valid for a Bool"),
        )
    if spec.zero_pad:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("zero padding is not valid for a Bool"),
        )
    if spec.align == Alignment.SIGN_AWARE:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("SIGN_AWARE alignment is valid only for numbers"),
        )

    var align = spec.align
    if align == Alignment.DEFAULT:
        align = Alignment.LEFT

    var base: String
    if pres == FormatType.REPR:
        base = repr(value)
    elif value:
        base = "true"
    else:
        base = "false"

    var result: String
    if spec.precision:
        var off = byte_offset_for_codepoints(StringSpan(base), spec.precision.value())
        result = String(StringSpan(base)[byte=0:off])
    else:
        result = base^

    var codepoints = result.count_codepoints()
    return pad(result, spec.width, Int(align._id), spec.fill, codepoints)

# API-DOCS-START
# format_bool — render a bool under a format spec.
# Signature:
#   def format_bool(value: Bool, spec: FormatSpec) raises FormatError -> String
# What it does:
#   Renders `value` under `spec`. The allowed presentations are DEFAULT, STRING
#   and REPR. fill, align, width and precision (max codepoints of "true"/"false")
#   are valid; SIGN_AWARE, zero_pad, sign, grouping and alt_form are rejected.
#   The value renders as "true"/"false", is truncated to `precision` codepoints,
#   then padded to `width` with `align` (default LEFT).
# Returns:
#   A newly allocated String owned by the caller.
# Errors:
#   raises FormatError with kind TYPE_MISMATCH — a numeric/char presentation or an
#   unsupported flag. Recoverable.
# Example:
#   print(format_bool(True, parse_format_spec("")))        # -> true
#   print(format_bool(False, parse_format_spec(">6")))     # -> " false"
#   _ = format_bool(True, parse_format_spec("d"))          # raises TYPE_MISMATCH
# API-DOCS-END
