# template.mojo — private runtime-template parser and renderer shared by
# format_template and format_template_to. Nothing here is public API.
#
# The template is parsed completely before any output is produced, so a parse
# error (malformed braces, unknown conversion, unknown spec, mixed numbering,
# missing/extra argument) leaves the destination untouched. A type error in a
# later field is detected during rendering, after earlier segments have already
# been written — the documented partial-output behaviour.

from akku.text_format.format_args import FormatArgs
from akku.text_format.format_bool import format_bool
from akku.text_format.format_error import FormatError
from akku.text_format.format_error_kind import FormatErrorKind
from akku.text_format.format_float import format_float
from akku.text_format.format_int import format_int
from akku.text_format.format_spec import FormatSpec
from akku.text_format.format_string import format_string
from akku.text_format.format_type import FormatType
from akku.text_format.parse_format_spec import parse_format_spec


# FormatSegment — one parsed piece of a template: literal text or a field.
struct FormatSegment(Copyable, Movable, Deinitable):
    var _is_field: Bool
    var _literal: String
    var _index: Int
    var _conversion: Int   # 0 none, 1 's', 2 'r'
    var _spec: FormatSpec

    def __init__(out self, literal: String):
        self._is_field = False
        self._literal = literal
        self._index = 0
        self._conversion = 0
        self._spec = FormatSpec()

    def __init__(out self, index: Int, conversion: Int, spec: FormatSpec):
        self._is_field = True
        self._literal = String()
        self._index = index
        self._conversion = conversion
        self._spec = spec


# parse_template — parse a template into literal/field segments, validating the
# documented arity and numbering rules against `arg_count`.
def parse_template(
    template: StringSpan, arg_count: Int
) raises FormatError -> List[FormatSegment]:
    var segments = List[FormatSegment]()
    var bytes = template.as_bytes()
    var n = len(bytes)
    var i = 0

    # 0 undecided, 1 implicit ({}), 2 explicit ({n}).
    var numbering = 0
    var next_auto = 0
    var used = List[Bool]()
    for _ in range(arg_count):
        used.append(False)

    while i < n:
        var b = bytes[i]

        # Escaped literal braces.
        if b == 123 and i + 1 < n and bytes[i + 1] == 123:      # '{{'
            segments.append(FormatSegment(String("{")))
            i += 2
            continue
        if b == 125 and i + 1 < n and bytes[i + 1] == 125:      # '}}'
            segments.append(FormatSegment(String("}")))
            i += 2
            continue

        # Literal run up to the next brace.
        if b != 123 and b != 125:
            var start = i
            while i < n and bytes[i] != 123 and bytes[i] != 125:
                i += 1
            segments.append(FormatSegment(String(template[byte=start:i])))
            continue

        # A single '}' with no matching '{' is malformed.
        if b == 125:
            raise FormatError(
                FormatErrorKind.MALFORMED_TEMPLATE, i, String("unmatched '}'")
            )

        # --- a field: '{' ... '}' ---
        var field_start = i
        i += 1

        var index = -1
        var explicit = False
        var digit_start = i
        while i < n and bytes[i] >= 48 and bytes[i] <= 57:
            i += 1
        if i > digit_start:
            explicit = True
            index = 0
            for k in range(digit_start, i):
                index = index * 10 + (Int(bytes[k]) - 48)

        var conversion = 0
        if i < n and bytes[i] == 33:        # '!'
            if i + 1 < n and bytes[i + 1] == 115:      # 's'
                conversion = 1
                i += 2
            elif i + 1 < n and bytes[i + 1] == 114:    # 'r'
                conversion = 2
                i += 2
            else:
                raise FormatError(
                    FormatErrorKind.MALFORMED_TEMPLATE, i, String("unknown conversion")
                )

        var spec = FormatSpec()
        if i < n and bytes[i] == 58:        # ':'
            var spec_start = i + 1
            var j = spec_start
            while j < n and bytes[j] != 125:
                j += 1
            if j >= n:
                raise FormatError(
                    FormatErrorKind.MALFORMED_TEMPLATE, field_start,
                    String("unclosed field"),
                )
            try:
                spec = parse_format_spec(template[byte=spec_start:j])
            except e:
                raise FormatError(
                    FormatErrorKind.INVALID_SPEC, spec_start + e.position, e.message
                )
            i = j

        if i >= n or bytes[i] != 125:
            raise FormatError(
                FormatErrorKind.MALFORMED_TEMPLATE, field_start,
                String("unclosed field"),
            )
        i += 1      # consume '}'

        # --- numbering rules ---
        if explicit:
            if numbering == 1:
                raise FormatError(
                    FormatErrorKind.MALFORMED_TEMPLATE, field_start,
                    String("mixed automatic and explicit numbering"),
                )
            numbering = 2
        else:
            if numbering == 2:
                raise FormatError(
                    FormatErrorKind.MALFORMED_TEMPLATE, field_start,
                    String("mixed automatic and explicit numbering"),
                )
            numbering = 1
            index = next_auto
            next_auto += 1

        if index >= arg_count:
            raise FormatError(
                FormatErrorKind.MISSING_ARGUMENT, field_start,
                String("no argument for this field"),
            )
        used[index] = True
        segments.append(FormatSegment(index, conversion, spec))

    # Every supplied argument must be referenced.
    for k in range(arg_count):
        if not used[k]:
            raise FormatError(
                FormatErrorKind.EXTRA_ARGUMENT, n,
                String("argument is never referenced by any field"),
            )

    return segments^


# render_segments — write the parsed segments through `writer`, binding each
# field to its argument.
def render_segments(
    mut writer: Some[Writer], segments: List[FormatSegment], args: FormatArgs
) raises FormatError:
    for seg in segments:
        if not seg._is_field:
            writer.write(seg._literal)
            continue
        var spec = seg._spec
        if seg._conversion == 2:
            spec.presentation = FormatType.REPR
        var kind = args._args[seg._index].kind()
        if kind == 0:
            writer.write(format_int(args._args[seg._index].as_int(), spec))
        elif kind == 1:
            writer.write(format_float(args._args[seg._index].as_float(), spec))
        elif kind == 2:
            writer.write(format_string(args._args[seg._index].text(), spec))
        else:
            writer.write(format_bool(args._args[seg._index].as_bool(), spec))
