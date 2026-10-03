from std.os import abort

from .semver import SemVer
from .version_error import VersionError


# parse — strict SemVer 2.0.0 parser.
def parse(text: StringSpan) raises VersionError -> SemVer:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# parse — parse a strict Semantic Versioning 2.0.0 string into a SemVer.
# Signature:
#   def parse(text: StringSpan) raises VersionError -> SemVer
# What it does:
#   Parses `text` against exactly the semver.org 2.0.0 grammar and returns the
#   value. The accepted form is MAJOR.MINOR.PATCH with an optional "-prerelease"
#   and an optional "+build". It is strict: no leading or trailing whitespace, no
#   leading "v" or "=", no partial versions (1 and 1.2 are rejected), no leading
#   zeros in the core or in numeric prerelease identifiers, and no empty
#   prerelease/build identifiers. All three core components are mandatory.
#   Numeric identifiers are compared and stored as numbers; prerelease and build
#   stay text. A component that does not fit Int is OVERFLOW. Build metadata is
#   preserved for round-tripping but never affects precedence.
#   `text` is borrowed and may be dropped after the call; the result owns its
#   qualifier strings.
# Returns:
#   A fully validated SemVer owned by the caller.
# Errors:
#   raises VersionError with kind:
#     EMPTY          — text is empty.
#     INVALID_FORMAT — a structural violation (partial version, extra separator,
#                      empty identifier, "v"/"=" prefix, whitespace).
#     BAD_NUMBER     — a numeric identifier contains a non-digit.
#     LEADING_ZERO   — an all-digit identifier has a leading zero.
#     OVERFLOW       — a numeric component does not fit Int.
#   All are recoverable data errors; a caller that only needs "is it a version?"
#   can use try_parse instead.
# Example:
#   var v = parse("1.2.3")
#   print(v)                                # -> 1.2.3
#   print(parse("1.2.3-alpha.1+build.5"))   # -> 1.2.3-alpha.1+build.5
#   _ = parse("v1.2.3")                     # raises INVALID_FORMAT
#   _ = parse("1.2")                        # raises INVALID_FORMAT
# API-DOCS-END
