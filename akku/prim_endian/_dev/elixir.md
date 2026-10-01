# prim_endian research: elixir

Reference language: Elixir (v1.20.x docs) on the BEAM/Erlang runtime (OTP 29.x
docs). Elixir has no byte-order module of its own: endianness is a **language
feature** (Erlang bit syntax, exposed unchanged in Elixir through
`Kernel.SpecialForms.<<>>/1`) plus a handful of `:binary` (stdlib) and
`:erlang` (erts) BIFs.

# 1. Standard library support

- Endianness is handled by the **bit syntax**, not a library module. A binary
  segment has the general form `Value:Size/TypeSpecifierList`; the endianness
  specification can be `big`, `little`, or `native`, and **the default is
  `big`**. Source: https://www.erlang.org/doc/system/bit_syntax.html ("Defaults": "The default endianness is `big`."), and https://www.erlang.org/doc/system/expressions.html (Endianness = `big | little | native`).
- In Elixir the same feature is the special form `<<>>/1`; endianness is one of
  the segment modifiers. Elixir lists `little`, `big` (default) and `native` as
  the three modifiers, and states: "`native` is determined by the VM at startup
  and will depend on the host operating system." Source: https://hexdocs.pm/elixir/Kernel.SpecialForms.html (`<<>>/1` → "Endianness").
- Construction and matching share the syntax. `<<x::16>>` **constructs** a
  16-bit big-endian field; the matching form `<<x::16-little>> = bin`
  **decodes** a little-endian field. Source: https://hexdocs.pm/elixir/Kernel.SpecialForms.html (`<<>>/1` examples: `<<number::little-integer-size(16)>> = <<0, 1>>` → `number = 256`; `<<number::big-integer-size(16)>> = <<0, 1>>` → `number = 1`).
- `:binary` (Erlang/OTP stdlib, used from Elixir as `:binary`) provides
  `decode_unsigned/1,2` and `encode_unsigned/1,2`, accepting `big` or `little`
  (default `big`). Sources: https://www.erlang.org/doc/apps/stdlib/binary.html ; https://github.com/erlang/otp/blob/OTP-29.1.1/lib/stdlib/src/binary.erl (specs at L299–L367).
- `:erlang.system_info(endian)` returns the host byte order as `big` or
  `little`. Source (implementation): https://github.com/erlang/otp/blob/OTP-29.1.1/erts/emulator/beam/erl_bif_info.c (L3101–L3106: `am_endian` → `am_big`/`am_little`). See §9 for a documentation caveat.
- Elixir intentionally does not wrap Erlang stdlib: "Elixir discourages simply
  wrapping Erlang libraries in favor of directly interfacing with Erlang code."
  Source: https://hexdocs.pm/elixir/erlang-libraries.html.
- Names to use from Elixir: `:binary.decode_unsigned/2`,
  `:binary.encode_unsigned/2`, `:erlang.system_info/1` (`endian`),
  `:erlang.term_to_binary/1` / `:erlang.binary_to_term/1`, and the bit-syntax
  `<<>>` special form.

# 2. Relevant community libraries

- There is effectively **no community library for generic endianness**, because
  the language feature plus `:binary` already cover it. A Hex package search for
  "endian" returns exactly one package, `gleb128` (LEB128 little-endian base-128
  variable-length integers, Gleam), which is not a general byte-order library.
  Source: https://hex.pm/packages?search=endian&sort=downloads.
- Domain-specific libraries implement endianness handling internally when they
  read fixed binary formats. Example: `elixir-nx/safetensors` handles tensor
  endianness in `Safetensors.Shared`. Source: https://deepwiki.com/elixir-nx/safetensors/3.2-binary-processing-and-endianness (secondary; derived from the safetensors repo).
- `:crypto` and `:ssl` handle wire formats internally in big-endian order but do
  not expose a byte-order API. `(Assessment: derived from the OTP external term
  format and stdlib docs, §3 below.)`
- `GUESS:` no maintained, general-purpose "endianness" Hex package was found;
  the reason is that the built-in bit syntax is sufficient, so there is no gap
  for a library. No authoritative negative-source exists.

# 3. Exposed APIs

Bit-syntax endian modifiers (language-level; identical in Erlang and Elixir):

- `big` — big-endian (network order). Default when none is given.
- `little` — little-endian.
- `native` — host byte order, "resolved at load time, to be either big-endian or
  little-endian, depending on what is 'native' for the CPU that the Erlang
  machine is run on." Source: https://www.erlang.org/doc/system/bit_syntax.html (Segments).
