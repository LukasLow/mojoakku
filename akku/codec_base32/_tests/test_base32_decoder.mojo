# Concern: `Decoder` — the stateful streaming decoder with a mandatory `finish`
# (docs block in `../decoder.mojo`).
#
# Covers: both `feed` overloads (StringSpan, Span[UInt8]); feed returns the
# bytes appended for the chunk and holds the sub-quantum remainder (0-7
# symbols); finish validates and flushes the remainder; streaming equals
# one-shot decode (`feed...finish == decode`) for the same concatenated bytes;
# the end-of-stream flag makes input after padding fail like one-shot decode;
# discard drops the carry without validating; feed never raises INVALID_LENGTH
# while finish raises the full decode set.
#
# Note on the linear value: `Decoder` is `@explicit_destroy`. `feed(mut self)`
# does not consume it, so every path that could exit the function must reach a
# `discard`; `finish(deinit self)` consumes it on success and on its own error
# path, so no discard follows a failed `finish`.

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    Alphabet,
    PaddingMode,
    Whitespace,
    ErrorKind,
    Decoder,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_feed_and_finish_match_one_shot_decode() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("MZXW6", out)
    except e:
        dec^.discard()
        raise e^
    try:
        _ = dec.feed("YTBOI======", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(out, decode("MZXW6YTBOI======"))

def test_feed_returns_bytes_appended_per_chunk() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    var first = 0
    var second = 0
    try:
        # One whole 8-symbol quantum -> 5 bytes.
        first = dec.feed("MZXW6YTB", out)
    except e:
        dec^.discard()
        raise e^
    try:
        # A second whole quantum -> 5 more bytes.
        second = dec.feed("MZXW6YTB", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(first, 5)
    assert_equal(second, 5)
    assert_equal(len(out), 10)

def test_feed_holds_sub_quantum_remainder() raises:
    # A 2-symbol remainder is held by feed and completed by finish. Under the
    # default PaddingMode.STRICT, finish on an unpadded partial quantum raises
    # INVALID_PADDING, so this test uses TOLERANT.
    var out = List[UInt8]()
    var dec = Decoder[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]()
    var fed = 0
    try:
        fed = dec.feed("MY", out)
    except e:
        dec^.discard()
        raise e^
    var after_feed = len(out)
    var flushed = dec^.finish(out)
    assert_equal(fed, 0)
    assert_equal(after_feed, 0)
    assert_equal(flushed, 1)
    assert_equal(out, bytes_of("f"))

def test_empty_stream_finish_appends_nothing() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    var written = dec^.finish(out)
    assert_equal(written, 0)
    assert_equal(len(out), 0)

def test_empty_chunks_are_accepted() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    var a = 0
    var b = 0
    try:
        a = dec.feed("", out)
    except e:
        dec^.discard()
        raise e^
    try:
        _ = dec.feed("MZXW6YTBOI======", out)
    except e:
        dec^.discard()
        raise e^
    try:
        b = dec.feed("", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(a, 0)
    assert_equal(b, 0)
    assert_equal(out, bytes_of("foobar"))

def test_byte_overload_matches_string_overload() raises:
    var raw = bytes_of("MZXW6YTBOI======")
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed(Span(raw), out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(out, bytes_of("foobar"))

def test_streaming_all_chunk_splits_equal_one_shot() raises:
    var raw = "MZXW6YTBOI======"
    var all = bytes_of(raw)
    for split in range(0, len(all) + 1):
        var first = List[UInt8]()
        for i in range(0, split):
            first.append(all[i])
        var second = List[UInt8]()
        for i in range(split, len(all)):
            second.append(all[i])
        var out = List[UInt8]()
        var dec = Decoder()
        try:
            _ = dec.feed(Span(first), out)
        except e:
            dec^.discard()
            raise e^
        try:
            _ = dec.feed(Span(second), out)
        except e:
            dec^.discard()
            raise e^
        _ = dec^.finish(out)
        assert_equal(out, decode(raw), "split point mismatch")

def test_streaming_matches_one_shot_with_padding() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("MY", out)
    except e:
        dec^.discard()
        raise e^
    try:
        _ = dec.feed("======", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(out, decode("MY======"))

def test_incomplete_padding_at_finish_raises() raises:
    # A stream that ends mid-padding ("MY=") is an incomplete padding run and
    # raises INVALID_PADDING only at finish, matching one-shot decode("MY=").
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("MY=", out)
    except e:
        dec^.discard()
        raise e^
    var caught = False
    try:
        _ = dec^.finish(out)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_padding_then_more_symbols_fails_like_one_shot() raises:
    # feed("MZXW6YTBOI======") then feed("AAAA") must fail just like
    # decode("MZXW6YTBOI======AAAA"), same kind and cumulative position.
    var one_shot_kind = ErrorKind.INVALID_SYMBOL
    var one_shot_pos = -1
    var one_shot_caught = False
    try:
        _ = decode("MZXW6YTBOI======AAAA")
    except e:
        one_shot_caught = True
        one_shot_kind = e.kind
        one_shot_pos = e.position
    assert_true(one_shot_caught)

    var out = List[UInt8]()
    var dec = Decoder()
    var kind = ErrorKind.INVALID_SYMBOL
    var pos = -1
    var caught = False
    try:
        _ = dec.feed("MZXW6YTBOI======", out)
        _ = dec.feed("AAAA", out)
        dec^.discard()
    except e:
        caught = True
        kind = e.kind
        pos = e.position
        dec^.discard()
    assert_true(caught)
    assert_equal(kind, one_shot_kind)
    assert_equal(pos, one_shot_pos)

def test_streaming_error_position_matches_one_shot() raises:
    # An invalid symbol in the SECOND chunk must report the cumulative position
    # of the whole stream: feed("MZX") then feed("!W6") reports the same kind and
    # position as decode("MZX!W6").
    var one_shot_kind = ErrorKind.INVALID_PADDING
    var one_shot_pos = -1
    var one_shot_caught = False
    try:
        _ = decode("MZX!W6")
    except e:
        one_shot_caught = True
        one_shot_kind = e.kind
        one_shot_pos = e.position
    assert_true(one_shot_caught)

    var out = List[UInt8]()
    var dec = Decoder()
    var kind = ErrorKind.INVALID_PADDING
    var pos = -1
    var caught = False
    try:
        _ = dec.feed("MZX", out)
        _ = dec.feed("!W6", out)
        dec^.discard()
    except e:
        caught = True
        kind = e.kind
        pos = e.position
        dec^.discard()
    assert_true(caught)
    assert_equal(kind, one_shot_kind)
    assert_equal(pos, one_shot_pos)

def test_carry_atomicity_invalid_symbol_not_retained() raises:
    # Each symbol is validated before it mutates the carry, so on a raise the
    # carry holds only fully validated sub-quantum symbols. Feed a valid
    # 2-symbol remainder, then a chunk whose first symbol is invalid; the
    # retained carry must still be the two valid symbols "MZ" -- not "MZ!". A
    # retained "MZ" (a valid remainder lacking its canonical padding) makes
    # finish raise INVALID_PADDING, whereas a carry contaminated with '!' would
    # raise INVALID_SYMBOL.
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("MZ", out)
    except e:
        dec^.discard()
        raise e^

    var feed_kind = ErrorKind.INVALID_PADDING
    var feed_pos = -1
    var feed_caught = False
    try:
        _ = dec.feed("!W6", out)
    except e:
        feed_caught = True
        feed_kind = e.kind
        feed_pos = e.position

    var finish_kind = ErrorKind.INVALID_SYMBOL
    var finish_caught = False
    try:
        _ = dec^.finish(out)
    except e:
        finish_caught = True
        finish_kind = e.kind

    assert_true(feed_caught)
    assert_equal(feed_kind, ErrorKind.INVALID_SYMBOL)
    # '!' is the third symbol of the stream; the two earlier symbols remain.
    assert_equal(feed_pos, 2)
    assert_true(finish_caught)
    assert_equal(finish_kind, ErrorKind.INVALID_PADDING)

def test_finish_raises_invalid_length_for_impossible_remainder() raises:
    # base32 remainders 1, 3 and 6 data symbols are structurally impossible and
    # only knowable at finish.
    for input in ["A", "AAA", "AAAAAA"]:
        var out = List[UInt8]()
        var dec = Decoder()
        try:
            _ = dec.feed(input, out)
        except e:
            dec^.discard()
            raise e^
        var caught = False
        try:
            _ = dec^.finish(out)
        except e:
            caught = True
            assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_true(caught)

def test_finish_raises_invalid_padding_for_missing_padding() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("MY", out)
    except e:
        dec^.discard()
        raise e^
    var caught = False
    try:
        _ = dec^.finish(out)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_feed_raises_invalid_symbol() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    var kind = ErrorKind.INVALID_PADDING
    try:
        _ = dec.feed("MZ!W6===", out)
        dec^.discard()
    except e:
        kind = e.kind
        dec^.discard()
    assert_equal(kind, ErrorKind.INVALID_SYMBOL)

def test_feed_raises_invalid_padding_for_symbol_after_padding() raises:
    # Padding is terminal: a real symbol after a padding symbol is an error. A
    # padding run that merely crosses a chunk boundary is NOT an error.
    var out = List[UInt8]()
    var dec = Decoder()
    var kind = ErrorKind.INVALID_SYMBOL
    try:
        _ = dec.feed("MY======Z", out)
        dec^.discard()
    except e:
        kind = e.kind
        dec^.discard()
    assert_equal(kind, ErrorKind.INVALID_PADDING)

def test_discard_drops_carry_without_appending() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("MZXW6YTB", out)
    except e:
        dec^.discard()
        raise e^
    try:
        _ = dec.feed("MZ", out)
    except e:
        dec^.discard()
        raise e^
    var appended_before = len(out)
    dec^.discard()
    assert_equal(len(out), appended_before)
    assert_equal(out, bytes_of("fooba"))

def test_tolerant_streaming_matches_one_shot() raises:
    var out = List[UInt8]()
    var dec = Decoder[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]()
    try:
        _ = dec.feed("MY", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(
        out,
        decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("MY"),
    )

def test_ignore_whitespace_streaming_matches_one_shot() raises:
    var out = List[UInt8]()
    var dec = Decoder[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]()
    try:
        _ = dec.feed("MZ XW6===", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(
        out,
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "MZ XW6==="
        ),
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
