# build_versioning research: Zig

## 1. Standard library support

- **Zig ships a standard-library SemVer parser and comparator.**
  `std.SemanticVersion` is "A software version formatted according to the
  Semantic Versioning 2.0.0 specification. See: https://semver.org"
  (`lib/std/SemanticVersion.zig:1-4`).
- **The type is a plain struct:**
  `major: usize, minor: usize, patch: usize, pre: ?[]const u8 = null,
  build: ?[]const u8 = null` (`SemanticVersion.zig:9-14`). The three numbers are
  `usize` (machine word); prerelease and build are **optional borrowed slices**
  into the input text (`?[]const u8`), defaulting to `null`.
- **Functions:** `pub fn order(lhs, rhs) std.math.Order`
  (`SemanticVersion.zig:34-86`); `pub fn parse(text: []const u8) !Version`
  (`:88-155`); `pub fn format(self, w: *std.Io.Writer) ...`
  (`:157-162`); plus the nested `Range` type with `includesVersion` and
  `isAtLeast` (`:16-32`).
- **It uses only generic stdlib primitives:** `std.mem.indexOfAny`,
  `std.mem.splitScalar`, `std.mem.order`, `std.ascii.isAlphanumeric`,
  `std.ascii.isDigit`, `std.fmt.parseUnsigned`, `std.math.Order`
  (`SemanticVersion.zig`).
- **`std.builtin` carries the compiler's own version as a `SemanticVersion`:**
  the test `zig_version` compares `comptime @import("builtin").zig_version`
  against a literal `Version` using `.order` (`SemanticVersion.zig:242-248`), and
  the standard library defines `zig_version: SemanticVersion` for the running
  compiler (`std.builtin`, `zig_version`).
- **The nested `Range` is a simple `{ min, max }` pair**, not a general
  constraint grammar: `includesVersion(ver)` returns false if `min.order(ver) ==
  .gt` or `max.order(ver) == .lt`; `isAtLeast(ver) ?bool` returns `null` when a
  runtime check is required (`SemanticVersion.zig:18-31`). It has **no**
  comparator/caret/tilde/wildcard support.

## 2. Relevant community libraries

- **None needed for the core.** Because `std.SemanticVersion` exists, Zig
  projects rarely add a SemVer dependency; the std type is the reference
  (Assessment: derived from §1). `GUESS:` there are community packages that add
  constraint/range grammars, but none was fetched in this run, so no names or
  APIs are asserted. Reason no source: the run fetched the stdlib source as the
  Zig reference.
- The interesting community signal is instead **how the std library itself uses
  SemVer**: `@import("builtin").zig_version` and the `Range.isAtLeast` helper for
  "is this compiler new enough" compile-time compatibility checks
  (`SemanticVersion.zig:28-32, 242-248`).

## 3. Exposed APIs

From `lib/std/SemanticVersion.zig` (all `pub`):

- **Fields:** `major: usize`, `minor: usize`, `patch: usize`,
  `pre: ?[]const u8 = null`, `build: ?[]const u8 = null` (`:9-14`).
- **`pub fn order(lhs: Version, rhs: Version) std.math.Order`** — SemVer
  precedence, returns `.lt` / `.eq` / `.gt` (`:34-86`).
- **`pub fn parse(text: []const u8) !Version`** — strict SemVer 2.0.0 parse;
  error set inferred, concretely `error{InvalidVersion, Overflow}` (via
  `parseNum`, `:145-154`) plus `std.fmt` errors propagated by `parseUnsigned`
  (`:88-155`).
- **`pub fn format(self: Version, w: *std.Io.Writer) std.Io.Writer.Error!void`** —
  canonical `MAJOR.MINOR.PATCH[-pre][+build]` (`:157-162`).
- **`Range` struct:** `min: Version`, `max: Version`,
  `pub fn includesVersion(self, ver) bool`,
  `pub fn isAtLeast(self, ver) ?bool` (`:16-32`).
- **`zig_version`** on `std.builtin` is a `SemanticVersion` (`SemanticVersion.zig`
  test usage `:243`).

## 4. Error representation

- **Error unions, no exceptions, no error codes.** `parse` returns `!Version`;
  the failure values are `error.InvalidVersion` and `error.Overflow`
  (`SemanticVersion.zig:88, 145-154`). The parser returns `error.InvalidVersion`
  for empty identifiers, disallowed characters, missing minor/patch, extra
  numeric components, and leading zeros; `error.Overflow` propagates from
  `std.fmt.parseUnsigned` when a component exceeds `usize`
  (`SemanticVersion.zig:88-155`).
