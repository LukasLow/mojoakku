from .ip_address import IpAddress
from .parse import parse
from .ip_parse_error import IpParseError


# is_valid — allocation-free validity predicate returning Bool.
def is_valid(text: StringSpan) -> Bool:
    try:
        _ = parse(text)
        return True
    except e:
        return False

# API-DOCS-START
# is_valid — allocation-free validity predicate returning Bool.
# Signature:
#   def is_valid(text: StringSpan) -> Bool
# What it does:
#   Checks whether `text` is a valid numeric address literal, using exactly the
#   same rules as parse. Never raises.
# Returns:
#   True iff parse(text) would succeed. A scalar Bool.
# Errors:
#   none — it never raises; every malformed condition is reported as False.
# Example:
#   is_valid("192.168.1.1")     # -> True
#   is_valid("256.1.1.1")       # -> False
#   is_valid("2001:db8::1")     # -> True
# API-DOCS-END
