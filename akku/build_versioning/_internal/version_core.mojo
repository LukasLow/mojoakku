from std.os import abort


from std.os import abort


# version_core — private implementation core for akku/build_versioning.
#
# Pure functions over raw version fields: the SemVer clause-11 precedence
# comparison and the shared identifier validation. Both `semver.mojo` (its
# `__eq__`) and `precedence.mojo` delegate here, so the logic exists once and
# neither public module imports the other. This file imports no public module,
# which is what breaks the would-be cycle. Not public API.


# compare_precedence — SemVer clause 11 ordering over raw fields, -1/0/+1.
def compare_precedence(
    a_major: Int,
    a_minor: Int,
    a_patch: Int,
    a_prerelease: StringSpan,
    b_major: Int,
    b_minor: Int,
    b_patch: Int,
    b_prerelease: StringSpan,
) -> Int:
    abort("MojoAkku: this API is not yet implemented")


# identifier_is_valid — is `text` a valid SemVer identifier (core or qualifier)?
def identifier_is_valid(text: StringSpan, numeric_only: Bool) -> Bool:
    abort("MojoAkku: this API is not yet implemented")
