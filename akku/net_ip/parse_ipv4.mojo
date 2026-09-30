from .ipv4_address import Ipv4Address
from .ip_parse_error import IpParseError

from akku.net_ip._internal.ip_core import parse_ipv4 as _parse_ipv4


# parse_ipv4 — parse dotted-quad IPv4 text into an Ipv4Address.
def parse_ipv4(text: StringSpan) raises IpParseError -> Ipv4Address:
    return Ipv4Address(_parse_ipv4(text.as_bytes()))

# API-DOCS-START
# parse_ipv4 — parse IPv4 dotted-quad text (explicit family).
# Signature:
#   def parse_ipv4(text: StringSpan) raises IpParseError -> Ipv4Address
# What it does:
#   Parses a dotted-quad IPv4 literal. Use it when the family is already known
#   and an IPv6-looking input should be rejected rather than parsed.
# Returns:
#   The parsed Ipv4Address, owned by the caller.
# Errors:
#   raises IpParseError with a kind and byte position.
# Example:
#   parse_ipv4("192.168.1.1")   # -> 192.168.1.1
#   parse_ipv4("1.2.3")         # -> raises TOO_FEW_GROUPS
# API-DOCS-END
