from .ip_parse_error import IpParseError
from .ip_parse_error_kind import IpParseErrorKind
from .ipv4_address import Ipv4Address

from akku.net_ip._internal.ip_core import (
    u128_group,
    format_ipv6,
    v6_is_unspecified,
    v6_is_loopback,
    v6_is_private,
    v6_is_link_local,
    v6_is_multicast,
    v6_is_ipv4_mapped,
    v6_is_ipv4_compatible,
)


# Ipv6Address — an IPv6 address value.
struct Ipv6Address(Copyable, Movable, Deinitable, Equatable, Writable):
    var _b: UInt128

    @doc_hidden
    def __init__(out self, b: UInt128):
        self._b = b

    @staticmethod
    def from_segments(
        s0: UInt16, s1: UInt16, s2: UInt16, s3: UInt16,
        s4: UInt16, s5: UInt16, s6: UInt16, s7: UInt16,
    ) -> Self:
        var v: UInt128 = 0
        v = (v << 16) | UInt128(s0)
        v = (v << 16) | UInt128(s1)
        v = (v << 16) | UInt128(s2)
        v = (v << 16) | UInt128(s3)
        v = (v << 16) | UInt128(s4)
        v = (v << 16) | UInt128(s5)
        v = (v << 16) | UInt128(s6)
        v = (v << 16) | UInt128(s7)
        return Self(v)

    @staticmethod
    def from_u128(value: UInt128) -> Self:
        return Self(value)

    @staticmethod
    def from_bytes(bytes: Span[UInt8, _]) raises IpParseError -> Self:
        if len(bytes) != 16:
            if len(bytes) < 16:
                raise IpParseError(IpParseErrorKind.TOO_FEW_GROUPS, len(bytes))
            raise IpParseError(IpParseErrorKind.TOO_MANY_GROUPS, 16)
        var v: UInt128 = 0
        for i in range(16):
            v = (v << 8) | UInt128(bytes[i])
        return Self(v)

    def to_u128(self) -> UInt128:
        return self._b

    def octets(self) -> Array[UInt8, 16]:
        var out = Array[UInt8, 16](fill=0)
        for i in range(16):
            out[i] = UInt8((self._b >> UInt128(120 - 8 * i)) & UInt128(0xFF))
        return out^

    def segments(self) -> Array[UInt16, 8]:
        var out = Array[UInt16, 8](fill=0)
        for i in range(8):
            out[i] = u128_group(self._b, i)
        return out^

    def is_unspecified(self) -> Bool:
        return v6_is_unspecified(self._b)

    def is_loopback(self) -> Bool:
        return v6_is_loopback(self._b)

    def is_private(self) -> Bool:
        return v6_is_private(self._b)

    def is_link_local(self) -> Bool:
        return v6_is_link_local(self._b)

    def is_multicast(self) -> Bool:
        return v6_is_multicast(self._b)

    def is_ipv4_mapped(self) -> Bool:
        return v6_is_ipv4_mapped(self._b)

    def to_ipv4_mapped(self) -> Optional[Ipv4Address]:
        if v6_is_ipv4_mapped(self._b):
            var out = Ipv4Address(UInt32(self._b & UInt128(0xFFFFFFFF)))
            return out^
        return None

    def to_ipv4(self) -> Optional[Ipv4Address]:
        # The mapped form, or the deprecated IPv4-compatible form.
        if v6_is_ipv4_mapped(self._b) or v6_is_ipv4_compatible(self._b):
            var out = Ipv4Address(UInt32(self._b & UInt128(0xFFFFFFFF)))
            return out^
        return None

    def next(self) -> Optional[Ipv6Address]:
        if self._b == UInt128(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF):
            return None
        var out = Ipv6Address(self._b + 1)
        return out^

    def prev(self) -> Optional[Ipv6Address]:
        if self._b == UInt128(0):
            return None
        var out = Ipv6Address(self._b - 1)
        return out^

    def __eq__(self, other: Self) -> Bool:
        return self._b == other._b

    def compare(self, other: Self) -> Int:
        if self._b < other._b:
            return -1
        if self._b > other._b:
            return 1
        return 0

    def write_to(self, mut writer: Some[Writer]):
        writer.write(format_ipv6(self._b))

# API-DOCS-START
# Ipv6Address — an IPv6 address value.
# Signature:
#   struct Ipv6Address(Copyable, Movable, Deinitable, Equatable, Writable):
#       var _b: UInt128
#       @staticmethod def from_segments(s0..s7: UInt16) -> Self
#       @staticmethod def from_u128(value: UInt128) -> Self
#       @staticmethod def from_bytes(bytes: Span[UInt8]) raises IpParseError -> Self
#       def to_u128(self) -> UInt128
#       def octets(self) -> Array[UInt8, 16]
#       def segments(self) -> Array[UInt16, 8]
#       def is_unspecified / is_loopback / is_private / is_link_local /
#           is_multicast / is_ipv4_mapped(self) -> Bool
#       def to_ipv4_mapped / to_ipv4(self) -> Optional[Ipv4Address]
#       def next / prev(self) -> Optional[Ipv6Address]
#       def __eq__(self, other: Self) -> Bool
#       def compare(self, other: Self) -> Int
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   A copyable 128-bit address value. Construct from eight 16-bit segments, a
#   UInt128, or a sixteen-byte slice; read it back as a UInt128, sixteen octets
#   or eight segments. The predicates classify it. The mapped operations are
#   explicit: to_ipv4_mapped returns Some only for an IPv4-mapped address,
#   to_ipv4 also accepts the deprecated IPv4-compatible form.
# Returns:
#   A value type, owned by the caller. `octets()`/`segments()` return fresh arrays.
# Errors:
#   Only from_bytes, which raises IpParseError when the slice is not exactly
#   sixteen bytes. Integer and segment construction are total.
# Example:
#   var a = Ipv6Address.from_u128(1)
#   a.is_loopback()                # -> True
#   print(a)                       # -> ::1
#   Ipv6Address.from_segments(0,0,0,0,0,0xffff,0x7f00,1).to_ipv4_mapped()
#                                  # -> Some(127.0.0.1)
# API-DOCS-END
