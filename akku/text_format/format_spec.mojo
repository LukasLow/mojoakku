from std.os import abort

from .alignment import Alignment
from .format_type import FormatType
from .grouping import Grouping
from .sign_mode import SignMode


# FormatSpec — the parsed format specification one value is rendered under.
struct FormatSpec(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var fill: Codepoint           # default ' ' (space)
    var align: Alignment          # default Alignment.DEFAULT
    var sign: SignMode            # default SignMode.NEGATIVE_ONLY
    var alt_form: Bool            # default False ('#')
    var zero_pad: Bool            # default False ('0')
    var width: Int                # default 0 (no minimum width)
    var precision: Optional[Int]  # default None
    var grouping: Grouping        # default Grouping.NONE
    var presentation: FormatType  # default FormatType.DEFAULT

    # __init__ — the neutral spec, equivalent to an empty spec string.
    def __init__(out self):
        self.fill = Codepoint(32)          # ' '
        self.align = Alignment.DEFAULT
        self.sign = SignMode.NEGATIVE_ONLY
        self.alt_form = False
        self.zero_pad = False
        self.width = 0
        self.precision = None
        self.grouping = Grouping.NONE
        self.presentation = FormatType.DEFAULT

    # __init__ — the fully resolved spec, one argument per grammar element.
    def __init__(
        out self,
        fill: Codepoint,
        align: Alignment,
        sign: SignMode,
        alt_form: Bool,
        zero_pad: Bool,
        width: Int,
        precision: Optional[Int],
        grouping: Grouping,
        presentation: FormatType,
    ):
        self.fill = fill
        self.align = align
        self.sign = sign
        self.alt_form = alt_form
        self.zero_pad = zero_pad
        self.width = width
        self.precision = precision
        self.grouping = grouping
        self.presentation = presentation

    # write_to — the grammar-like form, used by print(spec).
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# FormatSpec — the fully resolved format specification a value is rendered under.
# Signature:
#   struct FormatSpec(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
#       var fill: Codepoint
#       var align: Alignment
#       var sign: SignMode
#       var alt_form: Bool
#       var zero_pad: Bool
#       var width: Int
#       var precision: Optional[Int]
#       var grouping: Grouping
#       var presentation: FormatType
#       def __init__(out self)
#       def __init__(
#           out self, fill: Codepoint, align: Alignment, sign: SignMode,
#           alt_form: Bool, zero_pad: Bool, width: Int,
#           precision: Optional[Int], grouping: Grouping,
#           presentation: FormatType,
#       )
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Holds one grammar element per field, in grammar order:
#     fill + align — the padding codepoint and its side.
#     sign         — how a number's sign is rendered.
#     alt_form     — '#' (integer 0x/0o/0b prefixes, forced decimal point).
#     zero_pad     — '0' sign-aware zero padding.
#     width        — minimum field width in codepoints (0 means no minimum).
#     precision    — a minimum digit count for integers, digits after the point
#                    for floats, and a maximum codepoint count for strings; None
#                    means "not given".
#     grouping     — the integer thousands separator.
#     presentation — the selected form (radix, float style, text).
#   `__init__()` returns the neutral spec, equivalent to an empty spec string. All
#   fields are public and may be set after construction, or use the full
#   constructor. A width below 0 is treated as 0; fill may be any codepoint except
#   '{' or '}'. Build a validated spec with parse_format_spec.
# Returns:
#   A plain value, copyable and implicitly copyable; it owns nothing.
# Errors:
#   none — construction cannot fail; parse_format_spec is the validating entry.
# Example:
#   var spec = FormatSpec()
#   print(spec.width)                 # -> 0
#   var hex = FormatSpec(
#       Codepoint(32), Alignment.DEFAULT, SignMode.NEGATIVE_ONLY, False, False,
#       0, None, Grouping.NONE, FormatType.LOWER_HEX,
#   )
#   print(hex.presentation)           # -> LOWER_HEX
# API-DOCS-END
