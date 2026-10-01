from std.os import abort


# TimeErrorKind — compile-time discriminant for TimeError.
struct TimeErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Explicit override of Equatable's field-wise default: compares the
    # discriminant `_id` only.
    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    comptime OVERFLOW         = TimeErrorKind(0)   # a result does not fit the Int carrier
    comptime DIVISION_BY_ZERO = TimeErrorKind(1)   # a divisor of zero was requested

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# TimeErrorKind — the machine-testable reason a time operation failed.
# Signature:
#   struct TimeErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime OVERFLOW         = TimeErrorKind(0)
#       comptime DIVISION_BY_ZERO = TimeErrorKind(1)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from `TimeError.kind` inside an except block; it is never
#   constructed or passed to a time operation. The two kinds are the complete,
#   closed set:
#     OVERFLOW         — an arithmetic result or a unit scaling does not fit the
#                        Int carrier.
#     DIVISION_BY_ZERO — a divisor of zero was requested (no Inf/NaN duration).
#   It also implements Writable, so printing a kind shows its symbolic name.
# Returns:
#   A value type; reading `.kind` returns a TimeErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = Duration.from_seconds(1).scaled(-1_000_000_000_000_000_000)
#   except e:
#       print(e.kind == TimeErrorKind.OVERFLOW)   # True
#   print(TimeErrorKind.DIVISION_BY_ZERO)         # -> DIVISION_BY_ZERO
# API-DOCS-END
