from std.format import repr

from akku.text_format._internal.core import byte_offset_for_codepoints, pad
from akku.text_string import is_char_boundary, slice
from akku.text_format.format_error import FormatError
from akku.text_format.format_error_kind import FormatErrorKind
from akku.text_format.format_spec import FormatSpec
from akku.text_format.format_type import FormatType
from akku.text_format.alignment import Alignment
from akku.text_format.grouping import Grouping
from akku.text_format.sign_mode import SignMode


# _reject_non_text_spec — raise TYPE_MISMATCH for a spec element that makes no
# sense on text. Every condition is documented in the format_string API block.
def _reject_non_text_spec(spec: FormatSpec) raises FormatError:
    var pres = spec.presentation
    if (
        pres != FormatType.DEFAULT
        and pres != FormatType.STRING
        and pres != FormatType.REPR
    ):
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("presentation is not valid for a String"),
        )
    if spec.sign != SignMode.NEGATIVE_ONLY:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("a sign is not valid for a String"),
        )
    if spec.grouping != Grouping.NONE:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("grouping is not valid for a String"),
        )
    if spec.alt_form:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("alternate form is not valid for a String"),
        )
    if spec.zero_pad:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("zero padding is not valid for a String"),
        )
    if spec.align == Alignment.SIGN_AWARE:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, 0,
            String("SIGN_AWARE alignment is valid only for numbers"),
        )


# _truncate_codepoints — a borrowed view of the first `n` codepoints of `text`.
def _truncate_codepoints[o: Origin[mut=False]](
    text: StringSpan[o], n: Int
) raises FormatError -> StringSpan[o]:
    var off = byte_offset_for_codepoints(text, n)
    if off >= text.byte_length():
        return text
    if not is_char_boundary(text, off):
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, off,
            String("truncation would split a codepoint"),
        )
    try:
        return slice(text, 0, off)
    except e:
        raise FormatError(
            FormatErrorKind.TYPE_MISMATCH, off,
            String("truncation would split a codepoint"),
        )


# format_string — render text under a format spec.
def format_string(value: StringSpan, spec: FormatSpec) raises FormatError -> String:
    _reject_non_text_spec(spec)

    var align = spec.align
    if align == Alignment.DEFAULT:
        align = Alignment.LEFT

    # REPR renders the quoted form first, then width/precision apply to it.
    var base: String
    if spec.presentation == FormatType.REPR:
        base = repr(value)
    else:
        base = String(value)

    var result: String
    if spec.precision:
        result = String(_truncate_codepoints(StringSpan(base), spec.precision.value()))
    else:
        result = base^

    var codepoints = result.count_codepoints()
    return pad(result, spec.width, Int(align._id), spec.fill, codepoints)

# API-DOCS-START
# format_string — render text under a format spec.
# Signature:
#   def format_string(value: StringSpan, spec: FormatSpec) raises FormatError -> String
# What it does:
#   Renders `value` under `spec`. The allowed presentations are DEFAULT, STRING
#   and REPR. `precision`, when present, is the maximum number of codepoints; the
#   text is truncated at a codepoint boundary, never mid-sequence. Only fill,
#   align and width are valid; sign, grouping, alt_form, zero_pad and SIGN_AWARE
#   are rejected. The text is truncated to `precision` codepoints, then padded to
#   `width` codepoints with the fill character according to `align` (default
#   LEFT). REPR renders the quoted repr form first, then applies width/precision.
#   `value` is borrowed and may be dropped after the call.
# Returns:
#   A newly allocated String owned by the caller.
# Errors:
#   raises FormatError with kind TYPE_MISMATCH — a numeric presentation, or a
#   sign, grouping, zero-pad or SIGN_AWARE specification on a string. Recoverable.
# Example:
#   print(format_string("hi", parse_format_spec(">5")))     # -> "   hi"
#   print(format_string("héllo", parse_format_spec(".2")))  # -> "hé"
#   print(format_string("hi", parse_format_spec("r")))      # -> 'hi'
# API-DOCS-END
