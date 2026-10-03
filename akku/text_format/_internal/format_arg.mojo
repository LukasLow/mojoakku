from std.utils import Variant


# FormatArg — the internal closed union of the argument kinds that FormatArgs can
# carry. It is private: no public signature names it, and it exists only so
# FormatArgs can hold the four supported value types (Int, Float64, String, Bool)
# in one ordered list. This is a data declaration only; the template engine that
# inspects it is implemented in a later phase.
comptime FormatArg = Variant[Int, Float64, String, Bool]
