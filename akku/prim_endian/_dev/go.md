# prim_endian research: Go

> Scope note: this file is the Go half of the `systems-modern` group for the
> frozen Phase-1 run of `prim_endian` (see `README.md`). Q7 and Q9 are the
> endian-adapted variants (byte orders represented; host-native-endianness
> detection); the socket wording of Q5/Q7/Q9 does not apply. Zig is noted only
> as a cross-reference at the end of `rust.md`, per the run config.

## 1. Standard library support

- The standard library package is `encoding/binary`, described as implementing
  "simple translation between numbers and byte sequences and encoding and
  decoding of varints" (source: https://pkg.go.dev/encoding/binary).
- It defines the `ByteOrder` interface (source: encoding/binary/binary.go:39,
  https://cs.opensource.google/go/go/+/go1.27.1:src/encoding/binary/binary.go;l=39)
  and the `AppendByteOrder` interface (binary.go:53).
- Three exported `ByteOrder`/`AppendByteOrder` implementations are provided as
  package variables: `binary.LittleEndian` (binary.go:61),
  `binary.BigEndian` (binary.go:64) and `binary.NativeEndian`
  (`native_endian_little.go:14`; big-endian variant in
  `native_endian_big.go:14`) (source: https://pkg.go.dev/encoding/binary).
- `NativeEndian` was added in **Go 1.21**: "The new `NativeEndian` variable may
  be used to convert between byte slices and integers using the current
  machine's native endianness." (source: https://go.dev/doc/go1.21,
  section `encoding/binary`).
- A separate value-level byte-swap primitive lives in `math/bits`:
  `ReverseBytes16`, `ReverseBytes32`, `ReverseBytes64` and `ReverseBytes`
  (source: https://pkg.go.dev/math/bits; implementation
  https://cs.opensource.google/go/go/+/go1.27.1:src/math/bits/bits.go;l=266).
  `math/bits` "implements bit counting and manipulation functions for the
  predeclared unsigned integer types" (source: https://pkg.go.dev/math/bits).
- Floats are folded into byte order via `math.Float32bits` / `math.Float64bits`
  (source: encoding/binary/binary.go `encodeFast`/`decodeFast`;
  https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/binary.go).

## 2. Relevant community libraries

- There is no widely used dedicated third-party Go endianness package; the
  ecosystem standardizes on `encoding/binary`. Evidence of dominance: the
  `encoding/binary` package page reports "Imported by: 272,172"
  (source: https://pkg.go.dev/encoding/binary). `(Assessment: derived from
  the single-package standard-library design plus this import count; no
  comparable community endianness crate for Go was found in the registry.)`
- Note the naming collision risk: the Rust `byteorder` crate (see `rust.md`)
  has no Go counterpart of the same role. A search of Go's module index for a
  general endianness package returns wrappers around `encoding/binary` rather
  than an independent API. `GUESS:` — no authoritative registry query was run
  in this phase; the claim is limited to "no prominent library surfaced".
- Protocol/format libraries that need endianness (`google.golang.org/protobuf`,
  `encoding/gob`) are serializers, not endianness abstractions, and the package
  doc explicitly points at them only as *efficiency* alternatives
  (source: https://pkg.go.dev/encoding/binary). They are out of scope for
  `prim_endian`.

## 3. Exposed APIs

`ByteOrder` interface (source: https://pkg.go.dev/encoding/binary):

```go
type ByteOrder interface {
    Uint16([]byte) uint16
    Uint32([]byte) uint32
    Uint64([]byte) uint64
    PutUint16([]byte, uint16)
    PutUint32([]byte, uint32)
    PutUint64([]byte, uint64)
    String() string
}
```

`AppendByteOrder` adds allocation-friendly variants (added Go 1.19):

```go
type AppendByteOrder interface {
    AppendUint16([]byte, uint16) []byte
    AppendUint32([]byte, uint32) []byte
    AppendUint64([]byte, uint64) []byte
    String() string
}
```

- Package-level helpers that take a `ByteOrder`: `Read`, `Write`, `Encode`,
  `Decode`, `Append`, `Size` (source: https://pkg.go.dev/encoding/binary).
  `Encode`/`Decode`/`Append` were added in Go 1.23.
- `Math/bits` byte swap: `ReverseBytes16(x uint16) uint16`,
  `ReverseBytes32`, `ReverseBytes64` (source: https://pkg.go.dev/math/bits).
- The interface only covers **unsigned** 16/32/64-bit. Signed values and floats
  are converted by casting/reinterpreting at the call site
  (`order.PutUint16(bs, uint16(*v))`, `math.Float32bits`), see `encodeFast` /
  `decodeFast` in
  https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/binary.go.
- Go's `net` package network-byte-order helpers (`htons`/`htonl` analogues) are
  internal; the public equivalent is `binary.BigEndian`. `(Assessment: derived
  from there being no exported byte-order symbols in the `net` package docs;
  the historical `net` byte-order functions are unexported.)`

## 4. Error representation

Mixed, split by API layer:

- `Uint16/32/64` and `PutUint16/32/64` return values / mutate in place and have
  **no error return**. A too-short `[]byte` panics via slice bounds checks; the
  source contains deliberate `_ = b[1]` / `_ = b[7]` "bounds check hint to
  compiler" lines (source:
  https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/binary.go).
- `Read`/`Write`/`Encode`/`Decode`/`Append` return `error`. `Decode`/`Encode`/
  `Append` return `errBufferTooSmall = errors.New("buffer too small")`
  when the destination is short, and `errors.New("binary.Read: invalid type "
+ ...)` for unsupported types (source: same file; package doc
  https://pkg.go.dev/encoding/binary).
- `Read` uses `io.EOF` only when no bytes were read, and `io.ErrUnexpectedEOF`
  when EOF follows a partial read (source: https://pkg.go.dev/encoding/binary).
- Varints use a **sentinel + out-parameter** convention: `Uvarint`/`Varint`
  return `(value, n)` where `n == 0` means buffer too small and `n < 0` means
  overflow with `-n` = bytes read (source: https://pkg.go.dev/encoding/binary).

## 5. Ownership semantics

Adapted Q5: is conversion value-returning or in-place, and who owns the
input/output value.

- `Uint16([]byte) uint16` is **value-returning**: it reads bytes and returns a
  new integer; it neither stores nor retains the slice (source:
  binary.go `func (littleEndian) Uint16`).
- `PutUint16([]byte, uint16)` is **in-place**: it writes into a caller-owned
  slice and transfers no ownership (source: binary.go `PutUint16`).
- `AppendUint16([]byte, uint16) []byte` returns the (possibly reallocated)
  buffer; ownership stays with the caller and the returned slice may point at a
  new backing array (source: binary.go `AppendUint16`).
- `binary.Read`/`Write`/`Decode`/`Encode` operate on a caller-owned
  `io.Reader`/`io.Writer` and a caller-provided data pointer; decoded values are
  written into the caller's variable via reflection (source: binary.go `Read`,
  `Write`, `decoder.value`, `encoder.value`).
- There is no handle to free: Go is garbage-collected, so the endianness API
  owns no resource and exposes no destructor. `(Assessment: derived from the
  signatures above — all inputs are values or caller-owned slices/pointers.)`

## 6. Blocking / non-blocking

- The numeric conversions (`Uint*`, `PutUint*`, `AppendUint*`,
  `bits.ReverseBytes*`) are pure synchronous CPU operations with no I/O.
- `Read`/`Write` take an `io.Reader`/`io.Writer`; these may block depending on
  the concrete reader (e.g. a network connection), but `encoding/binary` itself
  introduces no asynchrony (source: signatures,
  https://pkg.go.dev/encoding/binary).
- Go has no async/await; concurrency is goroutine-based and orthogonal to this
  package. `(Assessment: derived from the package surface, which contains no
  channel, context or Future/async type.)`

## 7. IPv4 / IPv6

Adapted Q7: which byte orders are represented, and does a single abstraction
cover all of them.

- `binary.BigEndian` = big-endian; `binary.LittleEndian` = little-endian;
  `binary.NativeEndian` = host native. Network byte order is by convention
  big-endian and is served by `BigEndian`
  (source: https://pkg.go.dev/encoding/binary).
- A **single abstraction covers all three**: the `ByteOrder` interface, whose
  method set is identical for every implementation
  (source: binary.go:39).
- `NativeEndian` is a distinct concrete type (`nativeEndian`) that embeds
  `littleEndian` or `bigEndian` depending on the build target, so it reuses the
  same method bodies rather than re-implementing them
  (source: https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/native_endian_little.go
  and `.../native_endian_big.go`).
- There is no separate "network" constant or enum member; `BigEndian` is the
  network representation. `(Assessment: derived from the exported variable set
  in the package docs.)`

## 8. Timeouts

- Not applicable to the conversion functions: they are pure, non-blocking CPU
  operations with no deadline or cancellation parameter
  (source: signatures, https://pkg.go.dev/encoding/binary).
- Any timeout/cancellation is delegated to the `io.Reader`/`io.Writer` passed to
  `Read`/`Write`. Go's idiom for that is `context.Context`, but `encoding/binary`
  takes no context argument and exposes no cancellation hook
  (source: binary.go `Read`/`Write` signatures). `(Assessment: derived from the
  absence of any context/deadline parameter in the package's exported API.)`

## 9. TLS

Adapted Q9: how host native endianness is detected and reported.

- Native endianness is **compile-time selected**, not a runtime query:
  `native_endian_little.go` is built for
  `//go:build 386 || amd64 || amd64p32 || alpha || arm || arm64 || loong64 ||
  mipsle || mips64le || mips64p32le || nios2 || ppc64le || riscv || riscv64 ||
  sh || wasm` and embeds `littleEndian`; `native_endian_big.go` is built for
  `//go:build armbe || arm64be || m68k || mips || mips64 || mips64p32 || ppc ||
  ppc64 || s390 || s390x || shbe || sparc || sparc64` and embeds `bigEndian`
  (source:
  https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/native_endian_little.go
  and `.../native_endian_big.go`).
- The public surface exposes only the resulting `binary.NativeEndian` value plus
  its `String() == "NativeEndian"` (source: binary.go
  `func (nativeEndian) String`).
- There is **no exported `IsBigEndian`/`IsLittleEndian` runtime function** in
  `encoding/binary`; detection exists as the build-tag selection above.
  `(Assessment: derived from the exported API list in the package docs — only
  the three variables and the interface types are exported.)`

## 10. Interesting design decisions

1. **Interface over enum/flags.** One 7-method `ByteOrder` interface unifies
   all orders; callers pass an order value rather than a boolean
   `littleEndian` flag (source: binary.go:39). Contrast with JS `DataView`'s
   explicit bool flag (see `js-ts.md`).
2. **NativeEndian by embedding, selected at compile time.** No runtime branch;
   the compiler picks the embedded method set via build constraints
   (source: `native_endian_*.go`).
3. **Minimal unsigned-only interface.** Only 16/32/64-bit unsigned are in the
   interface; signed/floats are handled by casts/reinterpretation at call sites,
   keeping the interface total and small (source: binary.go `encodeFast`).
4. **`AppendByteOrder` as a second, separate interface** (Go 1.19): appending to
   a caller buffer is split from `Put*` to enable efficient accumulation and
   avoid repeated bounds checks (source: binary.go:53).
5. **Two error regimes.** Hot value conversions panic on short slices (fast,
   bounds-check-hinted); reflection-based `Read`/`Decode` return `error`
   (source: binary.go).
6. **`String()`/`GoString()` in the interface** for readable debugging output
   (`"LittleEndian"`, `"binary.LittleEndian"`) (source: binary.go).
7. **Value-level swap separate from slice interpretation.** `math/bits` owns
   `ReverseBytes*` on integers; `encoding/binary` owns slice↔integer
   conversion. Two orthogonal primitives (source: https://pkg.go.dev/math/bits).

## 11. Decisions NOT to copy

- **Reflection-based `Read`/`Write(any)`** with struct field walking: heavy,
  untyped, and dependent on exported fields / blank-name padding. A focused
  endianness library should not absorb a reflective serializer
  (source: binary.go `decoder.value`/`encoder.value`).
- **Panic-on-short-buffer** for `PutUint*`: conflicts with a principled
  error model; prefer an explicit failure (`raises`/Result) for the checked
  path.
- **Interface dispatch** for what is a compile-time-known order: Go needs it
  for dynamic choice, but a Mojo API can specialize at compile time.
- **Build-tag-embedded `NativeEndian`** is a Go toolchain mechanism that does
  not map 1:1 onto a single-compilation-model library; the *idea* (native
  endianness is a compile-time property) transfers, the *mechanism* does not.
- **`String()`/`GoString()` naming** is idiomatic Go only.

## 12. Ideas fitting Mojo

> Mojo-specific capabilities below are candidate ideas to be validated against
> the `mojov1` buch in later phases; this phase makes no Mojo API decision.

- **Value-returning total conversions** mirror Mojo value semantics:
  `to_be_bytes`-style functions returning a fixed-size value, and
  `from_be_bytes`-style functions taking one, never borrowing a buffer.
- **Compile-time order parameter**: model native/big/little as one
  implementation selected at compile time (Go's build-tag embedding, Rust's
  `const fn` no-op-or-swap), instead of a runtime enum/branch.
- **A minimal low-level `swap_bytes`** primitive on top of which big/little
  conversions are defined (Go `math/bits.ReverseBytes*`, Rust `swap_bytes`).
- **A slice-based in-place `put_*`** as a separate, explicitly-fallible
  operation (length-checked), while the fixed-width path stays total.
- **No reflective serializer**: keep endianness primitive and composable.
  `(Assessment: derived from the Go evidence above and the workflow's
  "no design decisions in Phase 1" rule.)`

## Sources

- Go `encoding/binary` package documentation — https://pkg.go.dev/encoding/binary
- Go `encoding/binary` source (v1.23.0) —
  https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/binary.go
  (also `cs.opensource.google/go/go/+/go1.27.1:src/encoding/binary/binary.go`)
- Go `encoding/binary` native-endian implementations (v1.23.0) —
  https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/native_endian_little.go
  and
  https://github.com/golang/go/blob/go1.23.0/src/encoding/binary/native_endian_big.go
- Go `math/bits` package documentation — https://pkg.go.dev/math/bits
  (source: `.../src/math/bits/bits.go`)
- Go 1.21 Release Notes (`NativeEndian` added) — https://go.dev/doc/go1.21
