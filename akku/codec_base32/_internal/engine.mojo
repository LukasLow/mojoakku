# MojoAkku base32 — private implementation engine.
#
# Real logic lives here; the public per-entry API files only delegate. The
# compile-time option values (Alphabet, Padding, PaddingMode, Whitespace,
# ErrorKind) are the public value types from the flat per-entry modules
# (`codec_base32.alphabet`, ...), used here as value parameters so table lookups
# and branches resolve while compiling.
#
# base32 geometry: 5 input bytes <-> 8 symbols, 5 bits per symbol, '=' padding to
# a multiple of 8. Valid decode remainders are 2, 4, 5 or 7 data symbols;
# remainders 1, 3 and 6 are structurally impossible.
#
# Ids:
#   Alphabet:      0 B32_STANDARD  1 B32_HEX
#   Padding:       0 REQUIRED      1 OMITTED
#   PaddingMode:   0 STRICT        1 TOLERANT
#   Whitespace:    0 REJECT        1 IGNORE

from akku.codec_base32.alphabet import Alphabet
from akku.codec_base32.padding import Padding
from akku.codec_base32.padding_mode import PaddingMode
from akku.codec_base32.whitespace import Whitespace
from akku.codec_base32.error_kind import ErrorKind
from akku.codec_base32.base32_error import Base32Error


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

# quantum_bytes — input bytes in one whole quantum (base32: 5).
def quantum_bytes[a: Alphabet]() -> Int:
    return 5


# quantum_syms — encoded symbols in one whole quantum (base32: 8).
def quantum_syms[a: Alphabet]() -> Int:
    return 8


# bits_per_symbol — value bits carried by one encoded symbol (base32: 5).
def bits_per_symbol[a: Alphabet]() -> Int:
    return 5


# has_padding — both RFC 4648 base32 alphabets use '=' padding.
def has_padding[a: Alphabet]() -> Bool:
    return True


# is_ws — one of space, tab, CR, LF, FF, VT.
def is_ws(b: UInt8) -> Bool:
    return b == UInt8(32) or b == UInt8(9) or b == UInt8(13) or b == UInt8(10) or b == UInt8(12) or b == UInt8(11)


# ---------------------------------------------------------------------------
# Symbol tables (uppercase-only on decode)
# ---------------------------------------------------------------------------

# enc_symbol — map a value [0, 32) to its encoded ASCII symbol.
def enc_symbol[a: Alphabet](v: Int) -> UInt8:
    if a == Alphabet.B32_STANDARD:
        if v < 26:
            return UInt8(65 + v)        # 'A'..'Z'
        return UInt8(50 + v - 26)       # '2'..'7'
    else:
        if v < 10:
            return UInt8(48 + v)        # '0'..'9'
        return UInt8(65 + v - 10)       # 'A'..'V'


# dec_value — map an encoded symbol to its value, or -1 if it is not in the
# alphabet. Both base32 alphabets are case-sensitive, uppercase-only.
def dec_value[a: Alphabet](b: UInt8) -> Int:
    if a == Alphabet.B32_STANDARD:
        if b >= UInt8(65) and b <= UInt8(90):
            return Int(b) - 65
        if b >= UInt8(50) and b <= UInt8(55):
            return Int(b) - 50 + 26
        return -1
    else:
        if b >= UInt8(48) and b <= UInt8(57):
            return Int(b) - 48
        if b >= UInt8(65) and b <= UInt8(86):
            return Int(b) - 65 + 10
        return -1


# ---------------------------------------------------------------------------
# Length functions (pure, total)
# ---------------------------------------------------------------------------

