# `.repo/todo/` — the MojoAkku library catalogue

This folder is the **machine-readable catalogue of every library MojoAkku could
build**. There is exactly **one file per library**, named `<id>.yml`, and all
files sit **flat** in this directory. The flat layout is a core project
decision: no library is nested inside another, not here and not under
`akku/`. The catalogue currently holds **318** entries (4 `done`, and the
`covered_*`/`homeless_*` marker prefixes explained in the ADR).

The catalogue is pure inventory — a library may still be only an idea. Its
`status` says whether work has started, nothing more.

## File schema

Every `<id>.yml` is a small, flat YAML file. Only these keys appear, each at
the start of a line (which is why the Taskfile can parse them with `awk`):

| Key          | Meaning                                                                                   | Allowed values                       |
| ------------ | ----------------------------------------------------------------------------------------- | ------------------------------------ |
| `id`         | Canonical library id; also the file name without `.yml`. `domain_local`, joined with `_`, no nesting. | `^[a-z0-9_]+$` (e.g. `net_udp`)       |
| `name`       | Human-readable display name.                                                              | free text                            |
| `status`     | Whether work has started. **Only three values.**                                          | `todo` \| `current` \| `done`        |
| `depends_on` | Inline list of other catalogue `id`s this library needs first (conceptual graph edges).   | `[]` or `[id, id, ...]`              |
| `mojoNeeds`  | Inline list of Mojo capability keys from `mojo.yml` the library requires.                 | `[pure-mojo]` or `[key, ...]`        |
| `summary`    | One-sentence description of what the library provides.                                    | free text                            |

Example:

```yaml
id: net_udp
name: UDP
status: todo
depends_on: [net_socket]
mojoNeeds: [pure-mojo, net-sockets]
summary: Datagram UDP sockets.
```

A library is buildable only when all its `mojoNeeds` are `have` in `mojo.yml`
and all its `depends_on` libraries are `done`. `mojoNeeds` keys are defined in
[`../mojo.yml`](../../mojo.yml); the naming rule is in
[`../docs/adr/0001-namespace-domains.md`](../../docs/adr/0001-namespace-domains.md).

### There is no `blocked` field — and no `blocked` status

Whether a library can be built **now** is **derived**, never stored. A library
is ready when its `status` is `todo` and every id in its `depends_on` list has
`status: done`. Storing a "blocked" flag would duplicate that information and go
stale the moment a dependency is finished. So the only thing a file records is
what it *needs* (`depends_on`) and how far it is (`status`). `task todo` does
the arithmetic.

## Status lifecycle

```
todo ──▶ current ──▶ done
```

- **todo** — catalogued, not finished. Some `todo` libraries are ready to build
  now; the rest wait for a dependency (see `task todo` / `task waiting`).
- **current** — work is actively running for this library.
- **done** — API, docs, scaffold, tests and implementation exist and passed
  review.

## The dependency graph

`depends_on` references other catalogue **ids**. An edge is a **conceptual
dependency**, never physical nesting: a library may depend on another library
the way `http` depends on `tcp`, but it never lives in that library's folder.

> **Rule: no library inside a library.**

A flat namespace (all libraries siblings under `akku/`) plus this explicit
graph keeps the overview readable — which matters most for a low-vision user.
Use a name prefix for collisions (e.g. `crypto_hash`) instead of nesting.

## Using the Taskfile

Run these from the repository root. The Taskfile uses only `sh`, `awk`, `grep`,
`sed` and `sort`, so it needs no Python, Node, jq or yq.

| Command             | What it prints                                                       |
| ------------------- | -------------------------------------------------------------------- |
| `task`              | Same as `task todo`.                                                 |
| `task todo`         | Every library you can start building **right now** (todo + deps done + `mojoNeeds` all `have`). |
| `task todo -- --all`| Every dependency-clear todo library with its blocking reason (alias `task todo-all`). |
| `task mojoHave`     | The `mojo.yml` capability keys whose state is `have`.                |
| `task current`      | Libraries that are in progress.                                      |
| `task all`          | Every catalogued library as `id  status  name`.                      |
| `task count`        | How many libraries are in each status, plus the total.               |
| `task show -- <id>` | The full YAML file of one library.                                   |
| `task waiting`      | Libraries still waiting for a dependency, and which one is missing.  |

Example output lines (ids are illustrative):

```
$ task todo
text_encoding  Encoding
text_string    String

$ task all
net_socket  done     Socket
net_tcp     done     TCP
net_udp     todo     UDP
web_http    todo     HTTP

$ task count
MojoAkku catalogue: 318 libraries

todo:      314
current:   0
done:      4
total:     318

$ task show -- net_udp
id: net_udp
name: UDP
status: todo
depends_on: [net_socket]
mojoNeeds: [pure-mojo, net-sockets]
summary: Datagram UDP sockets.

$ task waiting
web_http  todo  HTTP  -> waiting for: net_tcp

$ task todo -- --all
async_core  Async       -> needs async (missing)
sync_atomic  Atomic      -> needs threads (partial)
web_http    HTTP        -> waiting for: net_tcp
```

If no library is ready, `task todo` prints a clear "nothing is ready to build
yet" message. If `.repo/todo/` is still empty, every task says so instead of
failing.

## How work actually flows

1. Run `task todo` to see which libraries are unblocked right now.
2. Pick one and set `status: current` in its file while it is being built.
3. The pipeline starts at
   [`.agents/workflows/NewLibPhase1Research.md`](../../.agents/workflows/NewLibPhase1Research.md)
   (research, then API design, docs, scaffold, tests, implementation, review).
4. When the library passes review, set `status: done`. Dependents of it may now
   appear in `task todo`.

## Where the catalogue comes from

The catalogue is the normalized result of a **cross-language stdlib inventory
over 28 languages** (systems, scripting, JVM, BEAM/functional, web and
data/science groups). Each language's standard library and known 1st-party
libraries were checked at the concept level, not the function level. Multiple
names for the same concept were normalized to one canonical MojoAkku `id`. New
ids are still allowed when a concept was missed — the same naming convention
applies: `domain_local`, lowercase, joined with `_`, no nesting. The domain
prefixes are defined in
[`../docs/adr/0001-namespace-domains.md`](../../docs/adr/0001-namespace-domains.md).
