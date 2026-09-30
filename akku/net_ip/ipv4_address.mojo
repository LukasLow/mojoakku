from .ip_parse_error import IpParseError
from .ip_parse_error_kind import IpParseErrorKind

from akku.net_ip._internal.ip_core import (
    octets_to_u32,
    u32_octet,
    format_ipv4,
    v4_is_unspecified,
    v4_is_loopback,
    v4_is_private,
    v4_is_link_local,
    v4_is_multicast,
    v4_is_broadcast,
    v4_next,
    v4_prev,
)


# Ipv4Address — an IPv4 address value.
struct Ipv4Address(Copyable, Movable, Deinitable, Equatable, Writable):
    var _b: UInt32

    @doc_hidden
    def __init__(out self, b: UInt32):
        self._b = b

    @staticmethod
    def from_octets(a: UInt8, b: UInt8, c: UInt8, d: UInt8) -> Self:
        return Self(octets_to_u32(a, b, c, d))

    @staticmethod
    def from_u32(value: UInt32) -> Self:
        return Self(value)

    @staticmethod
    def from_bytes(bytes: Span[UInt8, _]) raises IpParseError -> Self:
        if len(bytes) != 4:
            if len(bytes) < 4:
                raise IpParseError(IpParseErrorKind.TOO_FEW_GROUPS, len(bytes))
            raise IpParseError(IpParseErrorKind.TOO_MANY_GROUPS, 4)
        return Self(octets_to_u32(bytes[0], bytes[1], bytes[2], bytes[3]))

    def to_u32(self) -> UInt32:
        return self._b

    def octets(self) -> Array[UInt8, 4]:
        var out = Array[UInt8, 4](fill=0)
        for i in range(4):
            out[i] = u32_octet(self._b, i)
        return out^

    def is_unspecified(self) -> Bool:
        return v4_is_unspecified(self._b)

    def is_loopback(self) -> Bool:
        return v4_is_loopback(self._b)

    def is_private(self) -> Bool:
        return v4_is_private(self._b)

    def is_link_local(self) -> Bool:
        return v4_is_link_local(self._b)

    def is_multicast(self) -> Bool:
        return v4_is_multicast(self._b)

    def is_broadcast(self) -> Bool:
        return v4_is_broadcast(self._b)

    def next(self) -> Optional[Ipv4Address]:
        var v = v4_next(self._b)
        if v:
            var out = Ipv4Address(v.value())
            return out^
        return None

    def prev(self) -> Optional[Ipv4Address]:
        var v = v4_prev(self._b)
        if v:
            var out = Ipv4Address(v.value())
            return out^
        return None

    def __eq__(self, other: Self) -> Bool:
        return self._b == other._b

    def compare(self, other: Self) -> Int:
        if self._b < other._b:
            return -1
        if self._b > other._b:
            return 1
        return 0

    def write_to(self, mut writer: Some[Writer]):
        writer.write(format_ipv4(self._b))

# API-DOCS-START
# Ipv4Address — an IPv4 address value.
# Signature:
#   struct Ipv4Address(Copyable, Movable, Deinitable, Equatable, Writable):
#       var _b: UInt32
#       @staticmethod def from_octets(a, b, c, d: UInt8) -> Self
#       @staticmethod def from_u32(value: UInt32) -> Self
#       @staticmethod def from_bytes(bytes: Span[UInt8]) raises IpParseError -> Self
#       def to_u32(self) -> UInt32
#       def octets(self) -> Array[UInt8, 4]
#       def is_unspecified / is_loopback / is_private / is_link_local /
#           is_multicast / is_broadcast(self) -> Bool
#       def next / prev(self) -> Optional[Ipv4Address]
#       def __eq__(self, other: Self) -> Bool
#       def compare(self, other: Self) -> Int
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   A copyable 32-bit address value. Construct from four octets, a UInt32, or a
#   four-byte slice; read it back as a UInt32 or four octets. The predicates
#   classify it, and next/prev step by one (None at 255.255.255.255 / 0.0.0.0).
#   There is no DNS and no port here.
# Returns:
#   A value type, owned by the caller. `octets()` returns a fresh Array.
# Errors:
#   Only from_bytes, which raises IpParseError when the slice is not exactly four
#   bytes. Integer and octet construction are total.
# Example:
#   var a = Ipv4Address.from_octets(192, 168, 1, 1)
#   a.is_private()                 # -> True
#   a.to_u32()                     # -> 0xC0A80101
#   print(a)                       # -> 192.168.1.1
# API-DOCS-END
