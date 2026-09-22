# .changes — how a change is recorded

`.changes/` is the controlled input for the changelog and the version tag.
Every user-visible (or otherwise notable) change lands here as **one file**, and
the release workflow turns those files into `CHANGELOG.md` entries and the next
git tag.

## One file per change

Create a file named `<yyyy-mm-dd>-<short-slug>.md` in `.changes/` (the date first
keeps them ordered; the slug keeps them readable). One file = one change.

Inside, write the change, one category line per change:

```
NEW: base64 — 15-entry public API with base16/base32/base64url
FIX: base64 — streaming decoder accepts padding across chunk boundaries
```

The category must be one of the six below, spelled exactly, followed by `: `.

## Categories

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

MojoAkku stays on **`0.x.y`** — **major is never bumped**. It is a pre-1.0
project, so a breaking change does **not** become `1.0.0`; it bumps the **minor**
(`0.x.0`), exactly like `NEW` and `DEPRECATED`. The version is derived from the
current tag plus the categories present in `.changes/`:

- any `NEW`, `BREAKING` or `DEPRECATED` → minor bump: `0.<x+1>.0`
- only `FIX`, `SECURITY`, `PERFORMANCE` or `INTERNAL` → patch bump: `0.<x>.<y+1>`

`task changes:version` (root Taskfile) computes the next version from the current
`git describe` tag and the categories in `.changes/`. The release workflow uses
that number for the tag and the changelog heading.

## After a release

The release workflow writes the finished `CHANGELOG.md` section and then moves
the consumed change files into `.changes/archive/<version>/`, so `.changes/`
starts empty for the next cycle.
