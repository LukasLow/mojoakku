from .ip_address import IpAddress
from .ip_parse_error import IpParseError
from .ipv4_address import Ipv4Address
from .ipv6_address import Ipv6Address

from akku.net_ip._internal.ip_core import parse_ipv4 as _parse_ipv4
from akku.net_ip._internal.ip_core import parse_ipv6 as _parse_ipv6


# parse — parse IPv4 or IPv6 text into a family-tagged IpAddress.
def parse(text: StringSpan) raises IpParseError -> IpAddress:
    var b = text.as_bytes()
    var is_v6 = False
    for i in range(len(b)):
        if b[i] == UInt8(58):  # ':'
            is_v6 = True
            break
    if is_v6:
        return IpAddress.from_ipv6(Ipv6Address(_parse_ipv6(b)))
    return IpAddress.from_ipv4(Ipv4Address(_parse_ipv4(b)))

# API-DOCS-START
# parse — parse IPv4 or IPv6 text into a family-tagged IpAddress.
# Signature:
#   def parse(text: StringSpan) raises IpParseError -> IpAddress
# What it does:
#   Parses a numeric address literal and returns the family-tagged value.
#   Text containing ':' is parsed as IPv6, otherwise as IPv4. There is no DNS
#   and no hostname resolution: only numeric literals are accepted. A trailing
#   '%zone' scope id is rejected with ZONE_NOT_SUPPORTED. Leading/trailing
#   whitespace is not trimmed.
# Returns:
#   The parsed IpAddress, owned by the caller.
# Errors:
#   raises IpParseError with a kind and the zero-based byte position of the
#   failure. Parsing is all-or-nothing: a failure yields no value.
# Example:
#   parse("192.168.1.1")        # -> 192.168.1.1 (IPv4)
#   parse("2001:db8::1")        # -> 2001:db8::1 (IPv6)
#   parse("::ffff:10.0.0.1")    # -> ::ffff:10.0.0.1 (IPv6, mapped)
# API-DOCS-END
