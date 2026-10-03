# format research: JS/TS

## 1. Standard library support

JavaScript has **no printf-style formatting function** in the language. The
formatting facility is **template literals** (backtick strings) with
`${expression}` interpolation and **tagged templates**. TypeScript inherits this
unchanged. Sources:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>,
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String>.

Number-to-string helpers exist (`Number.prototype.toFixed`, `toPrecision`,
`toExponential`, `toString(radix)`) but are not a formatting mini-language.
(Assessment: derived from the standard built-in object list at
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number>.)

## 2. Relevant community libraries

Historically `util.format` in Node.js (printf-like) and libraries such as
`sprintf-js` or `string-format` supply printf/`str.format` semantics, but they
are not standards. `Intl.NumberFormat`/`Intl.DateTimeFormat` are the standards
for locale-aware number/date formatting. Sources:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat>,
<https://nodejs.org/api/util.html#utilformatformat-args>.

## 3. Exposed APIs

- Template literal: `` `text ${expr} text` `` → coercion of each expression to
  string, then concatenation.
- Tagged template: `` tagFunction`…` `` calls `tagFunction(strings, ...values)`
  where `strings` is a frozen array with a frozen `.raw` property.
- `String.raw` — identity tag exposing raw (unescaped) strings.
Sources:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>,
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/raw>.

## 4. Error representation

- Malformed escape sequence in an **untagged** template literal → **SyntaxError**;
  in a **tagged** template the restriction is lifted and the bad segment appears
  as `undefined` in the "cooked" array. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>.
- A tag function may return anything (or throw); the language imposes no error
  contract. Source: ibid.
- `Intl` constructors throw `RangeError`/`TypeError` on bad options.
  (Assessment: derived from <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat>.)

## 5. Ownership semantics

Strings are **immutable primitives**; interpolation returns a new string.
Tag arguments (`strings`, `values`) are borrowed/read-only — the `strings` array
and its `.raw` are **frozen**. Source:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>.
GC-managed; no manual lifetime.

## 6. Blocking / non-blocking

Template interpolation is synchronous and in-memory; expressions may be async
values but the tagged-template contract is synchronous (an `async` tag returns a
Promise, which is not awaited by the syntax). (Assessment: derived from
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>.)

## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)

- **Placeholders**: `${expression}`; literal backtick and `${` are escaped with
  `\`. Tagged templates also receive **raw** strings (`strings.raw`).
  Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>.
- **Multi-line**: newlines are literal; a trailing `\` suppresses the newline.
  Source: ibid.
- **Nesting**: templates nest arbitrarily inside `${…}`. Source: ibid.
- **No format spec / width / precision / alignment** in the language. Numeric
  presentation is via `toFixed`/`toPrecision`/`toExponential` or
  `Intl.NumberFormat`. Source: ibid. and
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat>.
- **Locale**: `Intl.NumberFormat`/`Intl.DateTimeFormat` are the locale-aware
  path; bare interpolation uses the default numeric `toString`, which is
  locale-independent. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat>.

## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)

- No arity concept: each `${expr}` embeds a value by lexical closure, so
  "missing/extra argument" is impossible. (Assessment: derived from the template
  literal syntax at
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>.)
- **Tagged templates are the injection-safe pattern**: a tag receives the literal
  parts separately from the substituted values, which is why tags like `html`
  or `sql` can escape untrusted values (the standard "tag for safety" idiom).
  (Assessment: derived from the tag-function contract at
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>.)
- Untagged interpolation coerces `undefined`/`null` to `"undefined"`/`"null"`,
  a common bug source. (Assessment: derived from
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String#string_coercion>.)

## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)

- **Owned result**: a `string` primitive.
- **Borrowed view**: the `strings` array + `.raw` passed to a tag are borrowed and
  frozen. TypeScript can type them as `TemplateStringsArray`.
- **Builder**: `Array.prototype.join` over parts is the idiomatic accumulator; a
  tag function can return a non-string (a closure, a DOM node, …), which is how
  template libraries build structured output. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>.

## 10. Interesting design decisions

- **Tagged templates** turn the template into a function call with the literal
  segments pre-separated — a *composable* formatting mechanism rather than a
  fixed mini-language. Source: ibid.
- **Frozen `strings` array identity**: the same tagged literal always receives the
  same array object, enabling caching/memoization. Source: ibid.
- **Raw vs cooked** strings in one API. Source: ibid.
- **No built-in spec language** keeps the core tiny; `Intl` handles locale.
  (Assessment: derived from the MDN pages above.)
- **Injection safety is opt-in via tags**: the same syntax is safe or unsafe
  depending on whether you tag it. Source: ibid.

## 11. Decisions NOT to copy

- **Untagged interpolation silently stringifies `undefined`/`null`** — surprising.
- **No width/precision/alignment** means every numeric layout is hand-rolled;
  Mojo should keep a spec mini-language.
- **Tag-return-anything** is flexible but untyped and hard for a low-vision API;
  a Mojo equivalent should have a narrow, predictable return contract.

## 12. Ideas fitting Mojo

- **The tagged-template safety idea maps onto Mojo's `TString`**: interpolation
  captures expressions without a shared mutable format buffer, structurally
  avoiding format-string injection. (Assessment: derived from
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>
  and buch `mojov1/basics/literals`.)
- **Tag function = a formatter with access to literal parts** is a powerful
  extension seam; a Mojo formatter could expose the literal segments of a
  `TString` for custom rendering (e.g. HTML escaping).
- **Frozen/immutable inputs** align with Mojo's default `imm` reference.
- Keep the **core interpolation tiny** and push presentation (width/precision)
  into an explicit spec layer.

## Sources

- Template literals (MDN):
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals>
- `String.raw` (MDN):
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/raw>
- String coercion (MDN):
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String#string_coercion>
- `Intl.NumberFormat` (MDN):
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat>
- Node.js `util.format`:
  <https://nodejs.org/api/util.html#utilformatformat-args>
