from std.os import abort

from .format_args import FormatArgs
from .format_error import FormatError


# format_template — bind a runtime template and return the formatted String.
def format_template(
    template: StringSpan, args: FormatArgs
) raises FormatError -> String:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# format_template — bind a runtime template and return the formatted String.
# Signature:
#   def format_template(
#       template: StringSpan, args: FormatArgs
#   ) raises FormatError -> String
# What it does:
#   Renders `template`, replacing each `{...}` field with its argument rendered
#   under the field's spec/conversion. Literal text is copied unchanged; `{{` and
#   `}}` escape literal braces. A field is `{[arg_index][conversion][:spec]}`:
#   `arg_index` is zero-based and a template uses either all implicit `{}` or all
#   explicit `{n}` (never mixed); `conversion` is `!s` (display) or `!r` (repr);
#   `spec` is parsed by parse_format_spec. Implicit fields consume arguments left
#   to right and an explicit index may be reused (`{0} {0}`). `template` is
#   borrowed and `args` is borrowed for the call.
# Returns:
#   A newly allocated String owned by the caller.
# Errors:
#   raises FormatError with kind:
#     MALFORMED_TEMPLATE — unbalanced or bad braces, an empty/bad field, an
#                          unknown conversion, or mixed auto/manual numbering.
#     INVALID_SPEC       — a field's spec does not follow the grammar.
#     MISSING_ARGUMENT   — a field index has no corresponding argument.
#     EXTRA_ARGUMENT     — an argument is never referenced by any field.
#     TYPE_MISMATCH      — a field's spec is not applicable to its argument kind.
#   All are recoverable and carry a byte position in `template`.
# Example:
#   var args = FormatArgs()
#   args.push_int(42)
#   print(format_template("n = {}", args))          # -> n = 42
#   print(format_template("{0} {0}", args))         # -> 42 42
#   print(format_template("{{literal}}", args))     # -> {literal}
# API-DOCS-END
