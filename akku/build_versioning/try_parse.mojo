from std.os import abort

from .semver import SemVer
from .parse import parse


# try_parse — non-raising strict SemVer 2.0.0 parser.
def try_parse(text: StringSpan) -> Optional[SemVer]:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# try_parse — parse a strict SemVer 2.0.0 string, or None.
# Signature:
#   def try_parse(text: StringSpan) -> Optional[SemVer]
# What it does:
#   The non-raising twin of parse: it accepts exactly the same strict
#   semver.org 2.0.0 grammar and returns the value when `text` is valid, or None
#   otherwise. It never raises and never aborts — the absence of a parse result
#   is a value, not a sentinel. It is parse wrapped in a try/except that maps any
#   VersionError to None, so the error's kind and detail are discarded; call
#   parse when you need the reason.
#   `text` is borrowed and may be dropped after the call.
# Returns:
#   Some(SemVer) when `text` is a valid strict version, otherwise None. The
#   returned SemVer is owned by the caller.
# Errors:
#   none — absence is None.
# Example:
#   print(try_parse("1.2.3"))       # -> 1.2.3
#   print(try_parse("not-a-version"))   # -> None
#   print(try_parse(""))                # -> None
# API-DOCS-END
