# format research: Java

## 1. Standard library support

The **`java.util.Formatter`** class (since Java 5) is "an interpreter for
printf-style format strings" providing "layout justification and alignment,
common formats for numeric, string, and date/time data, and locale-specific
output". Convenience entry points: `String.format(...)`, `System.out.format`,
`PrintStream.printf`, `PrintWriter.printf`. Customization for arbitrary user
types is via the **`java.util.Formattable`** interface. Source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.

## 2. Relevant community libraries

None needed; `Formatter` + `Formattable` cover general use. `java.time.format`
(`DateTimeFormatter`) is the separate, thread-safe date/time formatter — a
notable split from the general `Formatter`. (Assessment: derived from
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.)

## 3. Exposed APIs

`Formatter.format(String format, Object... args)`, `format(Locale l, String
format, Object...)`, `String.format(...)`, `PrintStream.printf(...)`, and the
`Formattable.formatTo(Formatter, int flags, int width, int precision)` contract.
Date/time conversion suffixes `%t…`/`%T…`. Source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.

## 4. Error representation

Java is **strict where C is silent**: incompatible flag/conversion or unknown
conversion **throws**. Documented exceptions include
`UnknownFormatConversionException`, `UnknownFormatFlagsException`,
`IllegalFormatConversionException`, `IllegalFormatWidthException`,
`IllegalFormatPrecisionException`, `MissingFormatWidthException`,
`FormatFlagsConversionMismatchException`, `IllegalFormatCodePointException`,
and the base `IllegalFormatException`. Source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.

## 5. Ownership semantics

`Formatter` is `Closeable`/`Flushable`; it writes to an `Appendable`
(`StringBuilder`, stream). `String.format` returns a **new immutable `String`**.
"Formatters are not necessarily safe for multithreaded access. Thread safety is
optional." Source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.

## 6. Blocking / non-blocking

In-memory/`Appendable`-based; blocking only when the underlying `Appendable`
blocks (e.g. an output stream). No async in the formatting API. (Assessment:
derived from the `Appendable` target and `Closeable` at
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.)

## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)

Two specifier forms:
- general/character/numeric: `%[argument_index$][flags][width][.precision]conversion`
- date/time: `%[argument_index$][flags][width]conversion` (two-char `t`/`T`).
Source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.

- **Conversions** grouped General (`b h s`), Character (`c`), Numeric Integral
  (`d o x X`), Numeric Floating (`e E f g G a A`), Date/Time (`t`/`T` + suffix),
  Percent (`%`), Line Separator (`n`). Uppercase = same but upper-cased per
  locale. Source: ibid.
- **Flags** `- # + space 0 , (`. Source: ibid.
- **Argument index** one-based (`1$`), and the `<` flag re-uses the previous
  argument. Source: ibid.
- **Precision** is the number of digits after the radix point for `e`/`f`
  (default 6) or total significant digits for `g`; not applicable to integral/
  char/date and throws if given. Source: ibid.
- **Locale**: constructor/overload `loc`; the default locale is used otherwise.
  `Formatter` is "locale-specific output"; upper-case conversions use the
  prevailing locale. Source: ibid.

## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)

- Unknown conversion / incompatible flag → **throws** (`UnknownFormatConversion…
  `, `FormatFlagsConversionMismatchException`). Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.
- Wrong conversion for the argument type → `IllegalFormatConversionException`.
  Source: ibid.
- Invalid width/precision/index → `IllegalFormatWidthException`/
  `IllegalFormatPrecisionException`/`IllegalFormatException`. Source: ibid.
- `null` argument for general/char/numeric/date → the literal string `"null"`.
  Source: ibid.
- Java has **no `%n`-style `%n` pointer write** (its `%n` is the line separator),
  so there is no C-style `%n` memory hazard. (Assessment: derived from the
  conversions table at
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.)
- A runtime `String` format is allowed (dynamic), so a format string from user
  input can trigger `IllegalFormatException` — a controlled failure, not memory
  corruption.

## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)

- **Owned result**: immutable `String`.
- **Borrowed view**: `CharSequence` is the general text abstraction;
  `Formattable` receives the `Formatter` plus flags/width/precision.
- **Builder**: `Formatter(Appendable)` with `StringBuilder` is the canonical
  incremental path; `Formattable.formatTo` writes directly into the `Formatter`.
  Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>.

## 10. Interesting design decisions

- **Strictness as a feature**: "Java formatting is more strict than C's; …
  if a conversion is incompatible with a flag, an exception will be thrown. In C
  inapplicable flags are silently ignored." Source: ibid.
- **`Formattable` interface** for user types, passing flags/width/precision so a
  type can honour layout. Source: ibid.
- **`<` flag** to reuse the previous argument — compact repetition. Source: ibid.
- **Two-character date/time conversions** (`%tY`, `%tm`, `%td`, `%tT`) built into
  the general formatter. Source: ibid.
- **Locale is a parameter/constructor** argument, with `Locale.Category.FORMAT`
  default. Source: ibid.
- Note: "recognizable to C programmers but not necessarily completely compatible
  with those in C." Source: ibid.

## 11. Decisions NOT to copy

- **Exception-per-malformed-spec** for a plain string operation is heavy; Mojo
  should prefer compile-time checking plus `raises` on a runtime path.
- **`%t…` date/time built into the general formatter** bloats the spec; better a
  separate date formatter (cf. `java.time.format`).
- **`"null"` substitution** silently hides missing values.
- **Not thread-safe by default** with optional safety is a confusing contract.

## 12. Ideas fitting Mojo

- **`Formattable`-style trait receiving width/precision/flags** maps onto a Mojo
  `Writable`-like trait that can inspect formatting parameters; Mojo could pass a
  format-options struct instead of three ints.
- **Argument reuse (`<`)** and **explicit one-based indexes** are worth noting
  for a future spec mini-language.
- **Strictness is the right default** for MojoAkku: reject incompatible
  flag/conversion combinations rather than ignore them (contrast C).
- **Locale as a value** passed explicitly, matching Mojo value semantics.
- The **split between general `Formatter` and date/time formatting** argues for
  separate concerns in Mojo rather than one mega-spec.

## Sources

- java.util.Formatter (Java SE 21):
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formatter.html>
- java.util.Formattable:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Formattable.html>
- java.lang.String#format:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/String.html#format(java.lang.String,java.lang.Object...)>
- java.time.format.DateTimeFormatter:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/format/DateTimeFormatter.html>
