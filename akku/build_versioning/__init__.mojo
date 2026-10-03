# MojoAkku build_versioning — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from akku.build_versioning import ...` works. Nothing else lives here: the
# public surface is defined by the per-entry files and this file only forwards
# names.

from .semver import SemVer
from .version_error_kind import VersionErrorKind
from .version_error import VersionError
from .parse import parse
from .try_parse import try_parse
from .precedence import precedence
from .is_prerelease import is_prerelease
from .is_stable import is_stable

# API-DOCS-START
# Purpose   — akku/build_versioning is the MojoAkku Semantic Versioning 2.0.0
#   library: it parses a strict SemVer 2.0.0 string into a value and orders two
#   version values by the specification's precedence rules. Release 1 is the
#   core only — parse, compare and two kind predicates. Constraint ranges (caret,
#   tilde, hyphen, X-ranges, npm/Go/Cargo dialects, Maven brackets, PEP 440
#   specifiers) are deliberately out of scope and live in _dev/TODO.md. It is
#   built for a low-vision user: one value type, one typed error with a closed
#   kind, one precedence function returning -1/0/+1, explicit strictness (no
#   hidden "v"-stripping and no silent normalization), value semantics
#   throughout, and no magic sentinels.
# Overview  — one value type and one comparator, over a private shared core.
#     1. SemVer — the parsed version value: private major/minor/patch (Int) plus
#        owned prerelease and build Strings, read through accessor methods.
#        Constructed only by its validating component constructor or by parse,
#        so an existing SemVer is always well-formed.
#     2. VersionErrorKind — the closed failure discriminant: EMPTY,
#        INVALID_FORMAT, BAD_NUMBER, LEADING_ZERO, OVERFLOW, OTHER.
#     3. VersionError — the one typed error: kind, op and detail.
#     4. parse — the strict SemVer 2.0.0 parser, raising VersionError.
#     5. try_parse — its non-raising twin, returning Optional[SemVer].
#     6. precedence — SemVer clause 11 ordering as -1/0/+1; build metadata is
#        ignored.
#     7. is_prerelease / is_stable — two boolean questions about a value.
#   Cross-cutting: one typed error with a closed kind; strict input (no "v" or
#   "=" prefix, no whitespace, no partial versions, no leading zeros); equality
#   equals precedence, so build metadata never affects equality; value semantics
#   and no hidden global state.
# Dependencies — text_string only. The parser must split a version string once
#   on "+", once on "-" and twice on ".", treating absence as a value.
#   akku/text_string.split_once returns Optional[(before, after)] views with zero
#   allocation; the Mojo standard library offers only find/rfind (returning the
#   -1 sentinel) and split (all occurrences, allocating), and has no
#   split_once/partition. build_versioning points to text_string; text_string
#   never points back. This is a conceptual edge, never a nested directory.
#   Internally, _internal/version_core.mojo holds the shared clause-11
#   comparison and identifier validation so semver.mojo and precedence.mojo do
#   not import each other; it is private and not a dependency edge.
# Public API — the ordered index (each entry is specified in its own file):
#    1. SemVer           — the parsed version value with accessors.
#    2. VersionErrorKind — closed discriminant: EMPTY, INVALID_FORMAT,
#                          BAD_NUMBER, LEADING_ZERO, OVERFLOW, OTHER.
#    3. VersionError     — the one typed error: kind, op, detail.
#    4. parse            — strict SemVer 2.0.0 parser; raises VersionError.
#    5. try_parse        — non-raising parser; returns Optional[SemVer].
#    6. precedence       — clause 11 ordering: -1, 0 or +1 (build ignored).
#    7. is_prerelease    — does the version carry a prerelease?
#    8. is_stable        — major > 0 and no prerelease (documented convention).
# Error Surface — exactly one error type, VersionError, with a closed
#   VersionErrorKind. Which API raises what:
#     SemVer (component constructor) — VersionError: BAD_NUMBER,
#                                      INVALID_FORMAT, LEADING_ZERO
#     VersionErrorKind / VersionError — none
#     parse                          — VersionError: EMPTY, INVALID_FORMAT,
#                                      BAD_NUMBER, LEADING_ZERO, OVERFLOW
#     try_parse                      — none (absence is Optional)
#     precedence / is_prerelease / is_stable — none
#   Every VersionError is a recoverable data error: the caller passed a malformed
#   string or component. No operation is fatal and none aborts. OTHER is reserved
#   and carries its context in the opaque detail string; no release-1 operation
#   raises it. Callers branch on kind, never on the opaque detail string.
# Conventions — strict input: exactly the semver.org BNF, with no leading or
#   trailing whitespace, no "v"/"=" prefix, no partial versions, no leading
#   zeros and no empty identifiers. A version's prerelease and build are owned
#   Strings that are empty when absent — never Optional, never a sentinel. One
#   comparison: precedence returns an Int in {-1, 0, +1} and ignores build
#   metadata (clause 10). Equality is precedence equality, so SemVer.__eq__ is
#   true iff precedence == 0 and two versions differing only in build metadata
#   are equal. Components are Int with explicit OVERFLOW rejection. Names are
#   snake_case for functions and methods, CamelCase for types and
#   SCREAMING_CASE for comptime constants. There is no hidden global state.
# API-DOCS-END
