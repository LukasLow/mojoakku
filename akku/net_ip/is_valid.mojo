from .parse import parse


# is_valid — validity predicate returning Bool; never raises.
def is_valid(text: StringSpan) -> Bool:
    try:
        _ = parse(text)
        return True
    except e:
        return False

# API-DOCS-START
# is_valid — validity predicate returning Bool.
# Signature:
#   def is_valid(text: StringSpan) -> Bool
# What it does:
#   Checks whether `text` is a valid numeric address literal, using exactly the
#   same rules as parse. Never raises.
# Returns:
#   True iff parse(text) would succeed. A scalar Bool; no result string is
#   allocated (parsing may allocate small temporaries, so this is not
#   allocation-free).
# Errors:
#   none — it never raises; every malformed condition is reported as False.
# Example:
#   is_valid("192.168.1.1")     # -> True
#   is_valid("256.1.1.1")       # -> False
#   is_valid("2001:db8::1")     # -> True
# API-DOCS-END
