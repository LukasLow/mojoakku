# Concern: `Whitespace` — the compile-time decode whitespace policy REJECT vs
# IGNORE (docs block in `../whitespace.mojo`).
#
# Covers: REJECT makes any whitespace byte an INVALID_SYMBOL; IGNORE skips
# space, tab, CR, LF, FF and VT, and skipped whitespace still advances the
# original-stream index used for `position`. Whitespace tolerance is explicit
# and opt-in, never silently applied (a difference from Go base32 and Bouncy
# Castle, which ignore whitespace with no strict switch).

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    Alphabet,
    PaddingMode,
    Whitespace,
    ErrorKind,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_reject_is_the_default() raises:
    assert_equal(decode("MZXW6==="), bytes_of("foo"))
    var caught = False
    try:
        _ = decode("MZ XW6===")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 2)
    assert_true(caught)

def test_reject_each_whitespace_byte() raises:
    # space, tab, CR, LF, FF, VT are all rejected by default.
    var space_caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.REJECT](
            "MZ XW6==="
        )
    except e:
        space_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(space_caught)

    var tab_caught = False
    try:
        _ = decode("MZ\tXW6===")
    except e:
        tab_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(tab_caught)

    var cr_caught = False
    try:
        _ = decode("MZ\rXW6===")
    except e:
        cr_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(cr_caught)

    var lf_caught = False
    try:
        _ = decode("MZ\nXW6===")
    except e:
        lf_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(lf_caught)

    var ff_caught = False
    try:
        _ = decode("MZ\fXW6===")
    except e:
        ff_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(ff_caught)

    var vt_caught = False
    try:
        _ = decode("MZ\vXW6===")
    except e:
        vt_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(vt_caught)

def test_ignore_skips_whitespace_between_symbols() raises:
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "MZ XW6==="
        ),
        bytes_of("foo"),
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "M Z X W 6 Y T B"
        ),
        bytes_of("fooba"),
    )

def test_ignore_skips_whitespace_around_padding() raises:
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "MY = = = = = ="
        ),
        bytes_of("f"),
    )

def test_ignore_still_rejects_real_invalid_symbols() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "MZ!XW6==="
        )
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        # The '!' is at index 2 of the original stream.
        assert_equal(e.position, 2)
    assert_true(caught)

def test_ignore_position_still_counts_skipped_whitespace() raises:
    # Whitespace occupies a position in the original stream, so the offending
    # symbol's reported position is its original-stream index, not the
    # whitespace-stripped index.
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "M Z ! X W 6"
        )
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 4)
    assert_true(caught)

def test_ignore_allows_empty_after_whitespace() raises:
    # An input that is only whitespace becomes an empty symbol stream.
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]("  \n"),
        bytes_of(""),
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
