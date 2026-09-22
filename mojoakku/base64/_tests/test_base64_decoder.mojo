# Concern: `Decoder` — the stateful streaming decoder with a mandatory `finish`
# (BASE64_DOCS.md `### Decoder`).
#
# Covers: both `feed` overloads (StringSpan, Span[UInt8]); feed returns the
# bytes appended for the chunk and holds the sub-quantum remainder; finish
# validates and flushes the remainder; streaming equals one-shot decode
# (`feed...finish == decode`) for the same concatenated bytes; the end-of-stream
# flag makes input after padding fail like `decode("Zg==AAAA")`; discard drops
# the carry without validating; feed never raises INVALID_LENGTH while finish
# raises the full decode set.
#
# Note on the linear value: `Decoder` is `@explicit_destroy`. `feed(mut self)`
# does not consume it, so every path that could exit the function must reach a
# `discard`; `finish(deinit self)` consumes it on success and on its own error
# path, so no discard follows a failed `finish`.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
    Alphabet,
    PaddingMode,
    Whitespace,
    ErrorKind,
    Base64Error,
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
        _ = dec.feed("Zm9", out)
    except e:
        dec^.discard()
        raise e^
    try:
        _ = dec.feed("vYmFy", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(out, decode("Zm9vYmFy"))

def test_feed_returns_bytes_appended_per_chunk() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    var first = 0
    var second = 0
    try:
        first = dec.feed("Zm9v", out)
    except e:
        dec^.discard()
        raise e^
    try:
        second = dec.feed("YmFy", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    # "Zm9v" is one complete quantum -> 3 bytes; "YmFy" is another -> 3 bytes.
    assert_equal(first, 3)
    assert_equal(second, 3)
    assert_equal(len(out), 6)

def test_feed_holds_sub_quantum_remainder() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    var fed = 0
    try:
        fed = dec.feed("Zm", out)
    except e:
        dec^.discard()
        raise e^
    var after_feed = len(out)
    var flushed = dec^.finish(out)
    # A 2-symbol remainder is held; nothing is appended by feed.
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
        _ = dec.feed("Zm9vYmFy", out)
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
    var raw = bytes_of("Zm9vYmFy")
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
    var raw = "Zm9vYmFy"
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
        _ = dec.feed("Zg", out)
    except e:
        dec^.discard()
        raise e^
    try:
        _ = dec.feed("==", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(out, decode("Zg=="))

def test_padding_then_more_symbols_fails_like_one_shot() raises:
    # feed("Zg==") then feed("AAAA") must fail just like decode("Zg==AAAA").
    var out = List[UInt8]()
    var dec = Decoder()
    var kind = ErrorKind.INVALID_SYMBOL
    try:
        _ = dec.feed("Zg==", out)
        _ = dec.feed("AAAA", out)
        dec^.discard()
    except e:
        kind = e.kind
        dec^.discard()
    assert_equal(kind, ErrorKind.INVALID_PADDING)

def test_finish_raises_invalid_length_for_impossible_remainder() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("A", out)
    except e:
        dec^.discard()
        raise e^
    # A single base64 symbol is structurally impossible and only knowable at
    # finish.
    var caught = False
    try:
        _ = dec^.finish(out)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_equal(e.position, 0)
    assert_true(caught)

def test_finish_raises_invalid_padding_for_missing_padding() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("Zg", out)
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
        _ = dec.feed("Zm!v", out)
        dec^.discard()
    except e:
        kind = e.kind
        dec^.discard()
    assert_equal(kind, ErrorKind.INVALID_SYMBOL)

def test_feed_raises_invalid_padding_for_padding_mid_stream() raises:
    # A padding symbol with symbols still expected (no full quantum yet) is a
    # mid-stream padding error.
    var out = List[UInt8]()
    var dec = Decoder()
    var kind = ErrorKind.INVALID_SYMBOL
    try:
        _ = dec.feed("Zg=", out)
        dec^.discard()
    except e:
        kind = e.kind
        dec^.discard()
    assert_equal(kind, ErrorKind.INVALID_PADDING)

def test_discard_drops_carry_without_appending() raises:
    var out = List[UInt8]()
    var dec = Decoder()
    try:
        _ = dec.feed("Zm9v", out)
    except e:
        dec^.discard()
        raise e^
    try:
        _ = dec.feed("Zm", out)
    except e:
        dec^.discard()
        raise e^
    var appended_before = len(out)
    dec^.discard()
    assert_equal(len(out), appended_before)
    assert_equal(out, bytes_of("foo"))

def test_tolerant_streaming_matches_one_shot() raises:
    var out = List[UInt8]()
    var dec = Decoder[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]()
    try:
        _ = dec.feed("Zg", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(
        out,
        decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("Zg"),
    )

def test_ignore_whitespace_streaming_matches_one_shot() raises:
    var out = List[UInt8]()
    var dec = Decoder[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]()
    try:
        _ = dec.feed("Zm 9v", out)
    except e:
        dec^.discard()
        raise e^
    _ = dec^.finish(out)
    assert_equal(
        out,
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]("Zm 9v"),
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
