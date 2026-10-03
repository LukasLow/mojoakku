from std.os import abort

from .format_error import FormatError
from .format_spec import FormatSpec


# format_bool — render a bool under a format spec.
def format_bool(value: Bool, spec: FormatSpec) raises FormatError -> String:
    abort("MojoAkku: this API is not yet implemented")

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
