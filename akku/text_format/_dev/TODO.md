# text_format — backlog

Every API candidate the research showed is theoretically possible in Mojo but not
in scope for this run. One line each: candidate — meaning — origin. `mojo.md`
cites buch pages; `N` is the section of the language file. Items shipped by the
Phase-3 design are removed (see `DESIGN.md`).

- ascii_conversion — `!a` escaping conversion — python.md §7
- argument_reuse — `<` flag re-using the previous argument — java.md §7
- named_arguments — `{name}` keyword-bound placeholders — rust.md §7, python.md §7
- field_attribute_access — `{0.attr}` attribute lookup in a template — python.md §7
- field_item_access — `{0[key]}` index lookup in a template — python.md §7
- dynamic_width — `*`/`{}`/`N$` width or precision pulled from an argument — c.md §7, rust.md §7
- nested_format_spec — replacement fields inside a format spec — python.md §7
- compile_time_spec_check — validate a literal t-template's placeholders/types at compile time — cpp.md §10, rust.md §7
- safe_interpolate — best-effort substitution that never raises — python.md §10
- formatted_length — the length the output would have, for pre-sizing — c.md §10
- string_formatter — a builder-style incremental formatter — java.md §9, rust.md §9
- writable_bridge — adapt any `Writable` value into a template argument — mojo.md (buch `stdlib/format`)
- locale_parameter — explicit locale value for number/date formatting — cpp.md §10, java.md §7
- date_time_format — separate date/time formatting concern — java.md §10
- tagged_renderer — a formatter receiving literal segments for escaping (e.g. HTML) — js-ts.md §10
- i18n_template — `$`-style translatable template separate from general formatting — python.md §10

## Deferred candidates added at Phase 3

- general_float_types — `g`/`G` general, `%` percent and `a`/`A` hex-float presentations — go.md §7, java.md §7, python.md §7
- parse_template — parse a template into its literal/field/spec/conversion parts without rendering — python.md §9, §10
- grapheme_width — width/alignment measured in grapheme clusters or display columns — go.md §7, js-ts.md §11, mojo.md (buch `types/bool-and-strings`)