- Modifiers are hyphen-separated and order-independent: `<<102::integer-native, rest::binary>>`, `<<102::native-integer, ...>>`, `<<102::unsigned-big-integer, ...>>`, `<<102::unsigned-big-integer-size(8), ...>>`, `<<102::unsigned-big-integer-8, ...>>` are all equivalent. Source: https://hexdocs.pm/elixir/Kernel.SpecialForms.html (`<<>>/1` → "Options").
- Size/unit: size in bits unless a `unit` multiplies it. Example from the docs,
  `X:4/little-signed-integer-unit:8`, is a 32-bit signed little-endian integer.
  Source: https://www.erlang.org/doc/system/bit_syntax.html.

`:binary` functions (exact specs):

- `decode_unsigned(Subject) -> non_neg_integer()` — equivalent to
  `decode_unsigned(Subject, big)`.
- `decode_unsigned(Subject, Endianness) -> non_neg_integer()` where
  `Endianness :: big | little`.
- `encode_unsigned(Unsigned) -> binary()` — equivalent to `(Unsigned, big)`.
- `encode_unsigned(Unsigned, Endianness) -> binary()` where
  `Endianness :: big | little`, producing "the smallest possible unsigned binary
  representation". Source: https://www.erlang.org/doc/apps/stdlib/binary.html.

`:erlang` / other:

- `erlang:system_info(endian) -> big | little`. Source: erl_bif_info.c L3101–L3106 (URL in §1).
- `erlang:term_to_binary/1,2` and `erlang:binary_to_term/1,2` — the external term
  format is big-endian throughout (integers, lengths, floats, indices). Source:
  https://www.erlang.org/doc/apps/erts/erl_ext_dist.html ("Signed 32-bit integer
  in big-endian format" for `INTEGER_EXT`; "big-endian" repeated for
  `NEW_PID_EXT`, `BINARY_EXT`, `NEW_FLOAT_EXT`, etc.).
- `erlang:decode_packet/3` — packet length headers are big-endian: "the order of
  the bytes is big-endian." Source: https://www.erlang.org/doc/apps/erts/erlang.html (`decode_packet/3`).
- There is **no** `byteswap`/`htonl`-style function in Erlang/Elixir. A byte swap
  is written as a match in one order plus a construction in the other.
  `(Assessment: derived from the absence of such a function in the `:binary`,
  `:erlang` and `Bitwise` docs.)`
- Elixir's `Bitwise` module is bit-twiddling only (`band`, `bor`, `bxor`, `bsl`,
  `bsr`, shifts/ops) and has no endian function. Source: https://hexdocs.pm/elixir/Bitwise.html.

# 4. Error representation

- `:binary` functions raise a `badarg` exception (Erlang error exception) on bad
  input. `encode_unsigned/2` documents: "If `Unsigned` is not a non-negative
  integer, a `badarg` exception is raised." The module is byte-oriented: "For
  bitstrings that are not binaries (does not contain whole octets of bits) a
  `badarg` exception is raised from any of the functions in this module." Source:
  https://www.erlang.org/doc/apps/stdlib/binary.html.
- **Binary construction** can fail with `badarg`: "Unlike when constructing lists
  or tuples, the construction of a binary can fail with a `badarg` exception."
  Source: https://www.erlang.org/doc/system/bit_syntax.html.
- In Elixir, constructing a binary with a value that needs a type tag but lacks
  one yields `ArgumentError` (error message "argument error"); `Bitwise` functions
  raise `ArithmeticError` on non-integers. Sources: https://hexdocs.pm/elixir/Kernel.SpecialForms.html (`<<>>/1` "At runtime, binaries need to be explicitly tagged as `binary`"); https://hexdocs.pm/elixir/Bitwise.html ("otherwise an `ArithmeticError` is raised").
- **Matching failure is not an exception.** If a binary pattern does not fit, the
  match simply does not succeed (function clause falls through / `case` clause is
  skipped). Source: https://www.erlang.org/doc/system/bit_syntax.html (matching semantics; the doc notes construction can fail with `badarg` but a non-matching pattern is a non-match).
- No `Result`/`Either` in the endian path. The BEAM idiom `{:ok, v}` / `{:error, reason}`
  is used at higher-level library boundaries, not by these primitives.
  `(Assessment: derived from the absence of such returns in the `:binary` docs.)`

# 5. Ownership semantics (adapted: value-returning vs. in-place; ownership of input/output)

