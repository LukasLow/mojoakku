from akku.text_format._internal.template import parse_template, render_segments

from .format_args import FormatArgs
from .format_error import FormatError


# format_template_to — bind a runtime template and write it through a Writer.
def format_template_to(
    mut writer: Some[Writer], template: StringSpan, args: FormatArgs
) raises FormatError:
    # Parse everything first: a parse-stage error must write nothing.
    var segments = parse_template(template, args.count())
    render_segments(writer, segments, args)

# API-DOCS-START
# format_template_to — bind a runtime template and write it through a Writer.
# Signature:
#   def format_template_to(
#       mut writer: Some[Writer], template: StringSpan, args: FormatArgs
#   ) raises FormatError
# What it does:
#   The same binding as format_template, but the rendered bytes are written
#   directly to `writer`, with no intermediate owned String. Use it when the
#   destination already exists (a file, a socket, a text_string.StringBuilder or
#   any other Writer). `writer` is mutated in place; the library performs no
#   flush, and the writer's own semantics govern blocking and flush.
#   Partial output is possible: a template/spec error detected while parsing
#   (before any write) leaves the writer untouched, but a TYPE_MISMATCH in a later
#   field is detected only after earlier segments have already been written, so the
#   writer then holds the prefix produced so far. Atomicity holds only up to the
#   first write, not for the whole call.
# Returns:
#   Nothing; the output lands in the writer. The caller owns the writer and its
#   buffer.
# Errors:
#   raises FormatError — the same kinds as format_template. The writer's own
#   errors are the writer's contract, not surfaced as FormatError.
# Example:
#   var args = FormatArgs()
#   args.push_string(String("world"))
#   var b = StringBuilder()
#   format_template_to(b, "hello {}", args)
#   print(b)                      # -> hello world
# API-DOCS-END
