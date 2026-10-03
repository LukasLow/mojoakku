# format research: Rust

## 1. Standard library support

`std::fmt` is "the runtime support for the `format!` syntax extension", a
**compiler-implemented macro** family: `format!`, `print!`/`println!`,
`eprint!`/`eprintln!`, `write!`/`writeln!`, `format_args!`. Source:
<https://doc.rust-lang.org/std/fmt/>.

## 2. Relevant community libraries

None required — the macro + trait system covers general formatting.
`localization` is explicitly **not** in `std`: "The format functions provided by
Rust's standard library do not have any concept of locale." Source:
<https://doc.rust-lang.org/std/fmt/>.

## 3. Exposed APIs

Macros listed above; traits `Display`, `Debug`, `Octal`, `LowerHex`, `UpperHex`,
`Pointer`, `Binary`, `LowerExp`, `UpperExp`, `Write`; struct `Formatter<'a>`;
error `fmt::Error`; type alias `fmt::Result`; `format_args!` produces
`fmt::Arguments<'_>` (stack-only, no heap allocation). Custom types implement
`fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result`. Source:
<https://doc.rust-lang.org/std/fmt/>.

## 4. Error representation

`fmt::Result = Result<(), fmt::Error>`. Crucially: **formatting is infallible**;
the `Result` exists only to propagate a failing underlying stream/writer, and an
implementation "must and may only return an error if the passed-in `Formatter`
returns an error". Source: <https://doc.rust-lang.org/std/fmt/>.

## 5. Ownership semantics

`format!` returns an owning `String`; `write!` writes into a `&mut` destination
implementing `fmt::Write` or `io::Write`; `format_args!` returns a **borrowed**
`Arguments<'_>` that "does not require any heap allocations to create, and it
only references information on the stack". Custom `fmt` receives `&self` (shared
borrow). Source: <https://doc.rust-lang.org/std/fmt/>.

## 6. Blocking / non-blocking

In-memory formatting. `write!` blocks only as the destination does; no async in
the formatting API. (Assessment: derived from
<https://doc.rust-lang.org/std/fmt/>.)

## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)

Python-like `{}` placeholders:
`format_string := text [ '{' '{' | '}' '}' | format ]*`;
`format := '{' [argument] [':' format_spec] ws* '}'`;
`format_spec := [[fill]align][sign]['#']['0'][width]['.' precision][type]`.
Grammar source: <https://doc.rust-lang.org/std/fmt/>.

- **Positional** (`{0}`), **implicit-next** (`{}`), and **named** (`{name}`)
  arguments. Mixing works via an iterator; explicit names don't advance it.
  Unused arguments/formatted-not-all is a **compile-time error**. Source: ibid.
- **Width** can be dynamic with `N$`/`name$`, or `.*` (consume an extra arg for
  precision). Source: ibid.
- **Alignment**: `<` left, `^` center, `>` right, with optional fill char before
  it. Defaults: non-numerics left with space; numerics right. Source: ibid.
- **`+ - # 0`** flags; `0` is sign-aware zero-pad. Source: ibid.
- **Precision**: max width for non-numerics, digits after point for floats;
  rounding is **round half-to-even**. Source: ibid.
- **Type** selects the trait (`?` Debug, `x`/`X` hex, `o`, `b`, `e`/`E`, `p`).
  Source: ibid.
- **Locale**: none — output is identical regardless of system locale. Source:
  ibid.

## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)

- The format string **must be a literal** — "It is required by the compiler for
  this to be a string literal; it cannot be a variable passed in (in order to
  perform validity checking)." So runtime format-string injection is structurally
  impossible. Source: <https://doc.rust-lang.org/std/fmt/>.
- Bad placeholder, wrong type, unused arguments → **compile-time error**. Source:
  ibid.
- Escaping literal braces: `{{` and `}}`. Source: ibid.

## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)

- **Owned result**: `String` from `format!`/`to_string()`.
- **Borrowed view**: `fmt::Arguments<'_>` (stack-only argument bundle);
  `Formatter<'a>` borrows the write state.
- **Builder**: `write!`/`writeln!` into any `fmt::Write`/`io::Write` — the
  allocation-free path when you don't need an owned `String`.
- **Debug helper builders**: `DebugStruct`, `DebugList`, `DebugMap`,
  `DebugTuple`, `DebugSet`. Source: <https://doc.rust-lang.org/std/fmt/>.

## 10. Interesting design decisions

- **Compile-time macro that rejects non-literal format strings** — the strongest
  anti-injection design; C++ later did the same with `format_string`.
- **Infallible formatting**: `fmt::Result` only propagates I/O failure, a clear
  separation of "formatting" from "writing". Source:
  <https://doc.rust-lang.org/std/fmt/>.
- **Display vs Debug** as two distinct traits with distinct contracts (Display =
  faithful, not all types; Debug = all public types, derived). Source: ibid.
- **One trait per presentation** (`LowerHex`, `Binary`, `Octal`) lets a type opt
  into only the forms it supports.
- **`format_args!` stack-only, zero-allocation** argument passing. Source: ibid.
- **`pad_integral`/`pad` helpers** let custom types honour width/fill correctly.
  Source: ibid.

## 11. Decisions NOT to copy

- **Macro-based formatting** is not expressible the same way in Mojo; Mojo's
  `TString`/`t"…"` is the analogue, and `Writable` the trait.
- **Nine separate formatting traits** is a large surface; Mojo's single
  `Writable` + `write_to`/`write_repr_to` is leaner.
- **Requiring a literal** is right for safety but prevents genuinely dynamic
  templates; Mojo may want an explicit runtime-checked path instead.
- **No locale at all** matches Mojo's likely starting point, but note it as a
  deliberate limitation.

## 12. Ideas fitting Mojo

- **Compile-time validation of `t"…"` interpolations** against the value types is
  the natural Mojo equivalent of Rust's literal-only check.
- **Infallible-format / fallible-write split**: in Mojo, `write_to` should not
  raise; a `Writer` that can fail surfaces that through its own interface.
- **Display vs Debug** is exactly Mojo's `write_to` vs `write_repr_to` (buch
  `mojov1/stdlib/format`) — adopt the contract wording.
- **`Arguments<'_>` as a borrowed, allocation-free bundle**: Mojo's `TString` is
  lazy and allocation-free until materialized (buch `mojov1/basics/literals`), the
  same idea.
- **Round half-to-even** is the documented rounding rule worth matching for float
  formatting.

## Sources

- std::fmt module: <https://doc.rust-lang.org/std/fmt/>
- format! macro: <https://doc.rust-lang.org/std/macro.format.html>
- Display trait: <https://doc.rust-lang.org/std/fmt/trait.Display.html>
- Debug trait: <https://doc.rust-lang.org/std/fmt/trait.Debug.html>
- Formatter: <https://doc.rust-lang.org/std/fmt/struct.Formatter.html>
