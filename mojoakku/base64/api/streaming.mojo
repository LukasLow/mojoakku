# MojoAkku base64 — explicit streaming (api area: streaming).
#
# Stateful `Encoder` and `Decoder` value types carry the sub-quantum remainder
# between calls. `finish` is mandatory: `@explicit_destroy` plus
# `Deinitable where False` makes abandoning an instance a compile-time error, so
# the final flush can never be silently skipped.

from .options import Alphabet, Padding, PaddingMode, Whitespace
from .errors import Base64Error

from base64.src.engine import EncodeState, DecodeState


# Encoder — stateful encode value type owning the sub-quantum byte carry.
#
# Parameters / preconditions: the compile-time `alphabet` and `padding` mirror
# one-shot `encode`. `feed` accepts successive borrowed chunks of any length,
# including empty, as raw bytes (Span) or text (StringSpan); `out` is
# caller-owned and appended to.
# Return / meaning: `feed` returns the number of encoded characters appended for
# this chunk, encoding only complete quanta and holding the remainder; `finish`
# encodes the final partial quantum (with padding if REQUIRED) and returns the
# number appended. `finish` is the only place padding is emitted.
# Errors: none; encode cannot fail. `discard` drops the remainder without
# emitting it.
# Semantics (one line): feed complete quanta as they arrive, then finish exactly
# once to emit the remainder.
@explicit_destroy("call finish() or discard() before this encoder leaves scope")
struct Encoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](Deinitable where False):
    # The encoder owns only the sub-quantum carry; it is never exposed.
    var _state: EncodeState

    # __init__ — create an encoder with an empty carry.
    #
    # Parameters: none.
    # Return / meaning: an Encoder ready for the first `feed`.
    # Errors: none.
    # Semantics (one line): start a fresh stream with no buffered bytes.
    def __init__(out self):
        self._state = EncodeState()

    # feed (Span[UInt8]) — encode a borrowed chunk of raw bytes.
    #
    # Parameters: `chunk` is borrowed bytes of any length, including empty;
    # `out` is caller-owned and appended to.
    # Return / meaning: the number of encoded characters appended for this
    # chunk; only complete quanta are encoded and the remainder is held back.
    # Errors: none.
    # Semantics (one line): append whole-quantum output and retain the
    # sub-quantum carry.
    def feed(mut self, chunk: Span[UInt8, _], mut out: String) -> Int:
        return self._state.feed[Self.alphabet, Self.padding](chunk, out)

    # feed (StringSpan) — encode a borrowed chunk of text treated as raw bytes.
    #
    # Parameters: `chunk` is borrowed text treated byte by byte; `out` is
    # caller-owned and appended to.
    # Return / meaning: the number of encoded characters appended for this
    # chunk; the sub-quantum remainder is held back.
    # Errors: none.
    # Semantics (one line): the text overload of Encoder.feed.
    def feed(mut self, chunk: StringSpan, mut out: String) -> Int:
        return self._state.feed[Self.alphabet, Self.padding](chunk.as_bytes(), out)

    # finish — encode the final partial quantum and append it (mandatory flush).
    #
    # Parameters: `out` is caller-owned and appended to.
    # Return / meaning: the number of encoded characters appended, including any
    # required padding. This is the only place padding is emitted.
    # Errors: none.
    # Semantics (one line): consume the encoder and flush the remainder exactly
    # once.
    def finish(deinit self, mut out: String) -> Int:
        return self._state.finish[Self.alphabet, Self.padding](out)

    # discard — drop the remainder without emitting it.
    #
    # Parameters: none.
    # Return / meaning: consumes the encoder; the sub-quantum remainder is
    # abandoned and nothing is appended. `out` is not touched.
    # Errors: none.
    # Semantics (one line): the explicit, non-silent way to abandon a stream.
    def discard(deinit self):
        pass


