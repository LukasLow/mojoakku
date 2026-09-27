# bit research: Elixir

Scope note: Elixir runs on the BEAM, so the bit/bitstring machinery is *Erlang's*;
Elixir supplies the `<<>>` syntax sugar, the `Bitwise` module and the binary
comprehension. Where the primitive lives in Erlang, that is stated explicitly.
"Elixir" docs and "Erlang/OTP" docs are cited separately.

## 1. Standard library support

**Scalar bit functions (Elixir).** `Bitwise` is "a set of functions that perform
calculations on bits" and provides exactly `band/2`, `bor/2`, `bxor/2`, `bnot/1`,
`bsl/2`, `bsr/2`, plus the operators `&&&/2`, `|||/2`, `<<</2`, `>>>/2`
(<https://hexdocs.pm/elixir/Bitwise.html>). Key properties stated there:
- "All bitwise functions work only on integers, otherwise an `ArithmeticError` is
  raised."
- "All functions in this module are inlined by the compiler."
- "All bitwise functions can be used in guards" (example uses `Bitwise.band(int, 1)`
  in a guard).
That guard/inline property means the scalar layer is not library code but VM
instructions reached from user code.

**Scalar bit functions (Erlang).** The same six operations exist as Erlang
operators in the `Arithmetic Expressions` table: `bnot` (unary), `band`, `bor`,
`bxor`, `bsl`, `bsr`, all with argument type `Integer`
(<https://www.erlang.org/doc/system/expressions.html>). They are listed among the
auto-imported BIFs/operators of the `erlang` module
(<https://www.erlang.org/doc/apps/erts/erlang.html>).

**Bit syntax — the core primitive.** Erlang's bit syntax "operates on bit
strings. A bit string is a sequence of bits ordered from the most significant bit
to the least significant bit." Each element is a *segment* with the general form
`Value:Size/TypeSpecifierList`; "The segments are ordered left to right from the
most significant bit to the least significant bit of the bit string"
(<https://www.erlang.org/doc/system/expressions.html>). The same construct exists
in Elixir as the `<<>>/1` special form
(<https://hexdocs.pm/elixir/1.20.4/Kernel.SpecialForms.html>).

Segment type specifiers (Erlang): `Type = integer | float | binary | bytes |
bitstring | bits | utf8 | utf16 | utf32`; `Signedness = signed | unsigned`;
`Endianness = big | little | native`; `Unit = unit:IntegerLiteral` in range 1–256
(<https://www.erlang.org/doc/system/expressions.html>). Elixir documents the same
nine types plus the modifiers `signed`/`unsigned`, `little`/`big`/`native`
(<https://hexdocs.pm/elixir/1.20.4/Kernel.SpecialForms.html>).

**Binaries vs bitstrings.** "A bit string with a length that is a multiple of 8
bits is known as a *binary*" (Erlang, <https://www.erlang.org/doc/system/data_types.html>);
"A binary is a bitstring where the number of bits is divisible by 8"
(Elixir, <https://hexdocs.pm/elixir/binaries-strings-and-charlists.html>).

**No bit-set / bitset container in stdlib.** Elixir's standard set type is
`MapSet`, a hash-map-backed set (<https://elixir.hexdocs.pm/main/MapSet.html>) —
it is not bit-packed. Erlang/OTP ships three general set modules, `sets`,
`ordsets` and `gb_sets` — all value-set implementations with no bit packing
(`sets` is opaque, `ordsets` is an ordered list, `gb_sets` is a general balanced
tree) (<https://www.erlang.org/doc/apps/stdlib/sets.html>,
<https://www.erlang.org/doc/apps/stdlib/ordsets.html>,
<https://www.erlang.org/doc/apps/stdlib/gb_sets.html>). No `BitSet` type exists
in either stdlib.
(Assessment: derived from the absence of any `BitSet`/bitset module in the
stdlib module index, and from every bit-packed container being a Hex package in
§2.)

**No bitfield `get_bits`/`set_bits` helper.** Arbitrary `[hi:lo]` extraction is
done with bit-syntax matching; there is no named function. The Erlang docs use
the IP header as the canonical example `<<?IP_VERSION:4, HLen:4, SrvcType:8,
TotLen:16, ...>>` (<https://www.erlang.org/doc/system/bit_syntax.html>).

**Byte-oriented helpers.** `:binary` "provides functions for manipulating
byte-oriented binaries": `at/2`, `part/2,3`, `bin_to_list/1,2,3`, `decode_unsigned/2`,
`encode_unsigned/2`, `split/3`, `match/3`, `copy/1,2`, `encode_hex/2`, `decode_hex/1`
(<https://www.erlang.org/doc/apps/stdlib/binary.html>). Crucially it "handles
byte-oriented data. For bitstrings that are not binaries … a `badarg` exception is
raised." `:erlang` adds the BIFs `bit_size/1` ("size in bits") and `byte_size/1`
("number of bytes needed to contain `Bitstring`") (<https://www.erlang.org/doc/apps/erts/erlang.html>).

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | Model |
| --- | --- | --- | --- | --- |
| `bitmap` | hashd | 37★, MIT | MIT | fixed-size bit array, two impls (Binary + Integer) |
| `bitset` | kminwoog | v0.2.1 (Mar 2019), 5 001 all-time downloads | MIT | fixed-size N-bit, C++ `std::bitset` style |
| `nat_set` | hilverd | v0.0.1, 5★, Apache-2.0 | Apache-2.0 | set of natural numbers as one arbitrary-size integer |
| `bit_field_set` | gausby | v1.2.3 (May 2019), 20 445 all-time downloads | Apache-2.0 | fixed-size bit-flag set for peer-to-peer state (BitTorrent) |
| `abit` | preciz | v1.0.0 (Aug 2026), 698 299 all-time downloads, 17 versions | MIT | mutable bit array / N-bit counters over `:atomics` |

Sources: <https://github.com/hashd/bitmap-elixir>,
<https://hex.pm/packages/bitset>, <https://hex.pm/packages/nat_set>,
<https://hex.pm/packages/bit_field_set>, <https://hex.pm/packages/abit>.
Erlang's `:atomics` itself is part of OTP, not a package
(<https://www.erlang.org/doc/apps/erts/atomics.html>).

Notes on maturity from the sources: `bitset` and `bit_field_set` were last
updated in 2019 (Hex package pages above); `abit` is actively maintained (v1.0.0,
Aug 2026). (Assessment: derived from the "Last Updated" fields on the Hex pages.)

## 3. Exposed APIs

**Bitwise (Elixir)** — full name/arity list (<https://hexdocs.pm/elixir/Bitwise.html>):
`band/2`, `bor/2`, `bxor/2`, `bnot/1`, `bsl/2`, `bsr/2`, `&&&/2`, `|||/2`,
`<<</2`, `>>>/2`. All `integer() -> integer()` (binary ones `integer(), integer()
-> integer()`). `bnot(2) == -3`; `bsl(1, -2) == 0`; `bsr(1, -2) == 4` (negative
shift counts reverse direction).

**`Bitset`** (<https://hexdocs.pm/bitset/Bitset.html>, source
<https://github.com/kminwoog/bitset/blob/master/lib/bitset.ex>) — a struct
`%Bitset{data: bitstring, size: integer}`:
`new/1`, `new/2`, `size/1`, `test?/2`, `all?/1`, `any?/1`, `none?/1`, `count/1`,
`set/1`, `set/3` (`set(bitset, pos, bit \\ 1)`), `reset/1`, `reset/2`, `flip/1`,
`flip/2`, `reverse/1`, `to_string/2`, `to_data/1`, `to_bytes/1` (since 0.2.1),
`to_binary/1` (deprecated → `to_bytes/1`). Internally `test?/2` pattern-matches
`<<prefix::size(pos), bit::size(1), rest::bits>>`; `count/1` is
`for(<<bit::1 <- bitset.data>>, do: bit) |> Enum.sum()`; `to_bytes/1` reverses
every 8-bit byte (bit reversal) before emitting.

**`Bitmap`** (<https://github.com/hashd/bitmap-elixir>) — `Bitmap.new(size)`,
`Bitmap.set`, `Bitmap.unset`, `Bitmap.set?`, `Bitmap.toggle`, `Bitmap.at`,
`Bitmap.toggle_all`, `Bitmap.unset_all`, `Bitmap.set_all`, `Bitmap.to_string`.
Two backends, `Bitmap.Binary` and `Bitmap.Integer`, "Integers are the default due
to clear performance superiority based on benchmarks". README: "Index is zero
based". Values are shown as bitstrings: `Bitmap.new(5) => <<0::size(5)>>`,
`set(bitmap, 2) => <<4::size(5)>>` (i.e. index 0 = LSB).

**`NatSet`** (<https://hexdocs.pm/nat_set/NatSet.html>) — `new/0`, `new/1`,
`new/2`, `put/2`, `delete/2`, `member?/2`, `size/1`, `union/2`, `intersection/2`,
`difference/2`, `disjoint?/2`, `subset?/2`, `equal?/2`, `to_list/1`, `to_stream/1`.
"Stored using integers, in which each bit represents an element of the set. As
Elixir/Erlang uses arbitrary-sized integers, the memory used … grows dynamically
as needed." Implements `Enumerable` and `Collectable`.

**`BitFieldSet`** (<https://github.com/gausby/bit_field_set>, README) —
`new!(binary, size_in_bits)`, `put(set, index)`, `delete(set, index)`,
`to_binary(set)`. Example: `new!(<<0b00110001>>, 8) => #BitFieldSet<[2, 3, 7]>`,
then `to_binary` of `[0, 2, 7]` gives `<<161>>`. 0b10100001 = 161 confirms
**bit index 0 = MSB (network bit order)**. (Assessment: derived from the README
example arithmetic.)

**`Abit`** (<https://hexdocs.pm/abit/Abit.html>) — bit array over `:atomics`:
`bit_at/2`, `set_bit_at/3`, `toggle_bit_at/2`, `clear/1`, `bit_count/1`,
`set_bits_count/1`, `bit_position/1`, `to_list/1`, `union/2`, `intersect/2`,
`difference/2`, `symmetric_difference/2`, `invert/1`, `hamming_distance/2`.
`union`/`intersect`/`difference`/`symmetric_difference` "Mutates and returns
`ref_a`"; mismatched sizes "Raises `ArgumentError`". `Abit.Counter` provides
N-bit counters; `Abit.Bitmask` provides bitmask helpers.
`:atomics` primitives used underneath: `new/2`, `get/2`, `put/3`, `add/3`,
`sub/3`, `add_get/3`, `sub_get/3`, `exchange/3`, `compare_exchange/4`, `info/1` —
"Atomics are 64 bit integers … Indexes into atomic arrays are one-based"
(<https://www.erlang.org/doc/apps/erts/atomics.html>).

## 4. Error representation

- **Bad argument → exception, not a value.** "All BIFs fail with reason `badarg`
  if they are called with arguments of an incorrect type"
  (<https://www.erlang.org/doc/apps/erts/erlang.html>). Every `:binary` function
  on a non-binary bitstring raises `badarg`
  (<https://www.erlang.org/doc/apps/stdlib/binary.html>). Elixir `Bitwise` raises
  `ArithmeticError` for non-integers (<https://hexdocs.pm/elixir/Bitwise.html>).
- **Binary match failure → match error.** Pattern matching a bitstring that does
  not fit raises; e.g. `<<0,1,x>> = <<0,1,2,3>>` → `** (MatchError)`
  (<https://hexdocs.pm/elixir/binaries-strings-and-charlists.html>); in Erlang
  terms "a `badmatch` run-time error occurs"
  (<https://www.erlang.org/doc/system/expressions.html>).
- **Construction overflow is silent (truncation), not an error** — see §8.
- **Community libraries mix two idioms.** `Abit` returns `:ok` on mutation
  (`set_bit_at/3`, `toggle_bit_at/2`) and raises `ArgumentError` on size mismatch
  (<https://hexdocs.pm/abit/Abit.html>). `BitFieldSet` offers `new!` (bang = raises)
  (<https://github.com/gausby/bit_field_set>); a non-bang `new` presumably returns
  `{:ok, _}` / `{:error, _}` (Assessment: derived from the bang convention, the
  non-bang variant itself was not fetched). There is **no `Result`/`Either` type**
  for bit operations — errors are exceptions.

## 5. Ownership semantics

- **Everything is immutable; there is no ownership transfer.** "Erlang uses
  *single assignment*, that is, a variable can only be bound once"
  (<https://www.erlang.org/doc/system/expressions.html>). All the Elixir community
  containers (`Bitset`, `Bitmap.Integer`) return *new* structs from `set`/`reset`/
  `flip` (<https://github.com/kminwoog/bitset/blob/master/lib/bitset.ex>).
- **Binaries are reference-counted and shared.** "The binary object can be
  referenced by any number of ProcBins from any number of processes. The object
  contains a reference counter" (<https://www.erlang.org/doc/efficiency_guide/binaryhandling.html>).
  Heap binaries up to 64 bytes are stored on the process heap and copied on GC /
  on message send; larger refc binaries are shared.
- **Sub-binaries create retention.** "A *sub binary* is a reference into a part of
  another binary … the actual binary data is never copied"; `binary:part/3` and
  `binary:split/3` results "are all referencing `Subject`. This means … that
  `Subject` cannot be garbage collected until the results … are no longer
  referenced" (<https://www.erlang.org/doc/apps/stdlib/binary.html>).
  `binary:copy/1` and `referenced_byte_size/1` exist explicitly to break that
  reference. This is the BEAM's answer to "who owns/frees the buffer": the runtime,
  refcounted, with an explicit copy escape hatch.
- **`:atomics` are the mutable exception.** "Atomics are not tied to the current
  process and are automatically garbage collected when they are no longer
  referenced" (<https://www.erlang.org/doc/apps/erts/atomics.html>). `Abit`
  deliberately wraps them for shared mutable bit arrays
  (<https://hexdocs.pm/abit/Abit.html>).
- **Binary append optimisation** (`<<Acc/binary, H>>`) is documented as the
  efficient way to grow a binary; prepending copies every time
  (<https://www.erlang.org/doc/efficiency_guide/binaryhandling.html>).

## 6. Blocking / non-blocking

Not applicable in the socket sense: every function here is a synchronous, pure
(or atomics-mutating) computation with no I/O and no blocking calls. Concurrency
runs through the BEAM's processes; the only shared-mutable bit structure is
`:atomics`, which "utilizes only atomic hardware instructions without any software
level locking, which makes it very efficient for concurrent access"
(<https://www.erlang.org/doc/apps/erts/atomics.html>). `compare_exchange/4`
provides lock-free CAS. Message passing between processes copies heap binaries
(≤64 bytes) and shares large refc binaries
(<https://www.erlang.org/doc/efficiency_guide/binaryhandling.html>).

## 7. Width and ordering model

**Integers: arbitrary precision (bignum).** Erlang has no fixed machine width for
integer arithmetic; e.g. `16#4865_316F_774F_6C64` evaluates to
`5216630098191412324` (<https://www.erlang.org/doc/system/data_types.html>), and
`NatSet` states outright that "Elixir/Erlang uses arbitrary-sized integers"
(<https://hexdocs.pm/nat_set/NatSet.html>). Consequence: the logical operators
behave as if the value were two's complement with *infinitely many* leading bits
— `bnot(2) == -3` (<https://hexdocs.pm/elixir/Bitwise.html>). (Assessment: derived
from `bnot/1`'s documented result combined with unbounded integers.)
There is a hard ceiling: `1 bsl (1 bsl 64)` raises "a system limit has been
reached" (<https://www.erlang.org/doc/system/expressions.html>).

**Bitstring order: canonical MSB-first.** "A bit string is a sequence of bits
ordered from the most significant bit to the least significant bit"; segments run
left to right from MSB to LSB (<https://www.erlang.org/doc/system/expressions.html>).

**Sizes/units/defaults** (Erlang): integer size default 8, unit 1; float size
default 64, unit 1; `binary`/`bitstring` default size = whole value, unit 8 for
`binary`, 1 for `bitstring`. Default signedness `unsigned`, default endianness
`big` (<https://www.erlang.org/doc/system/bit_syntax.html>). Elixir documents the
same defaults and the `::8*4` shortcut for `size(8)-unit(4)`
(<https://hexdocs.pm/elixir/1.20.4/Kernel.SpecialForms.html>).

**Signedness only matters for matching.** "signedness only matters for matching"
(Erlang, <https://www.erlang.org/doc/system/bit_syntax.html>); Elixir shows the
same: `<<int::integer>> = <<-100>>` binds `156`, while
`<<int::integer-signed>> = <<-100>>` binds `-100`
(<https://hexdocs.pm/elixir/1.20.4/Kernel.SpecialForms.html>).

**Endianness is byte-level, not bit-level.** "Endianness = `big` | `little` |
`native` — Specifies byte level (octet level) endianness (byte order). …
Endianness only matters when the Type is either `integer`, `utf16`, `utf32`, or
`float`" (<https://www.erlang.org/doc/system/expressions.html>). The docs'
example `<<16#1234:16/little>> = <<16#3412:16>> = <<16#34:8, 16#12:8>>` and
`<<16#123:12/little>> = <<2:4, 3:4, 1:4>>` show it reorders *bytes*, not
individual bits. Consequence: there is **no LSB-first bit-order flag**; LSB-first
bit order is expressed by reversing/ordering segments explicitly, as `Bitset`'s
`reverse/1` and `reverse_byte/2` do
(<https://github.com/kminwoog/bitset/blob/master/lib/bitset.ex>). (Assessment:
derived from the byte-level definition of endianness plus the `Bitset` source.)

**Index-to-bit mapping differs per library** — the sharpest cross-model signal:
- `Bitmap`: "Index is zero based"; `new(5) => <<0::size(5)>>`,
  `set(…, 2) => <<4::size(5)>>` → **index 0 = LSB**
  (<https://github.com/hashd/bitmap-elixir>).
- `Abit`: `bit_position(0) = {1, 0}`; with word value 3, `bit_at(0)=1`,
  `bit_at(1)=1`, `bit_at(2)=0` → **bit index 0 = LSB of the 64-bit word**
  (<https://hexdocs.pm/abit/Abit.html>).
- `BitFieldSet`: `new!(<<0b00110001>>, 8) => [2, 3, 7]` →
  **bit index 0 = MSB (network bit order)**
  (<https://github.com/gausby/bit_field_set>).
- Bit syntax itself: **segment order = MSB-first**
  (<https://www.erlang.org/doc/system/expressions.html>).

**Binary comprehension is a bit-level iterator.** `for <<r::8, g::8, b::8 <-
pixels>>, do: {r, g, b}` walks the bitstring left-to-right in segments
(<https://hexdocs.pm/elixir/1.20.4/Kernel.SpecialForms.html>), and `:into` can
rebuild a bitstring: `for <<c <- " hello world ">>, c != ?\s, into: "", do: <<c>>`
→ `"helloworld"`.

## 8. Bounds, overflow and growth

**Construction silently truncates.** "if the size `N` of an integer segment is too
small to contain the given integer, the most significant bits of the integer are
silently discarded and only the `N` least significant bits are put into the bit
string. For example, `<<16#ff:4>>` will result in the bit string `<<15:4>>`"
(<https://www.erlang.org/doc/system/expressions.html>). Elixir repeats this:
`<<1>> == <<257>>` (<https://hexdocs.pm/elixir/binaries-strings-and-charlists.html>).

**Matching does not truncate — it fails.** A pattern whose size does not fit
raises (`MatchError`/`badmatch`); matching "fails if the size of `Dgram` is less
than `4*HLen`" (<https://www.erlang.org/doc/system/bit_syntax.html>).
So construction = mask, matching = require.

**Float and binary segments are strict.** A too-small float segment "an exception
is raised"; interpolating a bit string of size 1 into a `binary` segment (unit 8)
fails with "bad argument"; a `binary` interpolation shorter than the declared size
fails with "the value … is shorter than the size of the segment"
(<https://www.erlang.org/doc/system/expressions.html>).

**Shift amounts.** Negative right-hand counts reverse the direction:
`bsl(1, -2) == 0`, `bsr(1, -2) == 4`, `bsl(-1, -2) == -1`
(<https://hexdocs.pm/elixir/Bitwise.html>). Astronomically large counts hit the
VM system limit (see §7).

**Out-of-range indices.**
- `binary:at/2`: "If `Pos` >= `byte_size(Subject)`, a `badarg` exception is raised";
  `binary:part/3` likewise raises if the range leaves the binary
  (<https://www.erlang.org/doc/apps/stdlib/binary.html>).
- `Bitset.test?/2`/`set/3` destructure `<<prefix::size(pos), bit::1, rest::bits>>`,
  so `pos >= bit_size(data)` produces a match failure, not a friendly error
  (<https://github.com/kminwoog/bitset/blob/master/lib/bitset.ex>). (Assessment:
  derived from the source.)
- `:atomics` indices are one-based and bounded by the array arity; out-of-range is
  `badarg` (<https://www.erlang.org/doc/apps/erts/atomics.html>). `Abit.bit_position/1`
  maps a zero-based bit index to `{word, bit}` (examples `0→{1,0}`, `64→{2,0}`)
  (<https://hexdocs.pm/abit/Abit.html>).
- `BitFieldSet` index bounds are not shown in the README; `new!` suggests a bang
  (raising) constructor (<https://github.com/gausby/bit_field_set>).

**Growth policy — three different answers.**
- Fixed at creation: `Bitset.new(size)`, `Bitmap.new(5)`, `BitFieldSet.new!(…, 8)`,
  `:atomics.new(Arity, Opts)` (<https://hexdocs.pm/bitset/Bitset.html>,
  <https://github.com/hashd/bitmap-elixir>, <https://github.com/gausby/bit_field_set>,
  <https://www.erlang.org/doc/apps/erts/atomics.html>).
- Dynamic: `NatSet` "the memory used by a NatSet grows dynamically as needed"
  because it is one arbitrary-size integer
  (<https://hexdocs.pm/nat_set/NatSet.html>).
- `:atomics` "wrap around at overflow and underflow operations"
  (<https://www.erlang.org/doc/apps/erts/atomics.html>) — the counter layer wraps
  rather than raising.

**`byte_size` on a non-byte-aligned bitstring rounds up**: it returns "the number
of bytes needed to contain `Bitstring`" (<https://www.erlang.org/doc/apps/erts/erlang.html>).

## 9. Scalar functions, container type and bit-level I/O

The three layers are split as follows on the BEAM:

1. **Scalar bit functions — in the language/VM, not a library.** Elixir `Bitwise`
   (callable and inline, guard-safe) and the identical Erlang operators
   (<https://hexdocs.pm/elixir/Bitwise.html>,
   <https://www.erlang.org/doc/system/expressions.html>). There is no
   `pop_count`/`clz`/`ctz`/`rotate`/`bit_reverse` in the stdlib — those would be
   hand-rolled (the `Bitset` package hand-rolls reversal and counting:
   `count/1` uses a comprehension + `Enum.sum`; `reverse_byte/2` reverses each
   byte). (Assessment: derived from the complete `Bitwise` API list plus the
   hand-rolled helpers in the `Bitset` source.)

2. **Container type — absent from stdlib, supplied by Hex.** No `BitSet`;
   bit-packed containers are `bitmap`, `bitset`, `nat_set`, `bit_field_set`, `abit`
   (§2, §3). The two viable internal representations on the BEAM are (a) a
   bitstring/bitstring-backed struct (`Bitset`, `BitFieldSet`) and (b) an
   arbitrary-size integer used as the bit vector (`NatSet`, `Bitmap.Integer`,
   `bit_field_set`'s `to_binary` boundary). `Abit` adds (c) a mutable `:atomics`
   array for shared/concurrent use.

3. **Bit-level stream I/O — not a type; it is the bit syntax itself.** There is no
   `BitReader`/`BitWriter`: reading is bit-syntax pattern matching (with a size
   variable bound in the same pattern: `bar(<<Sz:8,Payload:Sz/binary-unit:8,Rest/binary>>)`
   <https://www.erlang.org/doc/system/bit_syntax.html>), iterating is the binary
   comprehension, and writing is the append-optimized accumulator
   `<<Acc/binary, H>>` (<https://www.erlang.org/doc/efficiency_guide/binaryhandling.html>).
   A `:binary` module supplies the byte-aligned fast paths
   (`part`, `at`, `decode_unsigned`) (<https://www.erlang.org/doc/apps/stdlib/binary.html>).
   `binary:decode_unsigned/2` / `encode_unsigned/2` are the endianness-aware
   integer↔bytes bridge (`<<169,138,199>>` → `11111111` big, `13077161` little).

## 10. Interesting design decisions

- **One mechanism for construction, matching and validation.** The same
  `Value:Size/TypeSpecifierList` grammar builds, parses and validates
  (<https://www.erlang.org/doc/system/expressions.html>). There is no separate
  `get_bits`/`set_bits`.
- **Size as a guard expression, and self-referential sizes.** Since OTP 23 `Size`
  may be a guard expression (`((Sz-1)*8)/binary`) and a variable bound earlier in
  the same pattern can size a later segment
  (<https://www.erlang.org/doc/system/bit_syntax.html>). This is what makes
  length-prefixed wire formats one-liners.
- **Construction truncates, matching fails** (§8) — a deliberate split between
  "pack the low bits" and "the data must fit".
- **Arbitrary bit length end to end.** "A Bin does not need to consist of a whole
  number of bytes"; the `binary` vs `bitstring` distinction, with `unit` as the
  alignment contract, is type-checked
  (<https://www.erlang.org/doc/system/bit_syntax.html>).
- **Endianness deliberately byte-scoped**, keeping bit order canonical MSB-first;
  LSB-first is an explicit reversal, not a mode (§7).
- **Bitwise ops are VM-inlined and guard-safe** (<https://hexdocs.pm/elixir/Bitwise.html>).
- **Bignum logical semantics**: `bnot(2) == -3`, so a mask is required to get a
  fixed-width complement (§7) — a real footgun that falls out of arbitrary width.
- **Negative shift counts reverse direction** instead of being an error
  (<https://hexdocs.pm/elixir/Bitwise.html>).
- **Efficient append-only binary building** with a documented optimisation and a
  documented set of operations that force copying
  (<https://www.erlang.org/doc/efficiency_guide/binaryhandling.html>).
- **Sub-binary sharing + `copy/1` + `referenced_byte_size/1`** as an explicit,
  measured memory-management story (<https://www.erlang.org/doc/apps/stdlib/binary.html>).
- **`Abit`'s atomics bit array** turns an immutable-language bitset into a
  lock-free shared structure, with `hamming_distance/2` and `set_bits_count/1`
  provided directly (<https://hexdocs.pm/abit/Abit.html>).
- **`NatSet`'s dual nature**: a set that is simultaneously an arbitrary-size
  integer and a full `Enumerable`/`Collectable`
  (<https://hexdocs.pm/nat_set/NatSet.html>).
- **`BitFieldSet`'s MSB-first index** matching network bit order, with a single
  `to_binary/1` boundary that materialises wire bytes
  (<https://github.com/gausby/bit_field_set>).
- **Two coexisting index conventions** in one ecosystem (LSB-first in `Bitmap`/
  `Abit`, MSB-first in `BitFieldSet`/bit syntax) — users must be told which.

## 11. Decisions NOT to copy

- **Arbitrary-precision integer semantics.** `bnot(2) == -3` and unbounded
  `bsl`/`bsr` cannot map to fixed-width Mojo integers; copying the operator
  semantics verbatim would produce surprising results. Mojo needs an explicit
  width and an explicit mask. (Assessment: derived from
  <https://hexdocs.pm/elixir/Bitwise.html> and
  <https://www.erlang.org/doc/system/expressions.html>.)
- **Silent truncation without a diagnostic.** `<<16#ff:4>> == <<15:4>>` and
  `<<1>> == <<257>>` hide bugs; Mojo should not silently drop high bits in a
  public `set_bits` (§8 sources). (Assessment: derived from those sources.)
- **`badarg`/`badmatch`-everywhere + bang/non-bang mixing.** A public MojoAkku
  API should not mix exceptions, `:ok` returns (`Abit`) and `{:ok, _} | {:error, _}`
  (`BitFieldSet`) for the same class of failure; one `raises` contract is
  preferable. (Assessment: derived from §4 sources.)
- **Storing `size` separately from `data` and computing set-all with
  `:math.pow`/`trunc`.** `Bitset.set/1` uses `trunc(:math.pow(2, size)) - 1`, a
  float path that is wrong past 2^53; and `reverse_byte/2` re-implements byte
  reversal bit by bit. Do not copy these as-is.
  (<https://github.com/kminwoog/bitset/blob/master/lib/bitset.ex>)
- **Mutable `:atomics` bit arrays returning `:ok`.** Loses value semantics and
  aliasing predictability; not a good default for a Mojo library whose selling
  point is predictability. (<https://hexdocs.pm/abit/Abit.html>)
- **O(n) bit-by-bit recursion over a bitstring for fixed-size bitsets.**
  `Bitset.count/1` builds an intermediate list
  (<https://github.com/kminwoog/bitset/blob/master/lib/bitset.ex>); word-wise
  popcount is the model to keep instead.
- **Relying on a byte-level endianness switch to express bit order.** It is a
  repeated source of confusion (§7); MojoAkku should name the bit order directly.
  (Assessment: derived from the Erlang endianness definition.)

## 12. Ideas fitting Mojo

- **Compile-time width parameter.** Mojo's `comptime`/parameter syntax can carry
  the width in the type, giving `BitSet[W: Int]` with the fixed width known at
  compile time, instead of the runtime `size` field the BEAM packages must carry
  (`Bitset.size`, `Bitmap.new(size)`, `BitFieldSet.new!(…, size)`)
  (<https://hexdocs.pm/bitset/Bitset.html>, <https://github.com/hashd/bitmap-elixir>,
  <https://github.com/gausby/bit_field_set>).
- **Explicit bit order as an enum.** Provide `BitOrder.MSB_FIRST` / `LSB_FIRST`
  (or `msb_first`/`lsb_first`) for the bit-level reader/writer, modelled after the
  contradictory ecosystem conventions (`Abit` LSB, `BitFieldSet` MSB) — and never
  as a silent byte-endianness side effect (<https://hexdocs.pm/abit/Abit.html>,
  <https://github.com/gausby/bit_field_set>).
- **`get_bits(value, hi, lo)` / `set_bits(value, hi, lo, v)` as the named pair**
  that the BEAM only expresses through `<<_::lo, field::(hi-lo+1), _/bitstring>>`
  matching (<https://www.erlang.org/doc/system/bit_syntax.html>) — this is exactly
  the `std.bit` gap named in the MojoAkku README.
- **An explicit cursor type for bit-level I/O.** The BEAM hides the read position
  in an opaque match context and the write position in an append-optimised binary
  (<https://www.erlang.org/doc/efficiency_guide/binaryhandling.html>); Mojo has no
  such runtime magic, so a `BitReader`/`BitWriter` struct with an explicit
  `bit_offset` and `var inout`/`inout self` methods is the honest translation.
- **Copy the size-variable idiom**: allow the size of one field to come from a
  previously read field (length-prefixed records), as in
  `<<Sz:8, Payload:((Sz-1)*8)/binary, Rest/binary>>`
  (<https://www.erlang.org/doc/system/bit_syntax.html>).
- **Copy the split "mask on write, raise on read" contract** but make it explicit
  in the API name (e.g. `truncate_pack` vs `expect_bits`) rather than implicit
  truncation (§8).
- **Borrow `Abit`'s derived operations** as value-returning functions:
  `intersect`, `union`, `difference`, `symmetric_difference`, `hamming_distance`,
  `cardinality`/`set_bits_count`, `invert` (needs signed width)
  (<https://hexdocs.pm/abit/Abit.html>).
- **Borrow `NatSet`'s collection protocol idea**: iterate set bits (ctz-loop in
  Mojo instead of `to_stream`) and expose `to_list`/iteration in ascending order
  (<https://hexdocs.pm/nat_set/NatSet.html>).
- **Value semantics for logical ops** is the natural Mojo model: `var`/`borrowed`/
  `inout` can give the set-operation API without the BEAM's copy-per-`set`
  behaviour, and `raises` can carry the `ArgumentError`-style size-mismatch
  contract of `Abit` (<https://hexdocs.pm/abit/Abit.html>).
- **Wrap, don't rebuild, `std.bit`.** The BEAM hand-rolls popcount/reverse
  because it has no primitives (`Bitset.count/1`, `reverse_byte/2`); Mojo's
  `std.bit` already ships `bit_not`, `bit_reverse`, `bit_width`, `byte_swap`,
  `count_leading_zeros`, `count_trailing_zeros`, `log2_ceil`, `log2_floor`,
  `next_power_of_two`, `prev_power_of_two`, `pop_count`, `rotate_bits_left`,
  `rotate_bits_right`, plus `mask.is_negative` and `mask.splat` — unstable by
  default — so MojoAkku should consume those and add only the container, the
  `[hi:lo]` bitfield pair and the bit-level stream. Source: `mojov1/stdlib/bit`,
  <https://mojolang.org/docs/std/bit/>.

## Sources

- Elixir `Bitwise` (v1.20.4): <https://hexdocs.pm/elixir/Bitwise.html>
- Elixir `Kernel.SpecialForms` `<<>>/1` (v1.20.4):
  <https://hexdocs.pm/elixir/1.20.4/Kernel.SpecialForms.html>
- Elixir "Binaries, strings, and charlists" (v1.20.4):
  <https://hexdocs.pm/elixir/binaries-strings-and-charlists.html>
- Erlang Bit Syntax (OTP 29.1.1): <https://www.erlang.org/doc/system/bit_syntax.html>
- Erlang Expressions / Bit Syntax Expressions (OTP 29.1.1):
  <https://www.erlang.org/doc/system/expressions.html>
- Erlang Data Types (OTP 29.1.1): <https://www.erlang.org/doc/system/data_types.html>
- Erlang `binary` module (OTP 29.1.1):
  <https://www.erlang.org/doc/apps/stdlib/binary.html>
- Erlang `erlang` module / BIF index (OTP 29.1.1):
  <https://www.erlang.org/doc/apps/erts/erlang.html>
- Erlang `atomics` module (OTP 29.1.1):
  <https://www.erlang.org/doc/apps/erts/atomics.html>
- Erlang Efficiency Guide, "Constructing and Matching Binaries" (OTP 29.1.1):
  <https://www.erlang.org/doc/efficiency_guide/binaryhandling.html>
- Erlang Deprecations (OTP 29.1.1): <https://www.erlang.org/doc/deprecations.html>
  (checked: `Bitwise`/the bitwise operators are not listed as deprecated)
- `bitmap` (hashd): <https://github.com/hashd/bitmap-elixir>
- `bitset` (kminwoog): <https://hex.pm/packages/bitset> ·
  <https://hexdocs.pm/bitset/Bitset.html> ·
  <https://github.com/kminwoog/bitset/blob/master/lib/bitset.ex>
- `nat_set` (hilverd): <https://hex.pm/packages/nat_set> ·
  <https://hexdocs.pm/nat_set/NatSet.html> ·
  <https://github.com/hilverd/nat-set-elixir>
- `bit_field_set` (gausby): <https://hex.pm/packages/bit_field_set> ·
  <https://github.com/gausby/bit_field_set>
- `abit` (preciz): <https://hex.pm/packages/abit> ·
  <https://hexdocs.pm/abit/Abit.html> · <https://github.com/preciz/abit>
- Elixir `MapSet`: <https://elixir.hexdocs.pm/main/MapSet.html>
