from .ipv6_address import Ipv6Address
from .ip_parse_error import IpParseError

from akku.net_ip._internal.ip_core import parse_ipv6 as _parse_ipv6


# parse_ipv6 — parse IPv6 text (with '::' compression) into an Ipv6Address.
def parse_ipv6(text: StringSpan) raises IpParseError -> Ipv6Address:
    return Ipv6Address(_parse_ipv6(text.as_bytes()))

# API-DOCS-START
# parse_ipv6 — parse IPv6 text (explicit family).
# Signature:
#   def parse_ipv6(text: StringSpan) raises IpParseError -> Ipv6Address
# What it does:
#   Parses an IPv6 literal, including '::' compression and an embedded dotted-quad
#   tail (for IPv4-mapped/compatible forms). Use it when the family is already
#   known and an IPv4-looking input should be rejected.
# Returns:
#   The parsed Ipv6Address, owned by the caller.
# Errors:
#   raises IpParseError with a kind and byte position.
# Example:
#   parse_ipv6("2001:db8::1")           # -> 2001:db8::1
#   parse_ipv6("::ffff:10.0.0.1")       # -> ::ffff:10.0.0.1
#   parse_ipv6("1::2::3")               # -> raises BAD_IPV6_COMPRESSION
# API-DOCS-END