- All conversion here is **value-returning and immutable**. Erlang terms are
  immutable; a function cannot mutate its argument. `decode_unsigned/2` returns a
  new integer; `encode_unsigned/2` returns a new binary; bit-syntax construction
  returns a new binary. Source: https://www.erlang.org/doc/apps/stdlib/binary.html ; https://www.erlang.org/doc/system/bit_syntax.html.
- There are **no out-parameters and no in-place variants** in the API. Source:
  the specs of `:binary` (`... -> non_neg_integer()` / `-> binary()`), URL above.
- Binaries are **reference-counted shared data**; decomposing a binary yields
  sub-binaries that *reference* the parent rather than copy it. `binary:part/3`
  and matching produce sub-binaries, and `binary:referenced_byte_size/1` /
  `binary:copy/1` exist to detect and detach a small sub-binary from a large
  parent: "If a binary references a larger binary (often called a subbinary), it
  can be useful to determine the size of the referenced binary... Copying a binary
  can help eliminate the reference to the original, potentially large, binary."
  Source: https://www.erlang.org/doc/apps/stdlib/binary.html.
- Consequence for MojoAkku study: there is no buffer ownership to manage at the
  API surface (values in / values out), but BEAM has a real **memory-retention**
  concern that a slice-based Mojo buffer API must also consider.
  `(Assessment: derived from the `referenced_byte_size`/`copy` docs.)`

# 6. Blocking / non-blocking

- **Not applicable.** Byte-order conversion and bit-syntax matching are pure,
  synchronous, CPU-bound operations with no I/O, no locks and no waiting.
  `(Assessment: derived from the specs in §3, which take values and return
  values and reference no processes, ports or I/O.)`
- The BEAM's concurrency model (preemptive processes, schedulers) is orthogonal:
  the operation runs in the calling process on the calling scheduler, but that is
  a property of the runtime, not of the endian API. `(Assessment: derived from
  the Erlang process/scheduler model; no endian-specific concurrency text
  exists.)`

# 7. IPv4 / IPv6 (adapted: which byte orders are represented, single abstraction)

- The syntax represents **all three** orders in one abstraction: `big`, `little`,
  `native` (default `big`). A single segment's `TypeSpecifierList` selects among
  them, and the same modifier set applies to both construction and matching.
  Source: https://www.erlang.org/doc/system/bit_syntax.html.
- **Network byte order is big-endian and is the default.** The canonical Erlang
  example parses an IPv4 header entirely with default (big-endian) fields:
  `<<4:4, HLen:4, SrvcType:8, TotLen:16, ID:16, ... SrcIP:32, DestIP:32, RestDgram/binary>>`.
  Source: https://www.erlang.org/doc/system/bit_syntax.html (Example 4, IP datagram).
- There is **no `network` alias** — the docs use "big-endian" and "network order"
  interchangeably; network order is simply `big`. Source: the term-format and
  packet docs, e.g. https://www.erlang.org/doc/apps/erts/erl_ext_dist.html (big-endian lengths/ids) and `decode_packet/3` in the `erlang` docs.
- `native` is the only host-dependent one, "resolved at load time". It is
  therefore not portable across machines, unlike `big`/`little`. Source:
  https://www.erlang.org/doc/system/bit_syntax.html.
- The `:binary` functions cover only **two** of the three (`big | little`) — they
  have no `native` option. Source: https://www.erlang.org/doc/apps/stdlib/binary.html. So the abstraction is *not* fully uniform: syntax has three orders, the `:binary` helpers have two.

# 8. Timeouts

- **Not applicable.** There is no blocking operation, therefore no timeout,
  deadline or cancellation surface for endian conversion. Source: none, and none
  is needed; the `:binary` specs (§3) contain no timeout or cancellation
  parameter. `(Assessment: derived from those signatures lacking any timeout
  argument.)`
- Cancellation at the BEAM level (killing a process) would abort the operation,
  but no endian API accepts or reports a cancellation handle. `(Assessment:
  derived from the BEAM process model.)`

# 9. TLS (adapted: how host native endianness is detected and reported)

- **Runtime query:** `erlang:system_info(endian)` returns `big` or `little`.
  Implementation chooses by a compile-time macro of the runtime build:
  `#if defined(WORDS_BIGENDIAN) return am_big; #else return am_little; #endif`.
  Source: https://github.com/erlang/otp/blob/OTP-29.1.1/erts/emulator/beam/erl_bif_info.c (L3101–L3106).
