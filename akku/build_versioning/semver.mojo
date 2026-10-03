from std.os import abort

from .version_error import VersionError
from akku.build_versioning._internal.version_core import (
    compare_precedence as _compare_precedence,
)


# SemVer — a parsed Semantic Versioning 2.0.0 value.
struct SemVer(Equatable, Copyable, Deinitable, Writable):
    var _major: Int
    var _minor: Int
    var _patch: Int
    var _prerelease: String
    var _build: String

    @doc_hidden
    def __init__(
        out self,
        major: Int,
        minor: Int,
        patch: Int,
        prerelease: String = "",
        build: String = "",
    ) raises VersionError:
        abort("MojoAkku: this API is not yet implemented")

    def major(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def minor(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def patch(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def prerelease[o: Origin[mut=False]](self) -> StringSpan[o]:
        abort("MojoAkku: this API is not yet implemented")

    def build[o: Origin[mut=False]](self) -> StringSpan[o]:
        abort("MojoAkku: this API is not yet implemented")

    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def __ne__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# SemVer — a parsed Semantic Versioning 2.0.0 value.
# Signature:
#   struct SemVer(Equatable, Copyable, Deinitable, Writable):
#       var _major: Int
#       var _minor: Int
#       var _patch: Int
#       var _prerelease: String
#       var _build: String
#       @doc_hidden
#       def __init__(
#           out self, major: Int, minor: Int, patch: Int,
#           prerelease: String = "", build: String = "",
#       ) raises VersionError
#       def major(self) -> Int
#       def minor(self) -> Int
#       def patch(self) -> Int
#       def prerelease[o: Origin[mut=False]](self) -> StringSpan[o]
#       def build[o: Origin[mut=False]](self) -> StringSpan[o]
#       def __eq__(self, other: Self) -> Bool
#       def __ne__(self, other: Self) -> Bool
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   A Semantic Versioning 2.0.0 value: three numeric components plus an optional
#   prerelease and build metadata. The fields are private; read them through
#   major(), minor(), patch() and the prerelease()/build() views. Build and
#   prerelease are empty when absent — there is no Optional field and no
#   sentinel. A SemVer is constructed only through the validating component
#   constructor here or through parse(), so every value that exists is
#   well-formed:
#     - components must be >= 0 (else BAD_NUMBER),
#     - prerelease/build strings must match the SemVer identifier grammar
#       (else INVALID_FORMAT or LEADING_ZERO).
#   The constructor is the parser-free path, for when the components are already
#   known; parse() is the strict string path. Equality follows SemVer precedence:
#   two versions that differ only in build metadata are equal (clause 10).
#   print(v) renders the strict form "MAJOR.MINOR.PATCH[-pre][+build]".
# Returns:
#   A value type, owned by the caller. It owns its two qualifier Strings and can
#   outlive the string it was parsed from. prerelease()/build() return borrowed
#   views into the value and stay valid as long as the value does.
# Errors:
#   The constructor raises VersionError: BAD_NUMBER (negative component),
#   INVALID_FORMAT (bad qualifier), LEADING_ZERO (numeric identifier with a
#   leading zero). All are recoverable.
# Example:
#   var v = SemVer(1, 2, 3)
#   print(v.major(), ".", v.minor(), ".", v.patch())   # -> 1 . 2 . 3
#   print(v)                                           # -> 1.2.3
#   var r = SemVer(1, 2, 3, "alpha.1", "build.5")
#   print(r.prerelease())                              # -> alpha.1
#   print(SemVer(1, 2, 3, "01"))                       # raises LEADING_ZERO
# API-DOCS-END
