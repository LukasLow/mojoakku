# MojoAkku

MojoAkku is a collection of independent Mojo libraries that live *beside* the
official Mojo standard library, focused on sockets, TCP, HTTP and closely
related layers. Read [`AGENTS.md`](AGENTS.md) first — it is the project map
(architecture, sibling-library rule, process and buch usage).

## Workflows

The process lives in `.agents/workflows/`. Start at the index,
[`.agents/workflows/README.md`](.agents/workflows/README.md): pick the phase
you are in (new library, bug fix, refactor, review, release) and follow the
matching workflow.

## Library layout

Libraries live directly under `mojoakku/` as siblings — never nested — and a
dependency between libraries is a conceptual edge (`http -> tcp -> socket`),
never a physical parent/child directory. The file list of one library —
including that `_tests/` has **no** `__init__.mojo` — is in
[`AGENTS.md`](AGENTS.md#layout-of-one-library).

## The catalogue (`_todos/`)

`_todos/` is a flat catalogue: one YAML file per planned library with its
status (`todo | current | done`) and its dependencies. The Taskfile reads it
and derives what can be built next.

## Task commands

Run these from the repository root:

| Command | What it does |
| --- | --- |
| `task` | Same as `task todo`: list libraries ready to build right now. |
| `task todo` | List libraries with status `todo` whose dependencies are all `done`. |
| `task all` | List every library as `id  status  name`, sorted by id. |
| `task count` | Count libraries per status, plus the total. |
| `task waiting` | List libraries still waiting for a dependency, and name it. |
| `task test` | Run the `test` task of every library (auto-discovered via `mojoakku/*/Taskfile.yml`). |
| `task ci` | The single CI entry point: every library's tests plus optional per-library `ci` hooks. |
| `task changes:version` | Compute the next `0.x.y` version from the current tag and `.changes/`. |

More commands: `task current` (libraries in progress) and
`task show -- <id>` (print one catalogue file).

## CI and changes

- **CI** (`.github/workflows/ci.yml`) runs exactly one command: `task ci`. The
  root Taskfile auto-discovers every library, so a new library is tested the
  moment its `mojoakku/<lib>/Taskfile.yml` exists — nothing to register.
- **Changes** are recorded as one file per change in `.changes/`, with category
  lines (`NEW`, `FIX`, `SECURITY`, `PERFORMANCE`, `BREAKING`, `DEPRECATED`,
  `INTERNAL`). `Release.md` turns them into `CHANGELOG.md` and the git tag;
  versions stay on `0.x.y` and major is never bumped. See `.changes/README.md`.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
