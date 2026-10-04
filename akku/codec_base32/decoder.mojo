from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .base32_error import Base32Error

from akku.codec_base32._internal.engine import DecodeState


# Decoder — stateful decode value type owning the sub-quantum character carry.
# feed holds back the sub-quantum remainder; finish validates it exactly like
# decode. See API-DOCS below.
@explicit_destroy("call finish() or discard() before this decoder leaves scope")
struct Decoder[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](Deinitable where False):
    var _state: DecodeState

    def __init__(out self):
        self._state = DecodeState()

    def feed(mut self, chunk: StringSpan, mut out: List[UInt8]) raises Base32Error -> Int:
        return self._state.feed_chunk[Self.alphabet, Self.padding_mode, Self.whitespace](chunk.as_bytes(), out)

    # Span[UInt8] overload of Decoder.feed.
    def feed(mut self, chunk: Span[UInt8, _], mut out: List[UInt8]) raises Base32Error -> Int:
        return self._state.feed_chunk[Self.alphabet, Self.padding_mode, Self.whitespace](chunk, out)

    def finish(deinit self, mut out: List[UInt8]) raises Base32Error -> Int:
        return self._state.finish[Self.alphabet, Self.padding_mode](True, out)

    def discard(deinit self):
        pass

# API-DOCS-START
# Decoder — stateful streaming decoder with a mandatory finish.
# Signature:
#   @explicit_destroy("call finish() or discard() before this decoder leaves scope")
#   struct Decoder[
#       alphabet: Alphabet = Alphabet.B32_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](Deinitable where False):
#       def __init__(out self)
#       def feed(mut self, chunk: StringSpan, mut out: List[UInt8]) raises Base32Error -> Int
#       def feed(mut self, chunk: Span[UInt8], mut out: List[UInt8]) raises Base32Error -> Int
#       def finish(deinit self, mut out: List[UInt8]) raises Base32Error -> Int
#       def discard(deinit self)
# What it does:
#   Decodes a stream that arrives in pieces. `feed` accepts successive borrowed
#   encoded-text chunks of any length, including empty, as StringSpan or
#   Span[UInt8]; each call decodes the complete 8-symbol quanta it can, appends
#   them to the caller-owned `out` and holds the sub-quantum remainder (0-7
#   symbols). A chunk boundary is not end of stream: an incomplete padding run at
#   a chunk edge is retained and judged by `finish`. `feed...feed; finish()`
#   therefore matches one-shot `decode` of the concatenation — same output, same
#   error kind, same `position`. The compile-time options match `decode`; `feed`
#   borrows the decoder while `finish` and `discard` consume it. The struct is
#   `@explicit_destroy`, so the mandatory final validation cannot be skipped.
# Returns:
#   `feed` returns the number of decoded bytes appended for that chunk; `finish`
#   returns the number appended while flushing and validating the remainder;
#   `discard` returns nothing. The caller owns `out`.
# Errors:
#   raises Base32Error, all recoverable. `feed` can raise INVALID_SYMBOL (a byte
#   outside the alphabet, including lowercase and whitespace under REJECT) or
#   INVALID_PADDING (a padding symbol mid-stream, or a symbol after the stream
#   ended); it never raises INVALID_LENGTH, because it holds back every
#   sub-quantum remainder. `finish` raises the full `decode` set (INVALID_SYMBOL,
#   INVALID_LENGTH, INVALID_PADDING). Complete quanta decoded before an error
#   stay appended. `discard` cannot raise; it drops the carry without validating
#   it.
# Example:
#   var out = List[UInt8]()
#   var dec = Decoder()
#   _ = dec.feed("MZXW6===", out)    # -> 3 bytes ("foo")
#   _ = dec.feed("MZXW6YTB", out)    # -> 3 more ("bar")
#   _ = dec^.finish(out)             # out -> "foobar" bytes
#   # Unpadded partial quantum needs TOLERANT at finish:
#   var out2 = List[UInt8]()
#   var dec2 = Decoder[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]()
#   _ = dec2.feed("MY", out2)
#   _ = dec2^.finish(out2)           # out2 -> [102]
# API-DOCS-END
