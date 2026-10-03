from std.os import abort


# VersionErrorKind — the closed reason a version operation failed.
struct VersionErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Written explicitly so equality compares the discriminant only.
    def __eq__(self, other: Self) -> Bool:
        return self._id == other._id

    comptime EMPTY          = VersionErrorKind(0)   # the input was empty
    comptime INVALID_FORMAT = VersionErrorKind(1)   # structural violation of the SemVer grammar
    comptime BAD_NUMBER     = VersionErrorKind(2)   # a numeric identifier is not all decimal digits
    comptime LEADING_ZERO   = VersionErrorKind(3)   # an all-digit identifier has a leading zero
    comptime OVERFLOW       = VersionErrorKind(4)   # a numeric component does not fit Int
    comptime OTHER          = VersionErrorKind(5)   # any other condition (see VersionError.detail)

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        # Symbolic names, not the numeric _id.
        if self._id == 0:
            writer.write("EMPTY")
        elif self._id == 1:
            writer.write("INVALID_FORMAT")
        elif self._id == 2:
            writer.write("BAD_NUMBER")
        elif self._id == 3:
            writer.write("LEADING_ZERO")
        elif self._id == 4:
            writer.write("OVERFLOW")
        else:
            writer.write("OTHER")

# API-DOCS-START
# VersionErrorKind — the machine-testable reason a version operation failed.
# Signature:
#   struct VersionErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime EMPTY          = VersionErrorKind(0)
#       comptime INVALID_FORMAT = VersionErrorKind(1)
#       comptime BAD_NUMBER     = VersionErrorKind(2)
#       comptime LEADING_ZERO   = VersionErrorKind(3)
#       comptime OVERFLOW       = VersionErrorKind(4)
#       comptime OTHER          = VersionErrorKind(5)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from `VersionError.kind` inside an except block; it is never
#   constructed or passed by a caller. The six kinds are the complete, closed
#   set:
#     EMPTY          — the input string was empty.
#     INVALID_FORMAT — a structural violation: not exactly three core components,
#                      an empty identifier, an unexpected or duplicated `+`/`-`,
#                      a disallowed character in a qualifier, a `v`/`=` prefix,
#                      or surrounding whitespace.
#     BAD_NUMBER     — a core component (or numeric prerelease identifier) is
#                      not all decimal digits, or a constructor component is
#                      negative.
#     LEADING_ZERO   — an all-digit identifier has a leading zero ("01"), which
#                      SemVer clause 2/9 forbids for the core and for numeric
#                      prerelease identifiers.
#     OVERFLOW       — a numeric component does not fit Int.
#     OTHER          — any other condition; the opaque VersionError.detail holds
#                      it. Reserved in release 1: no release-1 operation raises
#                      it.
#   It also implements Writable, so printing a kind shows its symbolic name,
#   never the numeric id. Comparisons use ==.
# Returns:
#   A value type; reading `.kind` returns a VersionErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = parse("not-a-version")
#   except e:
#       print(e.kind == VersionErrorKind.INVALID_FORMAT)   # True
#   print(VersionErrorKind.LEADING_ZERO)                   # -> LEADING_ZERO
# API-DOCS-END
