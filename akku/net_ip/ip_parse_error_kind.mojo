# IpParseErrorKind — the closed reason an address text failed to parse.
struct IpParseErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    def __eq__(self, other: Self) -> Bool:
        return self._id == other._id

    comptime EMPTY_INPUT           = IpParseErrorKind(0)  # no bytes at all
    comptime INVALID_CHARACTER     = IpParseErrorKind(1)  # byte not allowed where it appeared
    comptime OCTET_OUT_OF_RANGE    = IpParseErrorKind(2)  # an IPv4 octet > 255
    comptime SEGMENT_OUT_OF_RANGE  = IpParseErrorKind(3)  # an IPv6 group > 0xffff
    comptime TOO_FEW_GROUPS        = IpParseErrorKind(4)  # fewer groups than the family needs
    comptime TOO_MANY_GROUPS       = IpParseErrorKind(5)  # more groups than the family allows
    comptime BAD_GROUP_SEPARATOR   = IpParseErrorKind(6)  # missing/extra '.' or ':'
    comptime BAD_IPV6_COMPRESSION  = IpParseErrorKind(7)  # a second '::' or an ambiguous '::'
    comptime ZONE_NOT_SUPPORTED    = IpParseErrorKind(8)  # a '%zone' suffix (not supported yet)

    def write_to(self, mut writer: Some[Writer]):
        if self._id == 0:
            writer.write("EMPTY_INPUT")
        elif self._id == 1:
            writer.write("INVALID_CHARACTER")
        elif self._id == 2:
            writer.write("OCTET_OUT_OF_RANGE")
        elif self._id == 3:
            writer.write("SEGMENT_OUT_OF_RANGE")
        elif self._id == 4:
            writer.write("TOO_FEW_GROUPS")
        elif self._id == 5:
            writer.write("TOO_MANY_GROUPS")
        elif self._id == 6:
            writer.write("BAD_GROUP_SEPARATOR")
        elif self._id == 7:
            writer.write("BAD_IPV6_COMPRESSION")
        else:
            writer.write("ZONE_NOT_SUPPORTED")

# API-DOCS-START
# IpParseErrorKind — the machine-testable reason an address text was rejected.
# Signature:
#   struct IpParseErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime EMPTY_INPUT / INVALID_CHARACTER / OCTET_OUT_OF_RANGE /
#                SEGMENT_OUT_OF_RANGE / TOO_FEW_GROUPS / TOO_MANY_GROUPS /
#                BAD_GROUP_SEPARATOR / BAD_IPV6_COMPRESSION / ZONE_NOT_SUPPORTED
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Read from `IpParseError.kind` inside an except block; never constructed or
#   passed by a caller. The nine kinds are the complete set:
#     EMPTY_INPUT           — the input was empty.
#     INVALID_CHARACTER     — a byte that is not a digit, a hex digit, '.' or ':'.
#     OCTET_OUT_OF_RANGE    — an IPv4 dotted group greater than 255.
#     SEGMENT_OUT_OF_RANGE  — an IPv6 group greater than 0xffff.
#     TOO_FEW_GROUPS        — an IPv4 address with fewer than four octets (or an
#                             IPv6 address with too few groups and no '::').
#     TOO_MANY_GROUPS       — more groups than the family allows.
#     BAD_GROUP_SEPARATOR   — a missing or misplaced '.' or ':'.
#     BAD_IPV6_COMPRESSION  — a '::' that appears twice, or that would stand for
#                             a negative number of groups.
#     ZONE_NOT_SUPPORTED    — a trailing '%zone' (scope id); rejected for now.
#   It also implements Writable, so `print(err.kind)` shows the symbolic name.
# Returns:
#   A value type (compile-time constants); reading `.kind` returns an
#   IpParseErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = parse("256.1.1.1")
#   except e:
#       print(e.kind == IpParseErrorKind.OCTET_OUT_OF_RANGE)   # True
# API-DOCS-END
