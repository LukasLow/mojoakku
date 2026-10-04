# Concern: `Encoder` — the stateful streaming encoder with a mandatory `finish`
# (docs block in `../encoder.mojo`).
#
# Covers: both `feed` overloads (Span[UInt8], StringSpan); feed returns the
# number of encoded characters appended for the chunk and holds the sub-quantum
# remainder (0-4 bytes); finish encodes the final partial quantum, is the only
# place padding is emitted, and returns the count; discard drops the remainder
# without emitting it; streaming equals one-shot encode (`feed...finish ==
# encode`); empty chunks are accepted.
#
# Note on the linear value: `Encoder` is `@explicit_destroy`, so `finish` or
# `discard` must run on every path. Assertions that could raise are placed after
# the consuming call, and feed return values are captured first.

from std.testing import assert_equal, TestSuite
from akku.codec_base32 import (
    Alphabet,
    Padding,
    Encoder,
    encode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_feed_and_finish_match_one_shot_encode() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    _ = enc.feed("fo", out)
    _ = enc.feed("ob", out)
    _ = enc.feed("ar", out)
    _ = enc^.finish(out)
    assert_equal(out, encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("foobar"))

def test_feed_returns_characters_appended_per_chunk() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    # "fooba" is one whole 5-byte quantum -> 8 symbols; "r" is held.
    var first = enc.feed("fooba", out)
    var second = enc.feed("r", out)
    var flushed = enc^.finish(out)
    assert_equal(first, 8)
    assert_equal(second, 0)
    assert_equal(flushed, 8)
    assert_equal(out, encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("foobar"))

def test_finish_is_the_only_place_padding_is_emitted() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    var fed = enc.feed("f", out)
    var after_feed = out.byte_length()
    var flushed = enc^.finish(out)
    assert_equal(fed, 0)
    assert_equal(after_feed, 0)
    assert_equal(flushed, 8)
    assert_equal(out, "MY======")

def test_five_byte_quantum_crosses_chunk_boundaries() raises:
    # The carry is 0-4 bytes; five bytes fed one at a time must still combine.
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    _ = enc.feed("f", out)
    _ = enc.feed("o", out)
    _ = enc.feed("o", out)
    _ = enc.feed("b", out)
    _ = enc.feed("a", out)
    var after_quantum = String(out)
    _ = enc^.finish(out)
    # The whole quantum is emitted once the fifth byte arrives.
    assert_equal(after_quantum, "MZXW6YTB")
    assert_equal(out, encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("fooba"))

def test_padding_omitted_over_stream() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.OMITTED]()
    _ = enc.feed("f", out)
    _ = enc^.finish(out)
    assert_equal(out, "MY")
    assert_equal(out, encode[Alphabet.B32_STANDARD, Padding.OMITTED]("f"))

def test_hex_alphabet_streaming_matches_one_shot() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_HEX, Padding.REQUIRED]()
    _ = enc.feed("fo", out)
    _ = enc.feed("ob", out)
    _ = enc.feed("ar", out)
    _ = enc^.finish(out)
    assert_equal(out, encode[Alphabet.B32_HEX, Padding.REQUIRED]("foobar"))

def test_empty_chunks_are_accepted() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    var a = enc.feed("", out)
    _ = enc.feed("foobar", out)
    var b = enc.feed("", out)
    _ = enc^.finish(out)
    assert_equal(a, 0)
    assert_equal(b, 0)
    assert_equal(out, encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("foobar"))

def test_byte_overload_matches_string_overload() raises:
    var data = bytes_of("foobar")
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    _ = enc.feed(Span(data), out)
    _ = enc^.finish(out)
    assert_equal(out, encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("foobar"))

def test_discard_drops_remainder_without_emitting() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    _ = enc.feed("fo", out)
    var appended_before_discard = out.byte_length()
    enc^.discard()
    assert_equal(out.byte_length(), appended_before_discard)
    assert_equal(out, "")

def test_discard_after_complete_quanta_keeps_them() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    # 6 bytes: "fooba" is one whole quantum, the trailing "r" is held.
    _ = enc.feed("foobar", out)
    var before = String(out)
    enc^.discard()
    assert_equal(out, before)
    assert_equal(out, encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("fooba"))

def test_streaming_all_chunk_splits_equals_one_shot() raises:
    # Every split point must produce the same encoded output as the one-shot
    # encode of the concatenation.
    var raw = "foobarbazqux"
    var all = bytes_of(raw)
    for split in range(0, len(all) + 1):
        var first = List[UInt8]()
        for i in range(0, split):
            first.append(all[i])
        var second = List[UInt8]()
        for i in range(split, len(all)):
            second.append(all[i])
        var out = String()
        var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
        _ = enc.feed(Span(first), out)
        _ = enc.feed(Span(second), out)
        _ = enc^.finish(out)
        assert_equal(
            out,
            encode[Alphabet.B32_STANDARD, Padding.REQUIRED](raw),
            "split point mismatch",
        )

def test_empty_stream_finish_emits_nothing() raises:
    var out = String()
    var enc = Encoder[Alphabet.B32_STANDARD, Padding.REQUIRED]()
    var written = enc^.finish(out)
    assert_equal(written, 0)
    assert_equal(out, "")

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