# Decoder — stateful decode value type owning the sub-quantum character carry.
#
# Parameters / preconditions: the compile-time `alphabet`, `padding_mode` and
# `whitespace` mirror one-shot `decode`. `feed` accepts successive borrowed
# chunks as text (StringSpan) or bytes (Span); `out` is caller-owned and
# appended to.
# Return / meaning: `feed` decodes left to right, appends each complete quantum
# and holds back the sub-quantum remainder, returning the bytes appended for this
# chunk. `finish` validates the final partial quantum exactly as `decode` does
# and returns the bytes appended.
# Errors: raises Base64Error. `feed` can raise INVALID_SYMBOL or
# INVALID_PADDING; `finish` raises the full `decode` set (INVALID_SYMBOL,
# INVALID_LENGTH, INVALID_PADDING). Complete quanta decoded before an error
# remain appended. `discard` cannot raise.
# Semantics (one line): feed complete quanta as they arrive, then finish exactly
# once to validate and flush the remainder.
@explicit_destroy("call finish() or discard() before this decoder leaves scope")
struct Decoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](Deinitable where False):
    # The decoder owns only the sub-quantum character carry; it is never exposed.
    var _state: DecodeState

    # __init__ — create a decoder with an empty carry and a clear stream-ended
    # flag.
    #
    # Parameters: none.
    # Return / meaning: a Decoder ready for the first `feed`.
    # Errors: none.
    # Semantics (one line): start a fresh stream with no buffered symbols.
    def __init__(out self):
        self._state = DecodeState()

    # feed (StringSpan) — decode a borrowed chunk of encoded text.
    #
    # Parameters: `chunk` is borrowed encoded text of any length, including
    # empty; `out` is caller-owned and appended to. `self` is borrowed, not
    # consumed.
    # Return / meaning: the number of decoded bytes appended for this chunk;
    # complete quanta are decoded and the sub-quantum remainder is held back.
    # Errors: raises Base64Error — INVALID_SYMBOL (byte outside the alphabet, or
    # whitespace under REJECT) or INVALID_PADDING (a padding symbol seen
    # mid-stream, or a symbol after the stream has ended). Never INVALID_LENGTH.
    # Semantics (one line): append whole-quantum output and retain the
    # sub-quantum carry.
    def feed(mut self, chunk: StringSpan, mut out: List[UInt8]) raises Base64Error -> Int:
        return self._state.feed_chunk[Self.alphabet, Self.padding_mode, Self.whitespace](chunk.as_bytes(), out)

    # feed (Span[UInt8]) — decode a borrowed chunk of encoded bytes.
    #
    # Parameters: `chunk` is borrowed encoded bytes of any length, including
    # empty; `out` is caller-owned and appended to.
    # Return / meaning: the number of decoded bytes appended for this chunk; the
    # sub-quantum remainder is held back.
    # Errors: raises Base64Error with the same kinds as the StringSpan overload;
    # never INVALID_LENGTH.
    # Semantics (one line): the byte overload of Decoder.feed.
    def feed(mut self, chunk: Span[UInt8, _], mut out: List[UInt8]) raises Base64Error -> Int:
        return self._state.feed_chunk[Self.alphabet, Self.padding_mode, Self.whitespace](chunk, out)

    # finish — validate and flush the final partial quantum (mandatory flush).
    #
    # Parameters: `out` is caller-owned and appended to.
    # Return / meaning: the number of decoded bytes appended. A structurally
    # impossible remainder raises INVALID_LENGTH; a structurally valid partial
    # quantum that under STRICT lacks its canonical padding raises
    # INVALID_PADDING, while under TOLERANT it is completed without padding.
    # Errors: raises Base64Error — the full `decode` set (INVALID_SYMBOL,
    # INVALID_LENGTH, INVALID_PADDING); all recoverable.
    # Semantics (one line): consume the decoder and validate exactly what
    # remains, matching `decode` for the concatenated stream.
    def finish(deinit self, mut out: List[UInt8]) raises Base64Error -> Int:
        return self._state.finish[Self.alphabet, Self.padding_mode](True, out)

    # discard — drop the retained carry without validating it.
    #
    # Parameters: none.
    # Return / meaning: consumes the decoder; the unvalidated partial quantum is
    # abandoned (never decoded, never reported), `out` keeps exactly the complete
    # quanta appended by prior `feed` calls.
    # Errors: none; the call cannot raise.
    # Semantics (one line): the explicit way to end a stream without flushing a
    # remainder.
    def discard(deinit self):
        pass
