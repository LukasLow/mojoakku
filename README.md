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
dependency between libraries is a conceptual edge
(`web_http -> net_tcp -> net_socket`), never a physical parent/child directory. The file list of one library —
including that `_tests/` has **no** `__init__.mojo` — is in
[`AGENTS.md`](AGENTS.md#layout-of-one-library).

## The catalogue (`_todos/`) and the capability ledger

`_todos/` is a flat catalogue: one YAML file per planned library with its
status (`todo | current | done`), its dependencies (`depends_on`) and the Mojo
capabilities it needs (`mojoNeeds`). The Taskfile reads it and derives what can
be built next.

`mojoNeeds` keys are defined in [`mojo.yml`](mojo.yml), the **capability
ledger**: what Mojo 1.1.0 can (`have`), partly can (`partial`) or cannot
(`missing`) do, each with a source.

`task todo` applies the **capability gate**: a library is buildable only when
**all three** hold — its status is `todo`, every `depends_on` library is
`done`, and every `mojoNeeds` key is `state: have`. `task todo -- --all` (alias
`task todo-all`) drops the capability filter and shows every dependency-clear
`todo` library with a one-line reason (`ready`, or `needs <capability>
(<state>)`), so planned-but-blocked libraries stay visible.

Architecture decisions live in `docs/adr/` — see
[`docs/adr/0001-namespace-domains.md`](docs/adr/0001-namespace-domains.md) for
the domain-prefix naming rule.

## Task commands

Run these from the repository root:

| Command | What it does |
| --- | --- |
| `task` | Same as `task todo`: list libraries ready to build right now. |
| `task todo` | List libraries that are ready: status `todo`, all `depends_on` `done`, all `mojoNeeds` `have`. |
| `task todo -- --all` | Same, but show every dependency-clear `todo` library with its blocking reason (`ready` or `needs <capability> (<state>)`). Alias: `task todo-all`. |
| `task mojoHave` | List the `mojo.yml` capability keys whose state is `have`. |
| `task all` | List every library as `id  status  name`, sorted by id. |
| `task count` | Count libraries per status, plus the total. |
| `task waiting` | List libraries still waiting for a dependency, and name it. |
| `task test` | Run the `test` task of every library (auto-discovered via `mojoakku/*/Taskfile.yml`). |
| `task ci` | The single CI entry point: every library's tests plus optional per-library `ci` hooks. |
| `task changes:version` | Compute the next `0.x.y` version from the current tag and `.changes/`. |

More commands: `task current` (libraries in progress) and
`task show -- <id>` (print one catalogue file).

## CI, changes and release

- **`.changes/new/`** holds pending change files: one per change, with category
  lines (`NEW`, `FIX`, `SECURITY`, `PERFORMANCE`, `BREAKING`, `DEPRECATED`,
  `INTERNAL`). See `.changes/README.md`.
- **Pull requests** run `.github/workflows/pull-request-check.yml`: it runs
  `task ci` and requires exactly one new `.changes/new/*.md` file.
- **Pushes to `main`** run `.github/workflows/main-push.yml`: it runs `task ci`,
  and if `.changes/new/` is non-empty it releases — updates `CHANGELOG.md`,
  moves the files to `.changes/archive/<tag>/`, and creates the next `0.x.y` tag
  (`major` is never bumped).
- `task ci` is the single test entry point; the root Taskfile auto-discovers
  every library, so a new library is tested the moment its
  `mojoakku/<lib>/Taskfile.yml` exists — nothing to register.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
