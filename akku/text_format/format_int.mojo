from std.os import abort

from .format_error import FormatError
from .format_spec import FormatSpec


# format_int — render an integer under a format spec.
def format_int(value: Int, spec: FormatSpec) raises FormatError -> String:
    abort("MojoAkku: this API is not yet implemented")

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