# encoded_len_core — exact encoded length for n bytes; n < 0 is defined as 0.
def encoded_len_core[p: Padding](n: Int) -> Int:
    if n < 0:
        return 0
    if p == Padding.OMITTED:
        return (n * 8 + 4) // 5
    return 8 * ((n + 4) // 5)


# decoded_len_core — maximum decoded byte count for n symbols; n < 0 is 0.
def decoded_len_core(n: Int) -> Int:
    if n < 0:
        return 0
    var extra = 0
    var rem = n % 8
    if rem == 2:
        extra = 1
    elif rem == 4:
        extra = 2
    elif rem == 5:
        extra = 3
    elif rem == 7:
        extra = 4
    return (n // 8) * 5 + extra


# ---------------------------------------------------------------------------
# Encoding
# ---------------------------------------------------------------------------

# encode_full_bytes — encode exactly 5 bytes (a whole quantum); no padding.
def encode_full_bytes[a: Alphabet](buf: Span[UInt8, _], mut out: String):
    var qb = quantum_bytes[a]()
    var qs = quantum_syms[a]()
    var bps = bits_per_symbol[a]()
    var mask = (1 << bps) - 1
    var acc = 0
    for k in range(qb):
        acc = (acc << 8) | Int(buf[k])
    for k in range(qs):
        var shift = qb * 8 - (k + 1) * bps
        var v = (acc >> shift) & mask
        out += chr(Int(enc_symbol[a](v)))


# encode_partial — encode r < 5 bytes (a partial final quantum), appending
# padding when the policy is REQUIRED.
def encode_partial[a: Alphabet, p: Padding](buf: Span[UInt8, _], mut out: String):
    var r = len(buf)
    if r == 0:
        return
    var qs = quantum_syms[a]()
    var bps = bits_per_symbol[a]()
    var mask = (1 << bps) - 1
    var total = r * 8
    var acc = 0
    for k in range(r):
        acc = (acc << 8) | Int(buf[k])
    var syms = (total + bps - 1) // bps
    for k in range(syms):
        var avail = total - k * bps
        var v = (acc << (bps - avail)) & mask
        if avail >= bps:
            v = (acc >> (avail - bps)) & mask
        out += chr(Int(enc_symbol[a](v)))
    if has_padding[a]() and p == Padding.REQUIRED:
        for _ in range(qs - syms):
            out += "="


# EncodeState — the sub-quantum byte carry plus a count, shared by the one-shot
# and streaming encoders. The carry holds at most 4 bytes; it is sized 8 so the
# 4 carry bytes plus the incoming byte always fit.
struct EncodeState:
    var carry: Array[UInt8, 8]
    var count: Int

    def __init__(out self):
        self.carry = Array[UInt8, 8](fill=0)
        self.count = 0

    # feed — encode every complete quantum in `chunk`, holding the remainder;
    # returns the number of encoded characters appended.
    def feed[a: Alphabet, p: Padding](mut self, chunk: Span[UInt8, _], mut out: String) -> Int:
        var start = out.byte_length()
        var qb = quantum_bytes[a]()
        for i in range(len(chunk)):
            self.carry[self.count] = chunk[i]
            self.count += 1
            if self.count == qb:
                var sp = Span(self.carry)
                encode_full_bytes[a](sp[0:qb], out)
                self.count = 0
        return out.byte_length() - start

    # finish — flush the retained partial quantum (with padding if REQUIRED);
    # returns the number of encoded characters appended.
    def finish[a: Alphabet, p: Padding](mut self, mut out: String) -> Int:
        var start = out.byte_length()
        if self.count > 0:
            var sp = Span(self.carry)
            encode_partial[a, p](sp[0:self.count], out)
            self.count = 0
        return out.byte_length() - start


# encode_all — one-shot encode of an arbitrary byte span.
def encode_all[a: Alphabet, p: Padding](input: Span[UInt8, _], mut out: String):
    var qb = quantum_bytes[a]()
    var n = len(input)
    var i = 0
    while i + qb <= n:
        encode_full_bytes[a](input[i:i + qb], out)
        i += qb
    if i < n:
        encode_partial[a, p](input[i:n], out)


# ---------------------------------------------------------------------------
# Decoding state machine (shared by one-shot and streaming)
# ---------------------------------------------------------------------------

# valid_remainder — is a partial quantum of `r` symbols structurally possible?
def valid_remainder[a: Alphabet](r: Int) -> Bool:
    return r == 2 or r == 4 or r == 5 or r == 7


# DecodeState — the sub-quantum carry plus bookkeeping needed to reproduce
# one-shot error kinds and positions in the streaming decoder.
struct DecodeState:
    var carry: Array[UInt8, 8]
    var count: Int          # validated real symbols held for the current quantum
    var pad_count: Int      # '=' symbols seen for the current quantum
    var quantum_start: Int  # original-stream index where the current quantum began
    var last_pos: Int       # original-stream index of the most recent real symbol
    var stream_ended: Bool  # a padded quantum completed the logical stream
    var total: Int          # original-stream bytes consumed so far (streaming base)

    def __init__(out self):
        self.carry = Array[UInt8, 8](fill=0)
        self.count = 0
        self.pad_count = 0
        self.quantum_start = 0
        self.last_pos = 0
        self.stream_ended = False
        self.total = 0

    # feed_chunk — the streaming entry: process a chunk at the cumulative stream
    # offset and advance the consumed-byte count.
    def feed_chunk[
        a: Alphabet,
        pm: PaddingMode,
        ws: Whitespace,
    ](mut self, chunk: Span[UInt8, _], mut out: List[UInt8]) raises Base32Error -> Int:
        var start = len(out)
        self.process[a, pm, ws](chunk, self.total, True, out)
        self.total += len(chunk)
        return len(out) - start

    # emit_group — decode `count` held symbol values into whole bytes. When
    # `strict_trailing` is set, non-zero unused trailing bits raise
    # INVALID_SYMBOL at `pos`.
    def emit_group[a: Alphabet](mut self, count: Int, pos: Int, strict_trailing: Bool, emit: Bool, mut out: List[UInt8]) raises Base32Error:
        var bps = bits_per_symbol[a]()
        var total = count * bps
        var nbytes = total // 8
        var acc = 0
        for k in range(count):
            acc = (acc << bps) | Int(self.carry[k])
        if strict_trailing:
            var leftover = total - nbytes * 8
            if leftover > 0:
                var mask = (1 << leftover) - 1
                if (acc & mask) != 0:
                    raise Base32Error(ErrorKind.INVALID_SYMBOL, pos)
        if emit:
            for k in range(nbytes):
                var shift = total - 8 * (k + 1)
                out.append(UInt8((acc >> shift) & 0xFF))

    # process — consume one chunk. `base` is the number of original-stream bytes
    # before this chunk, so positions stay cumulative for streaming. A chunk
    # boundary is NOT end of stream: an incomplete padding run at the end of a
    # chunk is RETAINED (feed must not fail on a valid prefix), and only `finish`
    # decides whether the run was completed. A real symbol following a padding
    # symbol is still an error here, because padding is terminal.
    def process[
        a: Alphabet,
        pm: PaddingMode,
        ws: Whitespace,
    ](mut self, chunk: Span[UInt8, _], base: Int, emit: Bool, mut out: List[UInt8]) raises Base32Error:
        var qs = quantum_syms[a]()
        var n = len(chunk)
        for i in range(n):
            var pos = base + i
            var b = chunk[i]
            if self.stream_ended:
                if ws == Whitespace.IGNORE and is_ws(b):
                    continue
                raise Base32Error(ErrorKind.INVALID_PADDING, self.quantum_start)
            if is_ws(b):
                if ws == Whitespace.IGNORE:
                    continue
                raise Base32Error(ErrorKind.INVALID_SYMBOL, pos)
            if b == UInt8(61):  # '='
                if self.count == 0 and self.pad_count == 0:
                    raise Base32Error(ErrorKind.INVALID_PADDING, self.quantum_start)
                self.pad_count += 1
                var required = qs - self.count
                if self.pad_count > required:
                    raise Base32Error(ErrorKind.INVALID_PADDING, self.quantum_start)
                if self.pad_count == required:
                    # A complete padding run only closes a structurally possible
                    # remainder; padding cannot rescue an impossible symbol count
                    # (base32 "A=======", "AAA=====", "AAAAAA==").
                    if not valid_remainder[a](self.count):
                        raise Base32Error(ErrorKind.INVALID_LENGTH, self.quantum_start)
                    # Trailing-bit canonicality is only enforced under STRICT.
                    self.emit_group[a](self.count, self.last_pos, pm == PaddingMode.STRICT, emit, out)
                    self.stream_ended = True
                    self.count = 0
                    self.pad_count = 0
                    self.quantum_start = pos + 1
                continue
            # A real symbol.
            if self.pad_count > 0:
                raise Base32Error(ErrorKind.INVALID_PADDING, self.quantum_start)
            var v = dec_value[a](b)
            if v < 0:
                raise Base32Error(ErrorKind.INVALID_SYMBOL, pos)
            # Validate before mutating the carry (carry atomicity).
            self.carry[self.count] = UInt8(v)
            self.count += 1
            self.last_pos = pos
            if self.count == qs:
                self.emit_group[a](self.count, self.last_pos, False, emit, out)
                self.count = 0
                self.quantum_start = pos + 1
        # A chunk boundary is not end of stream: an incomplete padding run is
        # retained here and validated by `finish`.
        return

    # finish — validate and flush the retained remainder at true end of stream,
    # mirroring one-shot `decode`. It raises INVALID_PADDING for an incomplete
    # padding run, INVALID_LENGTH for a structurally impossible remainder, and
    # completes a valid partial quantum (TOLERANT without padding, or a completed
    # run already emitted by `process`).
    def finish[a: Alphabet, pm: PaddingMode](mut self, emit: Bool, mut out: List[UInt8]) raises Base32Error -> Int:
        var start = len(out)
        if self.stream_ended:
            return 0
        if self.pad_count > 0:
            # A padding run that never completed by end of stream.
            raise Base32Error(ErrorKind.INVALID_PADDING, self.quantum_start)
        var r = self.count
        if r == 0:
            return 0
        if not valid_remainder[a](r):
            raise Base32Error(ErrorKind.INVALID_LENGTH, self.quantum_start)
        if has_padding[a]() and pm == PaddingMode.STRICT:
            raise Base32Error(ErrorKind.INVALID_PADDING, self.quantum_start)
        self.emit_group[a](r, self.last_pos, pm == PaddingMode.STRICT, emit, out)
        self.count = 0
        return len(out) - start


# ---------------------------------------------------------------------------
# One-shot decode and validate
# ---------------------------------------------------------------------------

# decode_into_core — decode into a caller-owned list; complete quanta decoded
# before an error stay appended (partial commit).
def decode_into_core[
    a: Alphabet,
    pm: PaddingMode,
    ws: Whitespace,
](input: Span[UInt8, _], mut result: List[UInt8]) raises Base32Error -> Int:
    var st = DecodeState()
    var start = len(result)
    st.process[a, pm, ws](input, 0, True, result)
    _ = st.finish[a, pm](True, result)
    return len(result) - start


# is_valid_core — allocation-free validity predicate: it runs the full decode
# validation with output emission switched off, so no decoded bytes are built.
def is_valid_core[
    a: Alphabet,
    pm: PaddingMode,
    ws: Whitespace,
](input: Span[UInt8, _]) -> Bool:
    var st = DecodeState()
    var sink = List[UInt8]()
    try:
        st.process[a, pm, ws](input, 0, False, sink)
        _ = st.finish[a, pm](False, sink)
        return True
    except e:
        return False