- **Automatic in the syntax:** the `native` modifier is "resolved at load time to
  be either big-endian or little-endian, depending on what is 'native' for the
  CPU." Source: https://www.erlang.org/doc/system/bit_syntax.html.
- Elixir adds no separate constant: "`native` is determined by the VM at startup
  and will depend on the host operating system." Source: https://hexdocs.pm/elixir/Kernel.SpecialForms.html.
- So detection is a **runtime query** (`system_info(endian)`) or **implicit**
  (`native`); there is no source-level compile-time constant exposed to the user.
  `(Assessment: derived from the two sources above.)`
- **Documentation caveat:** the `endian` argument of `system_info/1` is
  implemented (C source above) and appears in the `erlang` module's `-spec`
  enumeration, but the rendered OTP 29.1.1 "System Information" prose section
  does **not** list or describe `endian` (the section enumerates `c_compiler_used`,
  `wordsize`, …, without `endian`). `(Assessment: derived from the rendered
  `erlang` docs page + the erl_bif_info.c implementation.)` The `native`
  modifier, by contrast, is fully documented.

# 10. Interesting design decisions

1. **Endianness is syntax, not a function.** It is a per-segment modifier applied
   uniformly to construction and matching, rather than a `to_be`/`to_le` function
   pair. This is the unique BEAM signal. Source: https://www.erlang.org/doc/system/bit_syntax.html.
2. **Big-endian is the default** — the network-safe choice — so the common wire
   case needs no modifier. Source: https://www.erlang.org/doc/system/bit_syntax.html ("The default endianness is `big`.").
3. **`native` is resolved at load time**, not passed as a runtime value — it
   cannot be misused as a per-call argument. Source: same.
4. **Asymmetry between syntax and helpers:** the bit syntax knows `native`;
   `:binary.encode_unsigned/decode_unsigned` only know `big | little`. Source:
   https://www.erlang.org/doc/apps/stdlib/binary.html.
5. **Signedness only matters for matching**, not construction — the docs state
   "signedness only matters for matching". A subtle implicit rule. Source:
   https://www.erlang.org/doc/system/bit_syntax.html.
6. **`encode_unsigned` is minimal-length**, not fixed-width: it emits "the
   smallest possible unsigned binary representation". Convenient for varints,
   surprising for fixed wire fields. Source: https://www.erlang.org/doc/apps/stdlib/binary.html.
7. **The whole wire ecosystem is big-endian by specification** (external term
   format, packet headers), which makes `big` both the language default and the
   ecosystem contract. Source: https://www.erlang.org/doc/apps/erts/erl_ext_dist.html.
8. **Modifier list is order-independent and hyphen-separated**, letting
   `unsigned-big-integer-size(32)` and `integer-big-unsigned-32` mean the same.
   Source: https://hexdocs.pm/elixir/Kernel.SpecialForms.html.

# 11. Decisions NOT to copy

1. **Hyphen-separated modifier soup.** `X:4/little-signed-integer-unit:8` packs
   order, signedness, type and unit into one token stream; for a low-vision user
   this is hard to parse. MojoAkku should prefer explicit, named functions/types.
   Source of the syntax: https://www.erlang.org/doc/system/bit_syntax.html.
2. **Silent host-dependence of `native`.** It resolves to big/little at load
   time, so the same source produces non-portable bytes. Prefer explicit order in
   an API; expose host order only as an explicit query. Source:
   https://www.erlang.org/doc/system/bit_syntax.html.
3. **Signedness that only affects matching** is an implicit rule that surprises
   readers. Source: https://www.erlang.org/doc/system/bit_syntax.html.
4. **`encode_unsigned` minimal-length output** carries no width contract; a wire
   library wants explicit widths. Source: https://www.erlang.org/doc/apps/stdlib/binary.html.
5. **Match failure is silent non-match.** Great for control flow, wrong for an
   API-level "decode" that a caller expects to either succeed or raise. Mojo has
   `raises`; use it. `(Assessment: derived from the matching semantics in the bit
   syntax docs.)`
6. **Order-independent modifier lists** make two different spellings equivalent,
   which is friendly to the compiler but weak for greppability/readability.
   Source: https://hexdocs.pm/elixir/Kernel.SpecialForms.html.
7. **No `native` in the `:binary` helpers** creates a split mental model; an
   API should be uniform across the orders it claims to support. Source:
   https://www.erlang.org/doc/apps/stdlib/binary.html.

# 12. Ideas fitting Mojo

