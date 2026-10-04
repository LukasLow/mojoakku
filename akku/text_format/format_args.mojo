from akku.text_format._internal.format_arg import FormatArg


# FormatArgs — an ordered, typed argument list for format_template.
struct FormatArgs(Deinitable):
    var _args: List[FormatArg]

    # __init__ — start with an empty argument list.
    def __init__(out self):
        self._args = List[FormatArg]()

    # push_int — append one Int argument at the end.
    def push_int(mut self, var value: Int):
        self._args.append(FormatArg(value))

    # push_float — append one Float64 argument at the end.
    def push_float(mut self, var value: Float64):
        self._args.append(FormatArg(value))

    # push_string — append one owned String argument at the end.
    def push_string(mut self, var value: String):
        self._args.append(FormatArg(value^))

    # push_bool — append one Bool argument at the end.
    def push_bool(mut self, var value: Bool):
        self._args.append(FormatArg(value))

    # count — the number of arguments pushed so far.
    def count(self) -> Int:
        return len(self._args)

# API-DOCS-START
# FormatArgs — an ordered, typed argument list for format_template.
# Signature:
#   struct FormatArgs(Deinitable):
#       def __init__(out self)
#       def push_int(mut self, var value: Int)
#       def push_float(mut self, var value: Float64)
#       def push_string(mut self, var value: String)
#       def push_bool(mut self, var value: Bool)
#       def count(self) -> Int
# What it does:
#   Collects the arguments a runtime template binds, in order. Create an empty
#   list and append with push_int/push_float/push_string/push_bool; the kind you
#   push decides which formatter the template uses for that argument, and there is
#   no implicit conversion between kinds. A String pushed with push_string is
#   owned by the list (transfer it with `^`). Arguments are bound by position,
#   never by name; `count()` reports how many have been pushed. The list is
#   move-only and is not implicitly copyable.
# Returns:
#   A value type that owns its argument list; count() returns an Int.
# Errors:
#   none — pushing and counting cannot fail.
# Example:
#   var args = FormatArgs()
#   args.push_int(42)
#   args.push_string(String("mojo"))
#   print(args.count())          # -> 2
#   # format_template("{} {}", args)  # later phase
# API-DOCS-END
