# MojoAkku — TODO

Deferred work. These points are known and deliberately postponed — they are not
forgotten, just not part of the current phase. Each point names the reason and
the target state.

This file is **not** the library catalogue: `_todos/` holds one YAML file per
planned library and drives the `task` commands, while `TODO.md` (this file)
records deferred work that no library owns.

## 1. Test infrastructure and tests

- **Status:** deferred.
- **Why:** The repository currently contains no Mojo libraries yet. The
  `mojoakku/` tree is created in workflow phase 7 (Scaffold), and tests are
  written before implementation in phase 9 (Tests). A test runner would have
  nothing to run until then.
- **Target state:** A per-library `mojoakku/<lib>/Taskfile.yml` with a `test`
  task that runs every `mojoakku/<lib>/_tests/*.mojo` file with `mojo run`
  (there is no `mojo test`; each test file is a program with its own `main()`),
  stopping with a non-zero exit when a file fails. The library Taskfile is
  created in workflow phase 7 (Scaffold) together with the library skeleton, and
  the tests themselves are written in phase 9 (Tests). Optionally a root-level
  `task test` can walk every `mojoakku/<lib>/Taskfile.yml` and run each library's
  `test` task.

## 2. Git tags and CI

- **Status:** deferred.
- **Why:** There is no release yet and no library to build. Tagging or a CI
  pipeline now would encode a process that does not exist.
- **Target state:** Git tags for releases and a CI pipeline that runs the
  build and the test suite on every push, so a broken change is caught before
  it reaches `main`.

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
