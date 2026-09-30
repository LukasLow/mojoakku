from .address_family import AddressFamily
from .ipv4_address import Ipv4Address
from .ipv6_address import Ipv6Address


# IpAddress — a family-tagged IPv4 or IPv6 address.
struct IpAddress(Copyable, Movable, Deinitable, Equatable, Writable):
    var _family: AddressFamily
    var _v4: UInt32
    var _v6: UInt128

    @doc_hidden
    def __init__(out self, family: AddressFamily, v4: UInt32, v6: UInt128):
        self._family = family
        self._v4 = v4
        self._v6 = v6

    # family — the address family (read-only accessor).
    def family(self) -> AddressFamily:
        return self._family

    @staticmethod
    def from_ipv4(address: Ipv4Address) -> Self:
        return Self(AddressFamily.IPV4, address.to_u32(), UInt128(0))

    @staticmethod
    def from_ipv6(address: Ipv6Address) -> Self:
        return Self(AddressFamily.IPV6, UInt32(0), address.to_u128())

    def is_ipv4(self) -> Bool:
        return self._family._id == 0

    def is_ipv6(self) -> Bool:
        return self._family._id == 1

    def to_ipv4(self) -> Optional[Ipv4Address]:
        if self._family._id == 0:
            var out = Ipv4Address(self._v4)
            return out^
        return None

    def to_ipv6(self) -> Optional[Ipv6Address]:
        if self._family._id == 1:
            var out = Ipv6Address(self._v6)
            return out^
        return None

    def unmap(self) -> IpAddress:
        # An IPv4-mapped IPv6 address becomes its IPv4 form; anything else is
        # returned unchanged.
        if self._family._id == 1:
            var v6 = Ipv6Address(self._v6)
            var v4 = v6.to_ipv4_mapped()
            if v4:
                return IpAddress.from_ipv4(v4.value())
        return IpAddress(self._family, self._v4, self._v6)

    def is_unspecified(self) -> Bool:
        if self._family._id == 0:
            return Ipv4Address(self._v4).is_unspecified()
        return Ipv6Address(self._v6).is_unspecified()

    def is_loopback(self) -> Bool:
        if self._family._id == 0:
            return Ipv4Address(self._v4).is_loopback()
        return Ipv6Address(self._v6).is_loopback()

    def is_private(self) -> Bool:
        if self._family._id == 0:
            return Ipv4Address(self._v4).is_private()
        return Ipv6Address(self._v6).is_private()

    def is_link_local(self) -> Bool:
        if self._family._id == 0:
            return Ipv4Address(self._v4).is_link_local()
        return Ipv6Address(self._v6).is_link_local()

    def is_multicast(self) -> Bool:
        if self._family._id == 0:
            return Ipv4Address(self._v4).is_multicast()
        return Ipv6Address(self._v6).is_multicast()

    def compare(self, other: Self) -> Int:
        # IPv4 sorts before IPv6; within a family the numeric order applies.
        if self._family._id != other._family._id:
            if self._family._id < other._family._id:
                return -1
            return 1
        if self._family._id == 0:
            return Ipv4Address(self._v4).compare(Ipv4Address(other._v4))
        return Ipv6Address(self._v6).compare(Ipv6Address(other._v6))

    def __eq__(self, other: Self) -> Bool:
        return self.compare(other) == 0

    def write_to(self, mut writer: Some[Writer]):
        if self._family._id == 0:
            writer.write(Ipv4Address(self._v4))
        else:
            writer.write(Ipv6Address(self._v6))

# API-DOCS-START
# IpAddress — a family-tagged IPv4 or IPv6 address (one "any address" type).
# Signature:
#   struct IpAddress(Copyable, Movable, Deinitable, Equatable, Writable):
#       var _family: AddressFamily
#       var _v4: UInt32
#       var _v6: UInt128
#       def family(self) -> AddressFamily
#       @staticmethod def from_ipv4(address: Ipv4Address) -> Self
#       @staticmethod def from_ipv6(address: Ipv6Address) -> Self
#       def is_ipv4 / is_ipv6(self) -> Bool
#       def to_ipv4 / to_ipv6(self) -> Optional[...]
#       def unmap(self) -> IpAddress
#       def is_unspecified / is_loopback / is_private / is_link_local /
#           is_multicast(self) -> Bool
#       def compare(self, other: Self) -> Int
#       def __eq__(self, other: Self) -> Bool
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Carries both families behind one type, with an explicit `family`
#   discriminant. `to_ipv4`/`to_ipv6` recover the concrete value or None.
#   `unmap` normalizes an IPv4-mapped IPv6 address to its IPv4 form and returns
#   every other address unchanged. `compare` gives a total order: IPv4 before
#   IPv6, then numeric within the family.
# Returns:
#   A value type, owned by the caller.
# Errors:
#   none — a family mismatch is reported as None, not an error.
# Example:
#   var a = IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001))
#   a.is_loopback()                       # -> True
#   IpAddress.from_ipv6(parse_ipv6("::ffff:10.0.0.1")).unmap()   # -> 10.0.0.1
# API-DOCS-END
