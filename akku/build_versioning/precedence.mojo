from std.os import abort

from .semver import SemVer
from akku.build_versioning._internal.version_core import (
    compare_precedence as _compare_precedence,
)


# precedence — SemVer clause 11 ordering of two versions, as -1 / 0 / +1.
def precedence(a: SemVer, b: SemVer) -> Int:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# precedence — SemVer clause 11 ordering of two versions, as -1 / 0 / +1.
# Signature:
#   def precedence(a: SemVer, b: SemVer) -> Int
# What it does:
#   Orders two valid versions by the Semantic Versioning 2.0.0 precedence rules
#   (clause 11) and returns -1 when `a` has lower precedence, 0 when they are
#   equal, +1 when `a` has higher precedence. The algorithm is:
#     1. compare major, then minor, then patch numerically;
#     2. a version with a prerelease is lower than the same core without one
#        (1.2.3-alpha < 1.2.3);
#     3. when both have a prerelease, compare their dot-separated identifiers
#        left to right: numeric identifiers numerically, alphanumeric identifiers
#        in ASCII order, a numeric identifier always below an alphanumeric one,
#        and if all are equal the set with fewer identifiers is lower
#        (alpha < alpha.1).
#   Build metadata is ignored entirely (clause 10): 1.2.3+a, 1.2.3+b and 1.2.3
#   all compare equal. The function is total and never fails. It is the same
#   comparison that SemVer equality uses, so the two always agree. It cannot
#   fail, so it does not raise; to sort, map it to a key.
# Returns:
#   -1, 0 or +1, owned by the caller.
# Errors:
#   none — total for every pair of valid versions.
# Example:
#   print(precedence(parse("1.0.0"), parse("2.0.0")))          # -> -1
#   print(precedence(parse("1.0.0"), parse("1.0.0")))          # -> 0
#   print(precedence(parse("1.0.0-alpha"), parse("1.0.0")))    # -> -1
#   print(precedence(parse("1.2.3+a"), parse("1.2.3+b")))      # -> 0
# API-DOCS-END
