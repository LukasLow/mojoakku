# .changes — how a change is recorded

`.changes/` is the controlled input for the changelog and the version tag. It
has exactly two areas:

```
.changes/
  new/                 # pending changes — written by humans / pull requests
    <yyyy-mm-dd>-<slug>.md
  archive/             # released changes — created by CI only, one subfolder per tag
    <tag>/<file>.md
```

- **`new/` is the input.** Every pull request adds **exactly one** Markdown file
  here. A file that sits in `new/` is by definition pending: it has not been
  released yet. No extra status field is needed.
- **`archive/` is the output.** The `main-push` workflow creates
  `.changes/archive/<tag>/` and moves the released files there. **Nobody writes
  or moves anything in `archive/` by hand** — CI owns it.

## The change file

Name it `<yyyy-mm-dd>-<short-slug>.md` (the date first keeps them ordered; the
slug keeps them readable). The file holds one category line per change:

```markdown
NEW: base64 — 15-entry public API with base16/base32/base64url
FIX: base64 — streaming decoder accepts padding across chunk boundaries
```

## Categories

The category lines drive the version. One file may carry several lines:

| Category | Means | Version effect |
| --- | --- | --- |
| `NEW:` | a new user-visible capability | **minor** |
| `BREAKING:` | an incompatible change to an existing API | **minor** |
| `DEPRECATED:` | something is marked for removal | **minor** |
| `FIX:` | a bug fix | **patch** |
| `SECURITY:` | a security fix | **patch** |
| `PERFORMANCE:` | a performance improvement | **patch** |
| `INTERNAL:` | not user-visible (build, docs, refactor, tests) | **patch** |

## Versioning rule (IMPORTANT)

MojoAkku stays on **`0.x.y`** — **major is never bumped**. A break is a **minor**
bump (`0.x.0`), exactly like `NEW` and `DEPRECATED`. The version is derived from
the current tag plus the categories of the pending files in `new/`:

- any `NEW`, `BREAKING` or `DEPRECATED` → minor: `0.<x+1>.0`
- only `FIX`, `SECURITY`, `PERFORMANCE` or `INTERNAL` → patch: `0.<x>.<y+1>`

## The release flow

Triggered by a push to `main` (`.github/workflows/main-push.yml`):

1. `task ci` runs (nothing is released unless the suite is green).
2. `sh .github/scripts/release-prepare.sh` computes the next `0.x.y`, prepends
   the changelog section, and **moves** the released files from `new/` into
   `.changes/archive/<version>/`.
3. The workflow commits the changelog and the moves, tags `v<version>` and
   pushes both atomically (with retry if `main` moved meanwhile).

With nothing in `new/`, nothing is released — the push only runs the tests.
