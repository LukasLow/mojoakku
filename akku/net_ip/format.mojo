from .ip_address import IpAddress
from .ipv4_address import Ipv4Address
from .ipv6_address import Ipv6Address


# format — render an IpAddress as text (IPv6 in RFC 5952 form).
def format(address: IpAddress) -> String:
    if address.is_ipv4():
        return String(Ipv4Address(address._v4))
    return String(Ipv6Address(address._v6))

# API-DOCS-START
# format — render an address as text.
# Signature:
#   def format(address: IpAddress) -> String
# What it does:
#   Returns the textual form of an address. IPv4 uses dotted-quad. IPv6 uses the
#   RFC 5952 canonical form: lowercase hex, no leading zeros, the longest run of
#   two or more zero groups replaced by '::', and an IPv4-mapped address written
#   as '::ffff:a.b.c.d'.
# Returns:
#   A freshly owned String. The caller owns the result.
# Errors:
#   none — formatting any address cannot fail.
# Example:
#   format(parse("2001:0db8:0000:0000:0000:0000:0000:0001"))  # -> "2001:db8::1"
#   format(parse("::ffff:10.0.0.1"))                          # -> "::ffff:10.0.0.1"
# API-DOCS-END
