from .semver import SemVer
from .version_error import VersionError
from .version_error_kind import VersionErrorKind
from akku.text_string import split_once
from akku.build_versioning._internal.version_core import (
    identifier_class as _identifier_class,
    has_leading_zero as _has_leading_zero,
    parse_digits as _parse_digits,
    validate_qualifier as _validate_qualifier,
)


# _fail — raise the one typed error with a consistent op and a detail string.
def _fail(kind: VersionErrorKind, detail: String) raises VersionError -> Never:
    raise VersionError(kind, "parse", detail)


# _parse_core_number — parse one core component. A component that contains a
# character outside [0-9A-Za-z-] (a space, '=', ...) is a structural error; a
# component of allowed characters that is not all digits (e.g. "x") is a number
# error. A leading zero and an Int overflow get their own kinds.
def _parse_core_number(text: StringSpan) raises VersionError -> Int:
    var cls = _identifier_class(text)
    if cls == 0:
        _fail(VersionErrorKind.INVALID_FORMAT, "core component has a disallowed character")
    if cls == 2:
        _fail(VersionErrorKind.BAD_NUMBER, "core component is not all digits")
    if _has_leading_zero(text):
        _fail(VersionErrorKind.LEADING_ZERO, "core component has a leading zero")
    var value = _parse_digits(text)
    if value < 0:
        _fail(VersionErrorKind.OVERFLOW, "core component does not fit Int")
    return value


# parse — strict SemVer 2.0.0 parser.
def parse(text: StringSpan) raises VersionError -> SemVer:
    if text.byte_length() == 0:
        _fail(VersionErrorKind.EMPTY, "input is empty")

    # A leading "v" or "=" is never part of a semantic version (semver.org:
    # "v1.2.3" is not a semantic version). Reject it structurally.
    var first = text.as_bytes()[0]
    if first == UInt8(118) or first == UInt8(61):  # 'v' or '='
        _fail(VersionErrorKind.INVALID_FORMAT, "a version may not start with 'v' or '='")

    # Split off build metadata at the first '+'. Split once and copy the halves
    # into owned Strings, so later splits do not fight the view origins; the
    # build remainder is kept whole, so '.' inside it is not split.
    var rest = String(text)
    var build = String()
    var plus = split_once(text, "+")
    if plus:
        rest = String(plus.value()[0])
        build = String(plus.value()[1])
        if build.byte_length() == 0:
            _fail(VersionErrorKind.INVALID_FORMAT, "empty build metadata")
        if split_once(StringSpan(build), "+"):
            _fail(VersionErrorKind.INVALID_FORMAT, "more than one '+' separator")
        # Build identifiers are over [0-9A-Za-z-] (clause 10), so a '-' INSIDE
        # the build is valid; leading zeros are allowed there. Only the empty
        # identifier list and a second '+' are invalid.
        if _validate_qualifier(StringSpan(build), True) != 0:
            _fail(VersionErrorKind.INVALID_FORMAT, "invalid build identifier list")

    # Split off the prerelease at the first '-' after the core. The prerelease is
    # kept whole; its '-'/'.'-separated identifiers are validated separately.
    var core = rest
    var prerelease = String()
    var dash = split_once(StringSpan(rest), "-")
    if dash:
        core = String(dash.value()[0])
        prerelease = String(dash.value()[1])
        if prerelease.byte_length() == 0:
            _fail(VersionErrorKind.INVALID_FORMAT, "empty prerelease")
        var pre = _validate_qualifier(StringSpan(prerelease), False)
        if pre == -1:
            _fail(VersionErrorKind.INVALID_FORMAT, "invalid prerelease identifier list")
        if pre == -2:
            _fail(VersionErrorKind.LEADING_ZERO, "numeric prerelease identifier has a leading zero")

    # The core is exactly three dot-separated numeric identifiers. Count the
    # parts first, then parse each in place (views are used immediately).
    var core_bytes = core.as_bytes()
    var n = len(core_bytes)
    var count = 1
    for i in range(n):
        if core_bytes[i] == UInt8(46):  # '.'
            count += 1
    if count != 3:
        _fail(VersionErrorKind.INVALID_FORMAT, "core must be MAJOR.MINOR.PATCH")

    var start = 0
    var major = 0
    var minor = 0
    var patch = 0
    var part = 0
    for i in range(n + 1):
        if i == n or core_bytes[i] == UInt8(46):
            var value = _parse_core_number(core[byte=start:i])
            if part == 0:
                major = value
            elif part == 1:
                minor = value
            else:
                patch = value
            part += 1
            start = i + 1

    return SemVer(major, minor, patch, prerelease, build)

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
