from .version_error import VersionError
from .version_error_kind import VersionErrorKind
from akku.build_versioning._internal.version_core import (
    compare_precedence as _compare_precedence,
    validate_qualifier as _validate_qualifier,
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
        if major < 0 or minor < 0 or patch < 0:
            raise VersionError(
                VersionErrorKind.BAD_NUMBER,
                "SemVer",
                "numeric components must be non-negative",
            )
        if prerelease.byte_length() > 0:
            var pre = _validate_qualifier(StringSpan(prerelease), False)
            if pre == -1:
                raise VersionError(
                    VersionErrorKind.INVALID_FORMAT,
                    "SemVer",
                    "invalid prerelease identifier list",
                )
            if pre == -2:
                raise VersionError(
                    VersionErrorKind.LEADING_ZERO,
                    "SemVer",
                    "numeric prerelease identifier has a leading zero",
                )
        if build.byte_length() > 0:
            var bld = _validate_qualifier(StringSpan(build), True)
            if bld == -1:
                raise VersionError(
                    VersionErrorKind.INVALID_FORMAT,
                    "SemVer",
                    "invalid build identifier list",
                )
        self._major = major
        self._minor = minor
        self._patch = patch
        self._prerelease = prerelease
        self._build = build

    def major(self) -> Int:
        return self._major

    def minor(self) -> Int:
        return self._minor

    def patch(self) -> Int:
        return self._patch

    def prerelease(self) -> StringSpan[origin_of(self._prerelease)]:
        return StringSpan(self._prerelease)

    def build(self) -> StringSpan[origin_of(self._build)]:
        return StringSpan(self._build)

    def __eq__(self, other: Self) -> Bool:
        return (
            _compare_precedence(
                self._major,
                self._minor,
                self._patch,
                StringSpan(self._prerelease),
                other._major,
                other._minor,
                other._patch,
                StringSpan(other._prerelease),
            )
            == 0
        )

    def __ne__(self, other: Self) -> Bool:
        return not (self == other)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self._major, ".", self._minor, ".", self._patch)
        if self._prerelease.byte_length() > 0:
            writer.write("-", self._prerelease)
        if self._build.byte_length() > 0:
            writer.write("+", self._build)

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
#       def prerelease(self) -> StringSpan[origin_of(self._prerelease)]
#       def build(self) -> StringSpan[origin_of(self._build)]
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
