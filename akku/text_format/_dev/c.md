# format research: C

## 1. Standard library support

C's entire formatting facility is the **printf family** in `<stdio.h>`: `printf`,
`fprintf`, `sprintf`, `snprintf` and the C11 bounds-checked `printf_s`/`sprintf_s`
/`snprintf_s` variants, plus the `v…` forms taking a `va_list`. Source:
<https://en.cppreference.com/w/c/io/fprintf>.

There is **no owned string type**: everything is a caller-provided
`char*` buffer with a terminating NUL, and the caller owns sizing and lifetime.

## 2. Relevant community libraries

None that add a distinct *model* — the printf family is the de-facto standard.
The {fmt} library (by Victor Zverovich, MIT) that later became `std::format`
originated a safe replacement, but for C the model is exactly `printf`.
(Assessment: derived from
<https://en.cppreference.com/w/cpp/utility/format/format>.)

## 3. Exposed APIs

`int printf(const char* format, ...)`, `int fprintf(FILE*, const char*, ...)`,
`int sprintf(char* buffer, const char*, ...)`, `int snprintf(char* buffer,
size_t bufsz, const char*, ...)`, and `int vsnprintf(char*, size_t, const char*,
va_list)`. Source: <https://en.cppreference.com/w/c/io/fprintf>.

## 4. Error representation

Return value is the number of characters written (or that *would* have been
written for `snprintf`), or a **negative value on an encoding/output error**.
POSIX additionally sets `errno`. Source:
<https://en.cppreference.com/w/c/io/fprintf>. There is no error object; the
caller must inspect the return.

## 5. Ownership semantics

The caller owns the destination buffer. `sprintf` writes into it and the
behavior is **undefined if output plus NUL exceeds the buffer**; `snprintf`
writes at most `bufsz - 1` characters plus a NUL. `snprintf(NULL, 0, …)` is the
documented size-query idiom. Source:
<https://en.cppreference.com/w/c/io/fprintf>. No function allocates.

## 6. Blocking / non-blocking

`printf`/`fprintf` write to a `FILE*` and block on the underlying stream; the
`sprintf`/`snprintf` forms are pure in-memory formatting (no I/O).
(Assessment: derived from the function signatures and descriptions at
<https://en.cppreference.com/w/c/io/fprintf>.)

## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)

`%`-introduced **conversion specifications**:
`%[flags][width][.precision][length]conversion`. Flags: `-` left-justify, `0`
zero-pad, `+` force sign, space sign, `#` alternate form. Width and precision
may be `*`, taking an `int` argument. Length modifiers (`hh h l ll j z t` …)
select the argument's size. Conversions: `%d/%i %u %o %x/%X %f %e/%E %g/%G %a/%A
%c %s %p %% %n`. `%s` precision is the **maximum number of bytes** written.
Precision for integers is the minimum number of digits; default float precision
is 6. Source: <https://en.cppreference.com/w/c/io/fprintf>.

**Locale**: formatting is locale-sensitive through the C locale for the decimal
point and digit grouping; wide-character variants (`wprintf`) exist. Sources:
<https://en.cppreference.com/w/c/io/fprintf> (wide variants),
<https://en.cppreference.com/w/c/locale/setlocale> (`setlocale`, `LC_NUMERIC`);
POSIX additionally specifies the `'` flag for the thousands separator.
(Assessment: derived from the setlocale and fprintf references.)

## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)

This is the danger zone:
- **Type mismatch or too few arguments is undefined behavior** — "If any argument
  … is not the type expected by the corresponding conversion specification, or
  if there are fewer arguments than required by `format`, the behavior is
  undefined." Source: <https://en.cppreference.com/w/c/io/fprintf>.
- **Extra arguments** are evaluated and ignored. Source: ibid.
- **Invalid conversion specifier is undefined behavior.** Source: ibid.
- `sprintf` overflow is undefined; `snprintf` truncates safely. Source: ibid.
- `%n` writes the count so far through a pointer and is "a common target of
  security exploits where format strings depend on user input"; it is rejected
  by the bounds-checked `printf_s` family. Source: ibid.

## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)

There is **no owned type and no view/builder split**. The model is
"caller-supplied buffer + manual size query":
`int sz = snprintf(NULL, 0, fmt, …); char buf[sz+1]; snprintf(buf, sizeof buf, fmt, …);`
Source: <https://en.cppreference.com/w/c/io/fprintf>. Output iterators do not
exist; the C++ layer adds them (see `cpp.md`).

## 10. Interesting design decisions

- **Two-call sizing** (`snprintf(NULL,0,…)`) lets an exact buffer be allocated
  without guessing. Source: <https://en.cppreference.com/w/c/io/fprintf>.
- **Runtime `*` width/precision** pulls width from the argument list — the
  ancestor of dynamic width in Go/Rust/Python.
- **`%n`** is a unique (and dangerous) side-channel.
- Locale is a global process state (`setlocale`), not a parameter — a design
  choice every later language reversed. (Assessment: derived from
  <https://en.cppreference.com/w/c/io/fprintf>.)

## 11. Decisions NOT to copy

- **Undefined behavior on mismatch.** Silent memory corruption is never
  acceptable in MojoAkku; type/arity errors must be checked, not UB.
- **`%n`** and format-string injection. Source:
  <https://en.cppreference.com/w/c/io/fprintf>.
- **Global `setlocale` state** and byte-counted `%s` precision.
- **Type-erased varargs**: no compile-time knowledge of the argument types.

## 12. Ideas fitting Mojo

- **Explicit bounded output / would-be length return**: a Mojo API could return
  the length that *would* be produced, so a caller can size a buffer exactly —
  useful for a `Writer` that pre-sizes.
- **Two-call resize idiom** as a fallback contract if a fixed buffer is supplied.
- The lesson that **arity is the hard part**: Mojo's `raises` can turn C's UB
  into a typed error instead (see `mojo.md`).
- Mojo already has `Writer`/`Writable` (buch `mojov1/stdlib/format`); the C
  lesson is *bounds*, not syntax.

## Sources

- printf/fprintf/sprintf/snprintf: <https://en.cppreference.com/w/c/io/fprintf>
- C++ std::format (heritage of the safe replacement model):
  <https://en.cppreference.com/w/cpp/utility/format/format>