- **Errors are distinguished from ordering.** Invalid input never becomes a
  `Version`, so `order` can never be called on an invalid value — the type
  system prevents the "invalid compares as less" problem found in C and Go
  (`c.md` §4, `go.md` §4). This is a direct consequence of `parse` returning
  `!Version` rather than a status plus an out-param.
- `isAtLeast` returns `?bool` (optional bool), using `null` as "unknown, needs a
  runtime check" — a third outcome beyond true/false
  (`SemanticVersion.zig:28-32`).
- `GUESS:` `order` has no documented error because it only accepts constructed
  `Version` values; no fetched source states this explicitly, but the signature
  `order(lhs: Version, rhs: Version) std.math.Order` (not `!Order`) makes it
  total (`SemanticVersion.zig:34`).

## 5. Ownership semantics

*Adapted for versioning (see `_dev/README.md`): whether parsing is in-place or
value-returning, and who owns the parsed value/string.*

- **Value-returning parse, borrowed qualifier slices, no allocation.**
  `parse(text: []const u8) !Version` returns the struct **by value**
  (`SemanticVersion.zig:88`). The `pre`/`build` fields are `?[]const u8`
  **slices into `text`** (`:105-124`), so the returned version **borrows the
  input buffer** and is only valid while `text` lives.
- **This makes the parse genuinely zero-allocation**, but it creates a lifetime
  obligation on the caller: the version cannot outlive the string it was parsed
  from (Assessment: derived from the `[]const u8` fields at `:12-13` and the
  slicing at `:113-124`).
- **The numeric fields are plain values** (`usize`), copied into the struct
  (`:9-11`).
- **`format` takes the version by value and writes to a caller-supplied writer**,
  so output ownership stays with the caller (`:157-162`).
- **The std type has no `deinit`** because it never allocates; ownership of the
  backing text is entirely the caller's (Assessment: derived from the absence of
  an allocator parameter anywhere in the file).

## 6. Blocking / non-blocking

- **Not applicable: pure computation.** `parse`, `order` and `format` do no I/O,
  allocate nothing, block nowhere, and expose no async/concurrency model
  (`SemanticVersion.zig`; note `parse` has no allocator parameter).
- **Values are immutable plain structs**, so distinct `Version`s can be shared
  across threads without synchronisation (Assessment: derived from the
  by-value struct and pure functions).
- `isAtLeast` returning `?bool` is the closest thing to a "may need runtime
  work" signal, but it still performs no blocking operation
  (`SemanticVersion.zig:28-32`).

## 7. IPv4 / IPv6

*Adapted for versioning (see `_dev/README.md`): how the spec/version identity is
modelled and whether one abstraction covers it all.*

- **Identity model: `major.minor.patch` as `usize` + optional prerelease and
  build slices** (`SemanticVersion.zig:9-14`). This matches the spec's
  `<version core>` plus the two optional suffixes (semver.org, *BNF*).
- **All three numeric components are mandatory.** `parse` requires minor and
  patch: `minor = try parseNum(it.next() orelse return error.InvalidVersion)`,
  likewise patch, and rejects a fourth component
  (`SemanticVersion.zig:96-102`). `1` and `1.2` are invalid — the test corpus
  lists `"1"`, `"1.2"` as invalid (`:196, 204`).
- **Leading zeros are forbidden** for major/minor/patch and for numeric
  prerelease identifiers: `parseNum` returns `error.InvalidVersion` if
  `text.len > 1 and text[0] == '0'` (`:145-148`); the corpus rejects `01.1.1`,
  `1.01.1`, `1.1.01`, `1.2.3-0123` (`:204-207`).
- **Optional `v` prefix is NOT supported.** `parse` starts directly at the
  digits; `v1.2.3` would fail at `parseNum` (Assessment: derived from `parse`
  `:88-102`; semver.org FAQ confirms `v1.2.3` is not a semantic version).
- **Prerelease and build are modelled but only prerelease affects precedence.**
  `order` compares `pre` (with the full item-11 rules) but **never touches
  `build`** (`SemanticVersion.zig:44-86`); the corpus includes
  `1.1.2-prerelease+meta` and `1.1.2+meta` as valid (`:176-177`). So two versions
  differing only in build compare `.eq` under `order` (semver.org item 10).
