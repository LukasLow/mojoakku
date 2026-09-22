# API-DOCS-START
# Decoder — stateful decode value type owning the sub-quantum character carry.
# Status: implemented
# Signature: @explicit_destroy("call finish() or discard() before this decoder
#   leaves scope") struct Decoder[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding_mode: PaddingMode = PaddingMode.STRICT,
#   whitespace: Whitespace = Whitespace.REJECT,
# ](Deinitable where False):
#   def __init__(out self)
#   def feed(mut self, chunk: StringSpan, mut out: List[UInt8]) raises Base64Error -> Int
#   def feed(mut self, chunk: Span[UInt8], mut out: List[UInt8]) raises Base64Error -> Int
#   def finish(deinit self, mut out: List[UInt8]) raises Base64Error -> Int
#   def discard(deinit self)
# Semantics: feed accepts successive borrowed encoded-text chunks of any length,
#   as StringSpan or Span[UInt8]; the two overloads mirror one-shot decode. `out`
#   is caller-owned and appended to. finish/discard consume the decoder. The carry
#   size is quantum_symbols-1 (base64 0-3, base32 0-7, base16 0-1) in a small
#   fixed Array[UInt8, 8] plus a count; never exposed. feed decodes left to right,
#   appends each complete quantum, holds back the sub-quantum remainder and
#   returns the bytes appended for this chunk. finish validates the final partial
#   quantum and mirrors decode exactly; a partial quantum that is structurally
#   impossible raises INVALID_LENGTH, one lacking its canonical padding under
#   STRICT raises INVALID_PADDING. A persistent stream-ended flag makes
#   feed(c1);...;feed(cn);finish() equivalent to decode(c1++...+cn). feed takes
#   mut self (borrow, not consume); only finish/discard take deinit self.
#   EOF is the caller's call to finish, not an I/O event.
# Errors: raises Base64Error. feed can raise INVALID_SYMBOL (byte outside the
#   alphabet, or whitespace under REJECT) and INVALID_PADDING (a padding symbol
#   seen mid-stream, or a symbol after the stream ended); it cannot raise
#   INVALID_LENGTH because feed holds back every sub-quantum remainder. finish
#   raises the full decode set (INVALID_SYMBOL, INVALID_LENGTH, INVALID_PADDING).
#   All are recoverable data errors; complete quanta decoded before an error
#   remain appended (partial-commit). discard cannot raise.
# Tests: test_base64_decoder.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a streaming decoder carrying <=(quantum-1) symbols
#   because Rust's DecoderReader carries leftovers in fixed buffers and JS's
#   setFromBase64 -> {read,written} with stop-before-partial is the documented
#   userland pattern for exactly this carry, while Elixir/Python leave it to the
#   caller and are the gap this closes.
# API-DOCS-END

from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .base64_error import Base64Error

from base64._internal.engine import DecodeState


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
