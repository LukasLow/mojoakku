# MojoAkku text_format — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from akku.text_format import ...` works. Nothing else lives here: the public
# surface is defined by the per-entry files and this file only forwards names.

from .format_error_kind import FormatErrorKind
from .format_error import FormatError
from .alignment import Alignment
from .sign_mode import SignMode
from .format_type import FormatType
from .grouping import Grouping
from .format_spec import FormatSpec
from .parse_format_spec import parse_format_spec
from .format_int import format_int
from .format_float import format_float
from .format_string import format_string
from .format_bool import format_bool
from .format_args import FormatArgs
from .format_template import format_template
from .format_template_to import format_template_to

# API-DOCS-START
# Purpose   — akku/text_format is the string-formatting library for MojoAkku: it
#   turns typed values into text in a controlled shape. Mojo 1.x already ships the
#   formatting traits (Writable.write_to / write_repr_to, Writer.write_string /
#   write), the interpolation literal t"..." (TString) and String.format() with
#   {} / {n} indexing, so this library rebuilds none of them. It fills the three
#   gaps the standard library leaves: a format-spec mini-language (width,
#   precision, alignment, fill, sign, radix/type, alternate form and grouping), a
#   runtime template that binds already-evaluated values and escapes braces, and
#   an explicit typed error contract for malformed input and arity/type mistakes.
#   It is a pure, in-process, deterministic library: no I/O, no Python, no FFI and
#   no hidden global state.
# Overview  — four small layers over the stdlib String/StringSpan/Writer model:
#     1. Error surface     — FormatErrorKind + FormatError: one closed
#        discriminant and one typed error carrying a byte position and a message.
#     2. Format spec       — the discriminants Alignment, SignMode, FormatType and
#        Grouping, the value type FormatSpec, and parse_format_spec to validate a
#        spec string into a FormatSpec.
#     3. Per-value apply   — format_int, format_float, format_string and
#        format_bool, each producing an owned String and raising on an
#        incompatible presentation.
#     4. Runtime template  — FormatArgs (an ordered, typed argument list) with
#        format_template (returns an owned String) and format_template_to (writes
#        straight through any Writer).
#   The spec grammar is [[fill]align][sign][#][0][width][grouping][.precision]
#   [presentation]; a template field is {[arg_index][!s|!r][:spec]}. Positions are
#   byte offsets, widths count codepoints, and errors are typed values.
# Dependencies — akku.text_string. The edge is technically justified: string
#   precision truncates to a maximum number of codepoints and must not split a
#   UTF-8 sequence, which reuses text_string.is_char_boundary and text_string
#   .slice (both report a typed error instead of aborting), and the owned output
#   is accumulated through text_string.StringBuilder, which already conforms to
#   Writer. No other sibling is mentioned by any signature; TString, Writable and
#   Writer are stdlib, not siblings. text_format is a flat sibling under akku/ and
#   nests no library.
# Public API — the ordered index (each entry is specified in its own file):
#     1. FormatErrorKind — closed failure discriminant: MALFORMED_TEMPLATE,
#                          INVALID_SPEC, MISSING_ARGUMENT, EXTRA_ARGUMENT,
#                          TYPE_MISMATCH.
#     2. FormatError     — the one typed error: kind, position, message.
#     3. Alignment       — alignment discriminant: DEFAULT, LEFT, RIGHT, CENTER,
#                          SIGN_AWARE.
#     4. SignMode        — sign discriminant: NEGATIVE_ONLY, ALWAYS, SPACE.
#     5. FormatType      — presentation discriminant: DEFAULT, BINARY, OCTAL,
#                          DECIMAL, LOWER_HEX, UPPER_HEX, CHAR, STRING, REPR,
#                          FIXED, SCIENTIFIC, UPPER_SCIENTIFIC.
#     6. Grouping        — digit-grouping discriminant: NONE, COMMA, UNDERSCORE.
#     7. FormatSpec      — the parsed spec value (fill, align, sign, alt form,
#                          zero pad, width, precision, grouping, presentation).
#     8. parse_format_spec — parse and validate a spec string into a FormatSpec.
#     9. format_int      — render an integer under a spec.
#    10. format_float    — render a float under a spec.
#    11. format_string   — render a string under a spec (width/precision in
#                          codepoints).
#    12. format_bool     — render a bool under a spec.
#    13. FormatArgs      — an ordered, typed argument list.
#    14. format_template — bind a runtime template, return an owned String.
#    15. format_template_to — bind a runtime template, write through a Writer.
# Error Surface — exactly one error type, FormatError, carrying kind:
#   FormatErrorKind, position: Int and message: String. Which API raises what:
#     parse_format_spec  — INVALID_SPEC
#     format_int         — TYPE_MISMATCH, INVALID_SPEC
#     format_float       — TYPE_MISMATCH, INVALID_SPEC
#     format_string      — TYPE_MISMATCH
#     format_bool        — TYPE_MISMATCH
#     format_template,
#       format_template_to — MALFORMED_TEMPLATE, INVALID_SPEC,
#                            MISSING_ARGUMENT, EXTRA_ARGUMENT, TYPE_MISMATCH
#     FormatErrorKind, FormatError, Alignment, SignMode, FormatType, Grouping,
#       FormatSpec, FormatArgs — none
#   Every FormatError is a recoverable data error. print(err) gives a readable
#   kind + position + message, and a caught error is re-raised by transfer with
#   `raise e^`.
# Conventions — the spec grammar field order is [[fill]align][sign][#][0][width]
#   [grouping][.precision][presentation]; a fill needs an alignment. Template
#   arg_index is ZERO-based ({0}, {1}), matching Mojo's own String.format(); a
#   template uses either all implicit {} or all explicit {n}, never both.
#   Conversions are !s (display) and !r (debug/repr). Width counts codepoints,
#   not bytes; string precision is a maximum codepoint count truncated on a
#   codepoint boundary. Default alignment is left for strings and bools, right for
#   numbers; SIGN_AWARE is valid only for numbers. Arguments are bound by
#   position, never by name. Names are snake_case for functions/methods and fields,
#   CamelCase for types, SCREAMING_CASE for comptime constants. There is no hidden
#   global state, no ambient locale and no default width.
# API-DOCS-END
