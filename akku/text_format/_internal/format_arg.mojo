# format_arg.mojo — the internal closed union of the argument kinds FormatArgs
# can carry.
#
# This is private: no public signature names it. It exists so FormatArgs can hold
# the four supported value types (Int, Float64, String, Bool) in one ordered list
# and so the template renderer can read a stored argument by kind without a
# runtime mutable access (Mojo's std Variant requires `mut` even to read). The
# struct is a plain data carrier with read-only accessors; the ordering and the
# kind tags are the whole contract.


# FormatArg — one stored argument: a kind tag plus the four typed slots.
struct FormatArg(Movable, Deinitable):
    var _kind: Int       # 0 int, 1 float, 2 string, 3 bool
    var _int: Int
    var _float: Float64
    var _text: String
    var _bool: Bool

    def __init__(out self, value: Int):
        self._kind = 0
        self._int = value
        self._float = 0.0
        self._text = String()
        self._bool = False

    def __init__(out self, value: Float64):
        self._kind = 1
        self._int = 0
        self._float = value
        self._text = String()
        self._bool = False

    def __init__(out self, var value: String):
        self._kind = 2
        self._int = 0
        self._float = 0.0
        self._text = value^
        self._bool = False

    def __init__(out self, value: Bool):
        self._kind = 3
        self._int = 0
        self._float = 0.0
        self._text = String()
        self._bool = value

    # kind — 0 int, 1 float, 2 string, 3 bool.
    def kind(self) -> Int:
        return self._kind

    # as_int — the Int slot (valid when kind == 0).
    def as_int(self) -> Int:
        return self._int

    # as_float — the Float64 slot (valid when kind == 1).
    def as_float(self) -> Float64:
        return self._float

    # as_bool — the Bool slot (valid when kind == 3).
    def as_bool(self) -> Bool:
        return self._bool

    # text — a borrowed view of the String slot (valid when kind == 2).
    def text(self) -> StringSpan[origin_of(self._text)]:
        return StringSpan(self._text)
