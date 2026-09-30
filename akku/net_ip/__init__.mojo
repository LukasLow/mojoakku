from .address_family import AddressFamily
from .ip_parse_error_kind import IpParseErrorKind
from .ip_parse_error import IpParseError
from .ipv4_address import Ipv4Address
from .ipv6_address import Ipv6Address
from .ip_address import IpAddress
from .parse import parse
from .parse_ipv4 import parse_ipv4
from .parse_ipv6 import parse_ipv6
from .try_parse import try_parse
from .is_valid import is_valid
from .format import format

# API-DOCS-START
# Purpose   — akku/net_ip is IPv4 and IPv6 addresses as value types. It parses
#   numeric address text, formats addresses back to text, classifies them
#   (loopback, private, link-local, multicast, unspecified, broadcast, mapped)
#   and converts between the text, byte and integer representations. It is a
#   pure, in-process value library: no files, sockets, DNS, threads or global
#   state.
# Overview  — One family-tagged type, IpAddress, unifies two concrete value
#   structs, Ipv4Address (a UInt32) and Ipv6Address (a UInt128). All three are
#   copyable values with structural equality and a total order (IPv4 before
#   IPv6). Parsing is strict and numeric-only (never DNS) and reports failures as
#   one typed error, IpParseError, carrying a kind and the byte position; the
#   non-throwing pair try_parse/is_valid covers expected-invalid input.
#   Formatting emits dotted-quad for IPv4 and the RFC 5952 canonical form for
#   IPv6. IPv4-mapped IPv6 addresses are handled explicitly (is_ipv4_mapped,
#   to_ipv4_mapped, unmap) and never converted implicitly.
# Dependencies — none. net_ip is a leaf: it depends only on the Mojo standard
#   library (UInt8/UInt16/UInt32/UInt128, Array, List, Span, StringSpan, String,
#   Optional, Bool) and needs no FFI and no socket.
# Public API — the ordered index (each entry is specified in its own file):
#    1. AddressFamily    — family tag: IPV4, IPV6.
#    2. IpParseErrorKind — parse failure reason (nine members).
#    3. IpParseError     — the one typed error: kind: IpParseErrorKind,
#                          position: Int.
#    4. Ipv4Address      — IPv4 address value (UInt32).
#    5. Ipv6Address      — IPv6 address value (UInt128).
#    6. IpAddress        — family-tagged address unifying both.
#    7. parse            — text -> IpAddress, raising IpParseError.
#    8. parse_ipv4       — text -> Ipv4Address, raising IpParseError.
#    9. parse_ipv6       — text -> Ipv6Address, raising IpParseError.
#   10. try_parse        — text -> Optional[IpAddress]; never raises.
#   11. is_valid         — text -> Bool; never raises.
#   12. format           — IpAddress -> String (IPv6 in RFC 5952 form).
# Error Surface — exactly one error type, IpParseError, carrying
#   kind: IpParseErrorKind and position: Int (a zero-based byte index). Every
#   kind is a recoverable data error. Which API can raise what:
#     parse       — EMPTY_INPUT, INVALID_CHARACTER, OCTET_OUT_OF_RANGE,
#                   SEGMENT_OUT_OF_RANGE, TOO_FEW_GROUPS, TOO_MANY_GROUPS,
#                   BAD_GROUP_SEPARATOR, BAD_IPV6_COMPRESSION,
#                   ZONE_NOT_SUPPORTED
#     parse_ipv4  — the IPv4 subset of the above
#     parse_ipv6  — the IPv6 subset of the above
#     Ipv4Address.from_bytes / Ipv6Address.from_bytes — TOO_FEW_GROUPS /
#                   TOO_MANY_GROUPS for a wrong-length slice
#     try_parse, is_valid, format, all predicates — never raise
#   A family mismatch (to_ipv4 on an IPv6 value) and an end-of-range step are
#   reported as Optional, never as an error. `print(err)` gives a readable kind
#   + position message.
# Conventions — names are stable; parsing is numeric-only and never resolves a
#   hostname; a zone ('%') suffix is rejected for now; IPv6 text output follows
#   RFC 5952; `position` is a byte index, not a character index.
# API-DOCS-END
