# io Phase 8 — Scaffold Review

## Verdict: APPROVED

Reviewed the scaffold `mojoakku/io_core/` against `NewLibPhase8ScaffoldReview.md`.

| Criterion | Result |
| --- | --- |
| Flat layout: `__init__.mojo`, 15 API files, `_internal/bounds.mojo`, `_dev/`, `_tests/`, `Taskfile.yml` (no `api/`/`API.mojo`/`src/`) | ✓ |
| `_tests/` has `.gitkeep`, no `__init__.mojo` | ✓ |
| 15/15 public symbols have a stub matching `_dev/DESIGN.md` (name, params, return) | ✓ |
| Every public body aborts with `MojoAkku: this API is not yet implemented` (32 sites); only the two `@doc_hidden __init__` field assignments and `@fieldwise_init` value types are non-abort | ✓ |
| Every API file has an end-user `# API-DOCS` block (summary, Signature, What it does, Returns, Errors, Example); `__init__.mojo` has the shared block | ✓ |
| No leaked implementation | ✓ |
| `_internal/` flat (no nested library) | ✓ |
| `Taskfile.yml` `test` task runs `_tests/` | ✓ |
| Signatures match the design (`whence`, `MutSpan[UInt8, _]`, `SpanCursor[origin: Origin[mut=False]]`, `MultiReader[R: Stream]` List-backed, `copy[R: Stream, W: Sink]`) | ✓ |

Findings:
1. **Compile gate** — the reviewer is read-only, so the Manager ran it:
   `cd mojoakku/io_core && task compile` → **`io public API compiles.`** ✓
2. **Workflow wording drift** — Phase 7/8 said the inline blocks carry the seven
   design fields; fixed in a separate repo-infra PR (`workflows-docs-fields`),
   not in the io change (one PR per library).
3. **Doc-example placeholders** (`SomeReader`, `SomeWriter`, `consume(...)`) are
   illustrative; Phase 9 must not copy them as compilable snippets.

**Handoff:** `NewLibPhase9Tests.md`.
