# format research: Go

## 1. Standard library support

The **`fmt`** package implements formatted I/O "with functions analogous to C's
printf and scanf", with simplified **verbs**. Four output families by
destination: `Print/Println/Printf` → stdout, `Sprint/Sprintln/Sprintf` → string,
`Fprint/Fprintln/Fprintf` → `io.Writer`, `Append/Appendln/Appendf` → `[]byte`.
Source: <https://pkg.go.dev/fmt>.

## 2. Relevant community libraries

None needed — `fmt` is exhaustive for formatting. Community activity is around
lint tools for `Printf` verbs, not alternative formatters. (Assessment: derived
from the completeness of the `fmt` API surface at <https://pkg.go.dev/fmt>.)

## 3. Exposed APIs

`func Printf(format string, a ...any) (n int, err error)`, `Sprintf(format
string, a ...any) string`, `Fprintf(w io.Writer, format string, a ...any)`,
`Appendf(b []byte, format string, a ...any) []byte`, `Errorf(format string, a
...any) error`. Interfaces: `fmt.Stringer` (`String() string`), `fmt.Formatter`
(`Format(f State, verb rune)`), `fmt.GoStringer`, `State`, `ScanState`,
`Scanner`. Source: <https://pkg.go.dev/fmt>.

## 4. Error representation

Two channels:
- **I/O errors** are returned (`n, err`), forwarded from the `io.Writer`.
- **Format errors are embedded in the output string**, not returned: wrong type →
`%!d(string=hi)`, too many args → `%!(EXTRA string=guys)`, too few →
`%!d(MISSING)`, bad width/precision → `%!(BADWIDTH)`/`%!(BADPREC)`, bad index →
`%!(BADINDEX)`, a panicking `String()`/`Error()` method → `%!s(PANIC=bad)`.
Source: <https://pkg.go.dev/fmt>.

## 5. Ownership semantics

Go strings are **immutable**; `Sprintf` returns a **new string**. `Appendf`
appends to a caller-owned `[]byte` and returns the updated slice. `Fprintf`
writes to a caller-supplied `io.Writer`. Nothing is freed manually (GC).
Source: <https://pkg.go.dev/fmt>.

## 6. Blocking / non-blocking

The `Fprint*` family writes to an `io.Writer` and blocks only as the writer
does; the `Sprint*`/`Append*` families are in-memory. No async model in the
formatting API itself. (Assessment: derived from the function signatures at
<https://pkg.go.dev/fmt>.)

## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)

**Verbs** `%v` (default), `%#v` (Go-syntax), `%T` (type), `%t`, `%d %b %o %O %x
%X %c %q %U`, float `%e %E %f %F %g %G %x %X`, `%s %q %x %X`, `%p`, `%%`.
**Width** = optional decimal before the verb; **precision** = `.` followed by a
decimal (`.` alone = 0). Flags: `+ - # space 0`. Width/precision may be `*`,
taking the next `int` operand. Source: <https://pkg.go.dev/fmt>.

Two distinctive rules:
- **Width and precision are measured in Unicode code points (runes)**, unlike C's
  bytes; for `%x`/`%X` on strings they are bytes. Source: ibid.
- **Explicit argument indexes** `%[n]d` (one-indexed), and `%[n]*` to select the
  width/precision operand; indexes advance the implicit counter. Source: ibid.

Default `%v` per type: bool `%t`, ints `%d`, floats `%g`, string `%s`,
struct `{field0 field1 …}`, map sorted by key, pointer `%p`. Source: ibid.
**Locale**: `fmt` is locale-independent (no locale parameter). (Assessment:
derived from the absence of locale in the API at <https://pkg.go.dev/fmt>.)

## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)

- **No crash/UB**: every malformed case renders a `%!…` marker in the output.
  Source: <https://pkg.go.dev/fmt>.
- Wrong type, too few args, extra args, bad width/precision and bad index are all
  encoded, never panicked. Source: ibid.
- A user `String()` that panics is caught and rendered as `%!s(PANIC=…)`; the
  package **does not protect** against infinite recursion in self-referential
  `String()` methods. Source: ibid.
- The docs explicitly warn about recursion: convert the value before recursing.
  Source: ibid.
- Format-string injection is not a memory-safety issue (no `%n`); the worst case
  is a confusing `%!` string.

## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)

- **Owned**: `string` returned by `Sprintf`.
- **Borrowed**: `[]byte` output target for `Append*`; `io.Writer` interface.
- **Builder**: `strings.Builder` is the idiomatic incremental accumulator; the
  `Append*` family appends directly to a byte slice with no intermediate string.
- **Customization interfaces**: `Stringer`/`Formatter`/`GoStringer`.
Source: <https://pkg.go.dev/fmt>.

## 10. Interesting design decisions

- **Error-in-the-output-string** is the opposite of exceptions: printing never
  fails, but a malformed call is visible in the text. Source:
  <https://pkg.go.dev/fmt>.
- **Rune-based width** — a deliberate fix of C's byte semantics, directly
  relevant to Mojo's byte/codepoint/grapheme split.
- **Interfaces over a central trait**: `Stringer` for values, `Formatter` for
  full verb control.
- **`%v` as universal default** plus `%#v` for Go-syntax — a "display" vs
  "debug/source" split like Rust's Display/Debug and Mojo's `write_to` vs
  `write_repr_to`.
- **`%w`** in `Errorf` wraps an error (an unrelated but notable verb).
  Source: <https://pkg.go.dev/fmt>.

## 11. Decisions NOT to copy

- **Silent `%!` output** for bad calls hides bugs; Mojo should surface a typed
  error or refuse at compile time.
- **Runtime-only verb checking** (no compile-time arity/type check).
- **Rune-based width only**: Mojo's three length measures (bytes/codepoints/
  graphemes, buch `mojov1/types/bool-and-strings`) mean a single "rune width" is
  not enough; the caller must choose.
- **`%#v` Go-syntax representation** leaks the language; not portable.

## 12. Ideas fitting Mojo

- **`Stringer`/`Formatter` interface pair** maps almost exactly onto Mojo's
  `Writable` + `Writer` traits (buch `mojov1/stdlib/format`); the lesson is that
  a *formatting trait* and a *destination trait* are separate — Mojo already
  made that split.
- **`Append*` into a caller byte buffer** is a good model for a Mojo builder
  (`StringBuilder`) writing through `Writer.write_string`.
- **Explicit argument indexes** and **`*`-dynamic width** are worth considering
  once a spec mini-language exists.
- **Default `%v`** suggests Mojo's `Writable` default reflection output is the
  right universal default (already shipped).
- The **panic-to-marker** handling of a panicking `String()` is a robustness
  pattern; in Mojo `raises` makes it explicit instead.

## Sources

- Go `fmt` package: <https://pkg.go.dev/fmt>
