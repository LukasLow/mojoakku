# Automatic library commands and smart tests

The baseline is a release tag created after full main CI. No test-status files,
fingerprints, marker commits or CI result cache are needed. Catalogue YAML stays
unchanged. Start pragmatically; deferred enhancements belong in root TODO.md.

## CI policy

- Pull requests run `task ci::smart`.
- Every main push runs `task ci::full`, regardless of the diff or any prior run.
- A release tag is created only after full CI succeeds. A failed check cannot
  create a tag. Release retries must rerun full CI on the new main revision.
- The release commit may change only release metadata (CHANGELOG.md and
  .changes); it must not silently change code or test inputs after full CI.
- The release tag is the reusable baseline. A successful PR or local run does
  not advance it. Thus changed libraries run again on every smart invocation.
- Main pushes containing only INTERNAL/DOCS changes might create no tag. This
  leaves an older baseline and can cause extra PR tests, but does not skip them.

## Commands

| Command | Behavior |
| --- | --- |
| `task <lib>::test` | Always run that library's suite. |
| `task <lib>::compile` | Run its compile task, if provided. |
| `task <lib>::ci` | Run its CI task, or test if no CI task exists. |
| `task test::full` | Test all discovered libraries. |
| `task test::smart` | Test changed libraries and all transitive dependents. |
| `task test::plan` | Show the baseline tag, selected libraries and reasons. |
| `task ci::full` | All library CI checks and mandatory repository checks. |
| `task ci::smart` | Selected library CI checks and mandatory repository checks. |

Initially `task test` and `task ci` remain aliases for full. Workflows explicitly
select smart for PR and full for main so a later alias change cannot weaken main.
Use bounded library concurrency with `JOBS=2` and serial execution with
`JOBS=1`. Test files inside a library remain serial initially.

## Automatic discovery

Find `akku/*/Taskfile.yml` on every invocation. Wildcard tasks (`*::test`, etc.)
read Task's MATCH variable and call the selected library's own Taskfile. No static
includes list or manual library registration. Validate identifiers and paths.
Unknown libraries, missing requested tasks and an empty aggregate discovery are
errors rather than silent successful checks.

The generic `.repo/scrupts/libraries.sh` helper derives its library from the
working directory; no library or API names are registered centrally.

A library's optional `ci` command must run its tests plus additional checks.
Aggregate CI invokes that command once, falling back to test when absent. This avoids running the net_ip suite twice.

## Baseline and changes

Choose the newest eligible release tag on the shared ancestry of the current
revision and the PR target/main branch. Do not blindly use the numerically newest
tag from an unrelated branch. Require a tag from the full-check release process.
Missing eligible tags or insufficient Git history select full checks, never an
empty plan. Both workflows already fetch complete history (`fetch-depth: 0`).

For the current checkout, combine:

- committed differences since that tag;
- staged and unstaged tracked changes;
- nonignored untracked files;
- deleted and renamed files, accounting for old and new owners.

Use NUL-delimited Git output. Compare tag to the actual working tree, not merely
HEAD or the last commit. A net change reverted completely to tagged content need
not trigger a library check unless other relevant inputs differ.

Stashes are not active checkout inputs. Tests cannot verify code that exists only
in a stash. Do not apply or drop stashes. When a stash is applied, its contents
enter the working-tree diff and are included automatically. If stash-aware
planning is later wanted, report it separately without treating the inactive
content as tested.

## Dependency graph

Discover dependencies from real imports in `.mojo` files, including private
modules and tests. Resolve absolute and relative paths, aliases, parenthesized
imports and function-scoped imports. Ignore comments and strings. No catalogue
`depends_on` lookup and no extra dependency manifest.

For `net_socket -> net_ip` and `web_http -> net_socket`, changing net_ip selects
net_ip, net_socket and web_http. Unchanged codec_base64 is not selected.

Use dependency information from both the tag and current sources where needed
for removed/renamed libraries and removed edges. Compute the reverse transitive
closure with a visited set. Unknown local imports or unsupported import syntax
must not silently omit consumers: use a clearly explained full fallback or fail
when even a full check cannot establish a valid project.

Each library owns its native and Python code, including vendored code under
`_internal/`. Inter-library edges are Mojo imports only.

Changes inside a library, including tests and fixtures, select its suite.
Changes to shared runner scripts, root Taskfile, toolchain/lockfiles, CI setup or
shared test infrastructure select all libraries. Markdown files (`.md`) anywhere are explicitly excluded as documentation; this
is a blacklist, not a source-extension whitelist. Other library files remain
relevant, including native/Python code and fixtures. Pure developer notes in _dev,
release metadata and catalogue descriptions do not on their own select suites.
Unclassified changes are conservative full-check triggers.

## Environment and repository checks

The baseline tag proves the full CI configuration that ran, not a successful
run on every OS. PR smart checks reuse that premise only under the reproducible
CI toolchain/platform configuration. Toolchain/configuration changes since the
tag select full. Local runs with an unmatched platform or toolchain must use
full checks rather than claiming tag-backed green evidence. No OS-version status
file is introduced.

Keep namespace and MissingMojo checks mandatory in both CI modes. A repository
check failure makes the full invocation fail. Selected library failures propagate
as nonzero exit status. Output distinguishes RUN / UNCHANGED / FAIL and gives the
selection reason; unchanged suites are not reported as newly passed tests.

## Implementation runtime

Use one Python standard-library runner in `.repo/scrupts/` for discovery,
Git changes, import analysis and bounded process execution. No third-party Python
packages. Python is explicitly available in smd/pixi.
No generated state directory and no CI cache integration.

## Ordered slices and acceptance checks

1. Automatic root dispatch and full pool: prove an added library works without
   root registration, verify paths/errors, concurrency bounds and failure exits.
2. Read-only plan: test a synthetic ip/socket/http chain plus unrelated base64;
   absolute/relative imports, comments, strings, new/deleted/renamed libraries,
   staged/unstaged/untracked/committed changes and eligible-tag selection.
3. Smart execution: prove unchanged affected code is rerun after a prior red
   attempt; no tag means full; shared infrastructure means full; main remains
   full even with no changes. Compare plans with known complete suites.
4. CI wiring: PR explicitly smart, main explicitly full; test that failed full
   CI cannot tag and release metadata cannot alter tested code after the check.

Keep changes independently reviewable. A repeated smart run still rechecks every
library changed since the tag; caching successful local/PR checks is deliberately
outside this first implementation.

## References

- Task wildcard tasks and concurrency: <https://taskfile.dev/docs/guide>
- Mojo imports: local mojov1 buch keywords/import.md and
  intro/packages-and-modules.md, read directly because buch tools are unavailable.
- Current .github/workflows/main-push.yml and pull-request-check.yml.
