from std.os import abort

from .format_error import FormatError
from .format_spec import FormatSpec


# format_float — render a float under a format spec.
def format_float(value: Float64, spec: FormatSpec) raises FormatError -> String:
    abort("MojoAkku: this API is not yet implemented")

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