- **One abstraction covers the whole spec:** a single `Version` struct plus
  `order`. `Range` is a *separate, minimal* `{min,max}` pair and is explicitly
  **not** a full constraint language (`SemanticVersion.zig:16-32`).
- **Prerelease/build are raw slices, not validated newtypes.** Validity is
  checked inside `parse` (`:126-141`) but the fields are typed `?[]const u8`, so
  a hand-constructed `Version{ .pre = "bad" }` is representable
  (Assessment: derived from `:12-13`; contrast Rust's `Prerelease` newtype,
  `rust.md` §7).

## 8. Timeouts

- **Not applicable.** No blocking operation, no deadline, no cancellation point
  (`SemanticVersion.zig`). The only bound is the input length (implicit) and the
  `usize` overflow check (`:145-154`).
- There is no allocator parameter and thus no allocation-failure timeout path
  (Assessment: derived from the `parse` signature).

## 9. TLS

*Adapted for versioning (see `_dev/README.md`): how prerelease/build metadata and
constraint ranges are handled.*

- **Prerelease rules implement semver.org item 11 exactly.** After equal
  major/minor/patch: a prerelease is lower than no-prerelease
  (`SemanticVersion.zig:44-46`); identifiers are compared left to right; numeric
  identifiers numerically, letter/hyphen identifiers with `std.mem.order`
  (ASCII); numeric always lower than non-numeric; "a larger set of pre-release
  fields has a higher precedence than a smaller set"
  (`SemanticVersion.zig:50-86`; comments cite item 11 explicitly).
- **Build metadata is validated but never used in precedence.** `parse` checks
  each build identifier (non-empty, alphanumeric or hyphen) but `order` ignores
  it entirely (`SemanticVersion.zig:133-141, 34-86`); semver.org item 10: "Build
  metadata MUST be ignored when determining version precedence".
- **Validity checks are explicitly traceable to the spec:** the source comments
  cite "https://semver.org/#spec-item-9" for prerelease and
  "https://semver.org/#spec-item-10" for build (`SemanticVersion.zig:126, 136`),
  and the test corpus draws from `semver.org/issues/59` (`:166-168`).
- **Ranges are deliberately minimal.** `Range{min,max}` supports only closed
  interval membership and a three-valued `isAtLeast`; there is **no** comparator,
  caret, tilde, wildcard, or hyphen range (unlike the C++, Go and Rust libraries
  in this corpus). This reflects that the std use case is "is the compiler new
  enough", not package resolution (`SemanticVersion.zig:16-32`).
- The `-0` sentinel idiom used by npm/Cargo/C++ is absent, because there is no
  range grammar to need it (`cpp.md` §9; `go.md` §9).

## 10. Interesting design decisions

- **Zero-allocation parse with borrowed slices.** `pre`/`build` are
  `?[]const u8` into the input, so parsing never allocates and `format` writes
  into a caller-provided writer (`SemanticVersion.zig:12-13, 157-162`). This is
  the tightest ownership design in the corpus.
- **The compiler's own version is a `SemanticVersion` constant**, enabling
  `comptime @import("builtin").zig_version.order(v) == .gt` for compile-time
  compatibility assertions (`SemanticVersion.zig:242-248`) — the library dogfoods
  itself for build-time gates.
- **`isAtLeast` is deliberately three-valued** (`?bool`), distinguishing
  "guaranteed yes", "guaranteed no", and "runtime check needed"
  (`SemanticVersion.zig:28-32`).
- **The test corpus is the spec's own edge-case list**, including hostile
  strings (`1.0.0-alpha..`, `9.8.7+meta+meta`, `2.11.2(0.329/5/3)`, `8.008.`)
  (`SemanticVersion.zig:166-238`). This is a ready-made conformance suite.
- **Overflow is a distinct error** from a syntactically invalid version:
  `error.Overflow` vs `error.InvalidVersion` (`:145-154`, corpus `:234-238`).
- **`std.mem.Order` is reused instead of a bespoke enum**, so the comparison
  result interoperates with `std.math` ordering helpers
  (`SemanticVersion.zig:34`).
- **The parser is written with a handful of `std.mem.*` calls**, not a regex:
  find the `-`/`+` boundary with `indexOfAny`, split on `.`, validate, then slice
  (`:89-124`). Small and auditable.
- **Unreachable overflow assertion in comparison:** while comparing numeric
  prerelease identifiers, `error.Overflow` is `unreachable` because `parse`
  already vetted the values (`SemanticVersion.zig:66-70`) — the parser and
  comparator share an invariant.

