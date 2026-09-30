# ADR 0002 — akku public namespace

- **Status:** accepted (2026-09-30; user-approved namespace migration).
- **Context:** MojoAkku's public source-root name was `mojoakku`. A shorter
  import prefix should not rename the project or undo ADR 0001's flat,
  domain-prefixed sibling libraries.

## Decision

1. Move the source root to `akku/`. Consumers import
   `from akku.<domain_local> import ...`, with the repository root on the
   import search path. `akku` is a namespace directory, not an API aggregator;
   each sibling retains its own `__init__.mojo` and public re-exports.
2. Keep library names and layout unchanged: `akku.codec_base64`, `akku.io_core`,
   `akku.prim_bit`, `akku.text_string`. Do not introduce `akku.net.ip` or other
   nested domain hierarchies.
3. Do not provide a `mojoakku` compatibility directory, module or compiled
   alias. Treat this as a breaking change, with migration guidance in README
   and exactly one pending `BREAKING:` change file. Under repository policy,
   the release stays `0.x.y` and receives a minor bump, never a major bump.
4. Preserve MojoAkku branding, `LukasLow/mojoakku` repository URLs, workspace
   identity, historical release/archive/session records and prior review/test
   evidence. Moved historical library records retain their original contents.
5. Update active code, tests, task discovery, docs and workflows together.
   Library behavior, dependency edges, capability ledger and catalogue status
   are not changed by the namespace migration.

## Consequences and migration

- Change imports `mojoakku.<lib>` to `akku.<lib>` and paths `mojoakku/<lib>/`
  to `akku/<lib>/`. Existing bare sibling imports used by the library tests
  become `akku.<lib>` as well.
- Replace `-I mojoakku` with `-I .` from the repository root; library-local
  test/compile tasks use `-I ../..`, not `-I ..`. External consumers pass the
  repository root, not its `akku/` directory.
- Rebuild namespace-dependent precompiled artifacts; changing a `.mojoc`
  filename alone does not change its encoded package name.
- `task ci` keeps auto-discovering sibling Taskfiles and checking MissingMojo
  markers under the new root. It additionally runs a repository-root consumer
  regression and checks that the removed import fails for module-not-found.
- A compatibility alias was rejected: it would leave two public namespaces
  and obscure stale imports rather than establishing the approved single root.

## References

- User approval and acceptance criteria: project `2faadf38`.
- [ADR 0001](0001-namespace-domains.md), [README](../../README.md).
- Buch `mojov1/intro/packages-and-modules`: Mojo 1.x supports imports through
  regular namespace directories, package names follow source directory names,
  and precompiled package names require recompilation to change.
