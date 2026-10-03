from std.os import abort

from .semver import SemVer


# is_prerelease — does the version carry a prerelease?
def is_prerelease(v: SemVer) -> Bool:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# is_prerelease — does the version carry a prerelease?
# Signature:
#   def is_prerelease(v: SemVer) -> Bool
# What it does:
#   Returns True when `v` has a non-empty prerelease, i.e. it was written with a
#   "-prerelease" suffix. It never inspects build metadata. This is exactly the
#   clause-11 condition that makes `v` compare lower than the same core without a
#   prerelease, offered as a named predicate so you do not have to test the
#   prerelease string yourself. It borrows `v`, allocates nothing and cannot
#   fail.
# Returns:
#   True when the version is a prerelease, otherwise False.
# Errors:
#   none — total.
# Example:
#   print(is_prerelease(parse("1.2.3-alpha")))   # -> True
#   print(is_prerelease(parse("1.2.3")))         # -> False
#   print(is_prerelease(parse("1.2.3+build")))   # -> False
# API-DOCS-END
