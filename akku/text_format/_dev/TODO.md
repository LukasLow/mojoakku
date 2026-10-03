# text_format — backlog (seed)

Every API candidate the Phase-1 research showed is theoretically possible in Mojo
but not in scope for this run. One line each: candidate — meaning — origin.
`mojo.md` cites buch pages; `N` is the section of the language file.

- format_spec — a parsed width/precision/alignment/sign/type specification — python.md §7, rust.md §7
- format_spec_parser — parse and validate a spec string into a typed spec value — cpp.md §10, rust.md §7
- template_placeholder — a named/indexed placeholder bound to an argument — python.md §7
- format_template — runtime template with `{}`/`{n}`/`{name}` fields — python.md §1
- interpolate — build a `String` from a template and typed arguments — rust.md §7, python.md §7
- width — minimum field width, static or dynamic — go.md §7, rust.md §7
- precision — digits after the point / max characters / significant digits — python.md §7
- alignment — left/right/center/`=` sign-aware padding — python.md §7, rust.md §7
- fill_char — custom padding character before an alignment — rust.md §7
- sign_mode — always/negative-only/space sign control — java.md §7, go.md §7
- alternate_form — `#` prefixes (`0x`/`0b`/`0o`) and forced decimal point — rust.md §7, python.md §7
- zero_pad — sign-aware zero padding (`0` flag) — rust.md §7
- digit_grouping — locale/literal separators `,` and `_` — python.md §7, java.md §7
- radix_types — `b`/`o`/`x`/`X` integer presentations — go.md §7, python.md §7
- float_types — `e`/`E`/`f`/`F`/`g`/`G`/`a`/`A` and `%` — go.md §7, java.md §7
- char_codepoint_type — `c` formats an integer as a Unicode character — go.md §7, python.md §7
- repr_conversion — `!r`/`r` debug representation conversion — python.md §7, rust.md §7
- ascii_conversion — `!a` escaping conversion — python.md §7
- argument_index — explicit one-based field indexing `{n}`/`%n$` — java.md §7, go.md §7
- argument_reuse — `<` flag re-using the previous argument — java.md §7
- auto_numbering — implicit `{}` sequential binding — python.md §7
- named_arguments — `{name}` keyword-bound placeholders — rust.md §7, python.md §7
- field_attribute_access — `{0.attr}` attribute lookup in a template — python.md §7
- field_item_access — `{0[key]}` index lookup in a template — python.md §7
- dynamic_width — `*`/`{}`/`N$` width or precision pulled from an argument — c.md §7, rust.md §7
- nested_format_spec — replacement fields inside a format spec — python.md §7
- literal_brace_escape — `{{`/`}}` escaping rule for a runtime formatter — python.md §7, rust.md §7
- compile_time_spec_check — validate a literal t-template's placeholders/types at compile time — cpp.md §10, rust.md §7
- format_error — typed error for malformed template / bad placeholder — java.md §4, python.md §4
- arity_error — typed error for missing or extra arguments — java.md §8, python.md §4
- type_mismatch_error — typed error when a value cannot use the requested spec — java.md §4, python.md §4
- safe_interpolate — best-effort substitution that never raises — python.md §10
- format_to_writer — write formatted output through `Writer` without an owned String — rust.md §9, go.md §3
- formatted_length — the length the output would have, for pre-sizing — c.md §10
- string_formatter — a builder-style incremental formatter — java.md §9, rust.md §9
- writable_bridge — adapt any `Writable` value into a template argument — mojo.md (buch `stdlib/format`)
- display_vs_debug — separate user-facing and debug representations — rust.md §10, go.md §10
- number_format — decimal width/precision/sign/grouping for numeric types (hex/oct/bin already ship via `hex`/`oct`/`bin`) — mojo.md (buch `stdlib/builtin`), python.md §7
- locale_parameter — explicit locale value for number/date formatting — cpp.md §10, java.md §7
- date_time_format — separate date/time formatting concern — java.md §10
- tagged_renderer — a formatter receiving literal segments for escaping (e.g. HTML) — js-ts.md §10
- i18n_template — `$`-style translatable template separate from general formatting — python.md §10
