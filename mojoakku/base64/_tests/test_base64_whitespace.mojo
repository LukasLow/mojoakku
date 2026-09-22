# Concern: `Whitespace` — the compile-time decode whitespace policy REJECT vs
# IGNORE (docs block in `../whitespace.mojo`).
#
# Covers: REJECT makes any whitespace byte an INVALID_SYMBOL; IGNORE skips
# space, tab, CR, LF, FF and VT, and skipped whitespace still advances the
# original-stream index used for `position`. Whitespace tolerance is explicit
# and opt-in, never silently applied.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
    Alphabet,
    PaddingMode,
    Whitespace,
    ErrorKind,
    Base64Error,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_reject_is_the_default() raises:
    assert_equal(decode("Zm9v"), bytes_of("foo"))
    var caught = False
    try:
        _ = decode("Zm 9v")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 2)
    assert_true(caught)

def test_reject_each_whitespace_byte() raises:
    # space, tab, CR, LF, FF, VT are all rejected by default.
    var space_caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.REJECT](
            "Zm 9v"
        )
    except e:
        space_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(space_caught)

    var tab_caught = False
    try:
        _ = decode("Zm\t9v")
    except e:
        tab_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(tab_caught)

    var cr_caught = False
    try:
        _ = decode("Zm\r9v")
    except e:
        cr_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(cr_caught)

    var lf_caught = False
    try:
        _ = decode("Zm\n9v")
    except e:
        lf_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(lf_caught)

    var ff_caught = False
    try:
        _ = decode("Zm\f9v")
    except e:
        ff_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(ff_caught)

    var vt_caught = False
    try:
        _ = decode("Zm\v9v")
    except e:
        vt_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(vt_caught)

def test_ignore_skips_whitespace_between_symbols() raises:
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "Zm 9v"
        ),
        bytes_of("foo"),
    )
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "Zm\n9v"
        ),
        bytes_of("foo"),
    )
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            " Z m 9 v "
        ),
        bytes_of("foo"),
    )

def test_ignore_skips_whitespace_around_padding() raises:
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "Zg = ="
        ),
        bytes_of("f"),
    )

def test_ignore_still_rejects_real_invalid_symbols() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "Zm!9v"
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
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "Z m ! 9 v"
        )
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 4)
    assert_true(caught)

def test_ignore_allows_empty_after_whitespace() raises:
    # An input that is only whitespace becomes an empty symbol stream and
    # decodes to empty bytes.
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]("  \n"),
        bytes_of(""),
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