- **Endian as a compile-time value parameter.** Model the order as a value enum
  (`Endian.BIG`, `Endian.LITTLE`, `Endian.NATIVE`) passed as a `comptime`
  parameter so each instantiation is specialized with no runtime branch — this is
  the direct Mojo counterpart of the per-segment modifier. Fits Mojo value
  parameters and `comptime`. Sources (Mojo): buch `mojov1` pages
  `functions/parameters-and-generics` ("Value parameters and how to choose") and
  `keywords/comptime`. `(Assessment: derived from Mojo's comptime/value-parameter
  model.)`
- **Pure value-returning functions plus explicit buffer variants.** Because Mojo
  has value semantics and `var`/`borrowed`/`ref` argument conventions, a
  `prim_endian` can offer both `to_be(x)` (return swapped value) and
  `to_be_inplace(mut span)` without ambiguity — a cleaner split than the BEAM's
  values-only model. Source (Mojo): buch `mojov1` page
  `memory/ownership-and-lifetimes`. `(Assessment: derived from Mojo's argument
  conventions.)`
- **`raises` for bad input.** Use `raises` + a typed error for out-of-range
  values or insufficient buffer length, instead of the BEAM's `badarg`/silent
  non-match split. Source (Mojo): buch `mojov1` page `errors/error-model`.
- **Fixed-width, explicit API.** Provide `to_be_u16`, `to_le_u32`, `to_be_u64`,
  … so width is in the name and never inferred (contrast `encode_unsigned`'s
  minimal length). `(Assessment: derived from §11.4 and Rust-style naming seen in
  the sibling `rust.md` file.)`
- **Host order via a compile-time target query, not a runtime flag.** Mojo's
  philosophy is "ask the target, do not guess"; a `comptime` host-endianness
  constant (analogous to `system_info(endian)` but resolved at compile time) fits
  better than a runtime query. Source (Mojo): buch `mojov1` page
  `concurrency/vectorization-and-simd` ("Portability: ask the target, do not
  guess"). `(Assessment: derived from that page plus §9.)`
- **Byteswap as a first-class operation.** `mojov1` has **no** page documenting a
  `byteswap`/endian builtin (searched the buch; no hit), so an explicit
  `byteswap` API (scalar + SIMD) is a genuine gap a Mojo library can fill. For
  SIMD, a lane-wise swap can be expressed with existing bitwise/shift operators
  or inline MLIR. `GUESS:` whether Mojo exposes a native byteswap intrinsic —
  no buch page and no official source could be found.

# Sources

- Erlang bit syntax (Segments, Defaults, Endianness, construction/matching):
  https://www.erlang.org/doc/system/bit_syntax.html
- Erlang expressions / bit-syntax reference (Endianness = `big | little | native`):
  https://www.erlang.org/doc/system/expressions.html
- Elixir `Kernel.SpecialForms` `<<>>/1` (types, options, modifiers, endianness,
  `native`): https://hexdocs.pm/elixir/Kernel.SpecialForms.html
- `:binary` stdlib (decode_unsigned/encode_unsigned, subbinary/copy semantics):
  https://www.erlang.org/doc/apps/stdlib/binary.html
- `:binary` source (specs, OTP-29.1.1):
  https://github.com/erlang/otp/blob/OTP-29.1.1/lib/stdlib/src/binary.erl
- `erlang:system_info(endian)` implementation (OTP-29.1.1):
  https://github.com/erlang/otp/blob/OTP-29.1.1/erts/emulator/beam/erl_bif_info.c (L3101–L3106)
- `erlang` module (BIFs, `decode_packet/3` big-endian):
  https://www.erlang.org/doc/apps/erts/erlang.html
- Erlang external term format (big-endian wire contract):
  https://www.erlang.org/doc/apps/erts/erl_ext_dist.html
- Elixir `Bitwise` (bit ops, no endian; `ArithmeticError`):
  https://hexdocs.pm/elixir/Bitwise.html
- Elixir "Erlang libraries" (Elixir reuses Erlang stdlib; does not wrap):
  https://hexdocs.pm/elixir/erlang-libraries.html
- Hex package search "endian" (only `gleb128`):
  https://hex.pm/packages?search=endian&sort=downloads
- Safetensors endianness handling (secondary):
  https://deepwiki.com/elixir-nx/safetensors/3.2-binary-processing-and-endianness
- Mojo facts (buch `mojov1`): pages `functions/parameters-and-generics`,
  `keywords/comptime`, `memory/ownership-and-lifetimes`, `errors/error-model`,
  `concurrency/vectorization-and-simd`.
