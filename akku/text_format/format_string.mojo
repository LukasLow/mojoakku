from std.os import abort

from .format_error import FormatError
from .format_spec import FormatSpec


# format_string — render text under a format spec.
def format_string(value: StringSpan, spec: FormatSpec) raises FormatError -> String:
    abort("MojoAkku: this API is not yet implemented")

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
