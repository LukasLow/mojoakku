# MojoAkku — TODO

Deferred work. These points are known and deliberately postponed — they are not
forgotten, just not part of the current phase. Each point names the reason and
the target state.

This file is **not** the library catalogue: `_todos/` holds one YAML file per
planned library and drives the `task` commands, while `TODO.md` (this file)
records deferred work that no library owns.

## 1. Test infrastructure and tests

- **Status:** DONE. Each library ships `mojoakku/<lib>/Taskfile.yml` with a
  `test` task (runs every `_tests/*.mojo` with `mojo run`). The root Taskfile's
  `task test` auto-discovers `mojoakku/*/Taskfile.yml` and dispatches to each
  library's `test`; `task ci` adds optional per-library `ci` hooks. First
  library (base64) has 132 passing tests.

## 2. Git tags and CI

- **Status:** DONE (CI) / ready (tags). `.github/workflows/ci.yml` runs exactly
  `task ci` on push and pull requests. The `.changes/` directory drives the
  changelog and the version: `task changes:version` computes the next `0.x.y`
  (major is never bumped), and `Release.md` writes `CHANGELOG.md` and creates
  the tag. No release tag has been cut yet.

## 3. Automatic upload to prefix.dev

- **Status:** deferred.
- **Why:** Publishing requires a release process (see point 2) and a stable,
  packaged library. Neither exists at this point.
- **Target state:** An automated upload of the Mojo packages to prefix.dev.
  This is **not yet wired into `.agents/workflows/Release.md`** (that workflow
  contains no upload step). The documented path is the modular-community
  recipe: keep `conda.recipe/recipe.yaml` current and let the
  `rattler-build-action` GitHub Action build and host the package on the
  `repo.prefix.dev/modular-community` channel.