## 11. Decisions NOT to copy

- **Borrowed qualifier slices create a subtle lifetime coupling.** A `Version`
  from `parse` is only valid while the input buffer lives; returning it from a
  function that owns a temporary string is a use-after-free. For MojoAkku, which
  values predictability, owning the qualifiers (like Rust) or copying them
  avoids this trap (Assessment: derived from `?[]const u8` at `:12-13`).
- **Unvalidated fields on a hand-constructible struct** allow invalid
  prereleases to exist outside `parse` (Assessment: derived from `:9-14`).
  Validated constructors/newtypes are safer (`rust.md` §7).
- **`usize` components** tie the numeric range to the word size and overflow at
  ~2^64 on 64-bit (or ~2^32 on 32-bit) (`:9-11`); an explicit, documented width
  is preferable (`rust.md` §10, `go.md` §3).
- **No `v`-prefix handling, no coercion, no partial versions** — strict to the
  point that common real-world input (`v1.2.3`, `1.2`) is rejected
  (Assessment: derived from `parse`). A general library should decide and
  document its policy rather than silently inherit Zig's strictness.
- **`Range {min,max}` is too weak to be called a range engine.** If Mojo ships
  ranges, Zig is not the model (it has no comparators/wildcards) — but its
  honesty about scope (a closed interval for compiler checks) is worth copying
  (Assessment: derived from `:16-32`).
- **No input-length cap** leaves the same unbounded-parse surface as Rust
  (`rust.md` §11); Go and C++ guard it explicitly (`go.md` §3, `cpp.md` §10).
- **`format` requires a `*std.Io.Writer`**, dragging an I/O abstraction into the
  formatting of a pure value; a Mojo design may prefer returning a `String` or
  implementing a `Writable` trait (Assessment: derived from `:157-162`).

## 12. Ideas fitting Mojo

- **A `Version` value type with owning qualifiers** is the safe middle ground
  between Zig's borrowed slices and no representation; parse allocates once, the
  caller never manages a lifetime (mojov1 buch, `mojov1/types/overview` —
  `String`/`StringSpan`, value semantics).
- **Strict `parse` returning `raises VersionError`**, with distinct variants for
  syntax vs overflow, mirroring Zig's `InvalidVersion` / `Overflow`
  (`SemanticVersion.zig:145-154`; mojov1 buch, `mojov1/appendix/cheat-sheet` —
  typed raising).
- **The spec's own edge-case corpus as the initial test set**, already collected
  in Zig's source (`SemanticVersion.zig:166-238`; semver.org item 9/10).
- **A three-valued `is_at_least`-style query** (`?bool` → Mojo `Optional`) for
  build/compat gates, which is genuinely useful and rarely modelled
  (`SemanticVersion.zig:28-32`).
- **Dogfood: a compile-time version constant** so the library's own version and
  compatibility checks use the same type — analogous to `builtin.zig_version`
  (mojov1 buch, `mojov1/appendix/cheat-sheet` — `comptime`).
- **Keep the core parse/compare small and defer ranges**, exactly as Zig keeps
  `Range` minimal; a full constraint grammar is a separate, larger commitment
  (Assessment: derived from `:16-32`; `cpp.md` §11).
- **Reuse a standard ordering type** for `compare`'s result rather than inventing
  booleans (`SemanticVersion.zig:34`; semver.org item 11).
- **No allocator in the hot path**: parse into a value; only the qualifier
  strings, if owned, justify a single allocation (Assessment: derived from the
  zero-allocation design at `:12-13`).

## Sources

- <https://semver.org/> — SemVer 2.0.0 spec: items 2, 9, 10, 11; BNF grammar;
  test corpus origin `semver.org/issues/59`; `v` FAQ.
- <https://github.com/ziglang/zig/blob/master/lib/std/SemanticVersion.zig> —
  complete `std.SemanticVersion` source: fields, `order`, `parse`, `format`,
  `Range`, error set, spec-citing comments, and the valid/invalid test corpus.
- <https://ziglang.org/documentation/master/std/#std.SemanticVersion> — std
  documentation entry point for `std.SemanticVersion` (page is JS-rendered;
  authoritative details taken from the source file above).
- <https://docs.npmjs.com/cli/v10/using-npm/semver> — cross-ecosystem range
  syntax used for contrast (Zig has no comparable range grammar).
