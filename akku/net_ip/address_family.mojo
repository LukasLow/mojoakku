# AddressFamily — the closed family tag carried by IpAddress.
struct AddressFamily(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Written explicitly so equality compares the discriminant only.
    def __eq__(self, other: Self) -> Bool:
        return self._id == other._id

    comptime IPV4 = AddressFamily(0)
    comptime IPV6 = AddressFamily(1)

    def write_to(self, mut writer: Some[Writer]):
        if self._id == 0:
            writer.write("IPV4")
        else:
            writer.write("IPV6")

# API-DOCS-START
# AddressFamily — the family of an IP address: IPv4 or IPv6.
# Signature:
#   struct AddressFamily(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime IPV4 = AddressFamily(0)
#       comptime IPV6 = AddressFamily(1)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Returned by IpAddress.family(); the two members are the complete set.
#     IPV4 — a 32-bit address.
#     IPV6 — a 128-bit address.
#   It is a compile-time value type; compare with `==`. It also implements
#   Writable, so `print(fam)` shows the symbolic name, never the number.
# Returns:
#   A value type (compile-time constants); reading `.family()` returns an
#   AddressFamily owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   if addr.family() == AddressFamily.IPV6:
#       print("v6")
#   print(AddressFamily.IPV4)              # -> IPV4
# API-DOCS-END
