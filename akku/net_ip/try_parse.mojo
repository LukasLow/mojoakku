from .ip_address import IpAddress
from .parse import parse
from .ip_parse_error import IpParseError


# try_parse — non-throwing parse: Some(address) or None.
def try_parse(text: StringSpan) -> Optional[IpAddress]:
    try:
        var address = parse(text)
        return address^
    except e:
        return None

# API-DOCS-START
# try_parse — non-throwing parse returning Optional.
# Signature:
#   def try_parse(text: StringSpan) -> Optional[IpAddress]
# What it does:
#   The non-throwing counterpart of parse. Returns Some(address) when the text
#   is a valid numeric literal, None otherwise. Use it when a malformed address
#   is expected input rather than an exceptional case.
# Returns:
#   Some(IpAddress), or None when parsing fails. Allocates only for the returned
#   value.
# Errors:
#   none — every failure is reported as None.
# Example:
#   try_parse("10.0.0.1")       # -> Some(10.0.0.1)
#   try_parse("10.0.0")         # -> None
# API-DOCS-END
