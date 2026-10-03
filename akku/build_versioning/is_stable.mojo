from std.os import abort

from .semver import SemVer


# is_stable — is the version stable by the documented convention?
def is_stable(v: SemVer) -> Bool:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# is_stable — is the version stable by the documented convention?
# Signature:
#   def is_stable(v: SemVer) -> Bool
# What it does:
#   Returns True when the version has major greater than 0 and no prerelease.
#   This is a documented convention, not a semver.org rule: the specification
#   defines precedence, not stability. A 0.x.y release and any prerelease are not
#   stable. is_stable(v) implies not is_prerelease(v) and v.major() > 0. It
#   borrows `v`, allocates nothing and cannot fail.
# Returns:
#   True when the version is stable, otherwise False.
# Errors:
#   none — total.
# Example:
#   print(is_stable(parse("1.0.0")))       # -> True
#   print(is_stable(parse("0.1.0")))       # -> False (pre-1.0 convention)
#   print(is_stable(parse("1.0.0-rc.1")))  # -> False (a prerelease)
# API-DOCS-END
