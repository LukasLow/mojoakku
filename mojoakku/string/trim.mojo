from std.os import abort


# trim — strip leading/trailing Unicode whitespace, or an explicit char set.
def trim[o: Origin[mut=False]](text: StringSpan[o]) -> StringSpan[o]:
    abort("MojoAkku: this API is not yet implemented")


def trim[o: Origin[mut=False]](text: StringSpan[o], chars: StringSpan) -> StringSpan[o]:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# trim — remove leading and trailing whitespace, or an explicit character set.
# Signature:
#   def trim[o: Origin[mut=False]](text: StringSpan[o]) -> StringSpan[o]
#   def trim[o: Origin[mut=False]](text: StringSpan[o], chars: StringSpan) -> StringSpan[o]
# What it does:
#   The one-argument form strips leading and trailing Unicode whitespace
#   (U+0009-U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000-U+200A, U+2028,
#   U+2029, U+202F, U+205F, U+3000). The two-argument form strips any leading or
#   trailing codepoint that is a member of the SET `chars` — not a prefix or
#   suffix that must match as a whole. `text` is borrowed; the result is a view
#   into it, so nothing is allocated. An all-whitespace input yields the empty
#   view.
# Returns:
#   A borrowed view into `text` with the matching bytes removed from both ends.
#   The view stays valid as long as `text` does.
# Errors:
#   none — trimming cannot fail.
# Example:
#   print(trim("  hi  "))            # -> hi
#   print(trim("\u00A0x\u3000"))     # -> x (Unicode whitespace, unlike std strip)
#   print(trim("xxaxx", "x"))        # -> a  (chars is a set)
#   print(trim("abc", ""))           # -> abc (empty set strips nothing)
# API-DOCS-END
