from std.os import abort

from .format_error import FormatError
from .format_spec import FormatSpec


# parse_format_spec — parse and validate a spec string into a FormatSpec.
def parse_format_spec(text: StringSpan) raises FormatError -> FormatSpec:
    abort("MojoAkku: this API is not yet implemented")

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
