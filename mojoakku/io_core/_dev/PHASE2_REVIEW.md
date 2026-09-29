# io Phase 2 — Research Review

## Verdict: APPROVED

Pass 1 returned `NEEDS_WORK` with 9 findings (2 source-rule violations, 1
unresolved EOF contradiction, 3 unsourced licence claims, 3 minor citation
issues). All were addressed in the commit `io phase 2: research review fixes`:

| # | Finding | Fix |
| --- | --- | --- |
| 1 | js-ts.md misattributed a Python sentence to Node | removed from the Node bullet; moved to a Python-sourced cross-language note (`js-ts.md` §9) |
| 2 | java.md cited the non-existent `mojov1/keywords/async-await` | corrected to `mojov1/keyword-conventions/async-await` (+ `intro/stability`) |
| 3 | EOF representation contradictory (0-sentinel vs explicit) | converged on an **explicit typed EOF outcome** (no 0 sentinel); `java.md` §12 items 1–2 and `c.md` §12 reworded |
| 4 | Unsourced licence claims (bytebufferpool, libuv, libevent) | each now cites its project `LICENSE` file |
| 5 | rust.md wrong `core_io` gate syntax | corrected to per-item `#[unstable(...)]` |
| 6 | cpp.md `<expected>` mis-citation | now cites `/w/cpp/header/expected` |
| 7 | cpp.md unsourced "iostreams are blocking" assertion | marked `(Assessment: derived …)` with a `basic_streambuf` source |
| 8 | go.md citations lack line anchors | pinned to named symbols (verifiable without inventing line numbers) |
| 9 | Heading wording differs from the literal question text | authorised by `_dev/README.md` (adapted question set); no change |

## Outcome

Pass 2 (fresh reviewer): **APPROVED** — all nine findings verified resolved by
reading the files; the corpus still has 13 sections per file and every
non-`GUESS` statement is sourced. One optional precision note (`cpp.md` generic
`/w/cpp/header` for a second `<expected>` claim) was tightened to
`/w/cpp/header/expected`.

The corpus is complete (8 language files, 13 sections each), sourced, and
usable for design. Q5 (buffer/handle ownership), Q7 (byte vs text streams,
buffering, partial read) and Q9 (EOF/error signalling) are covered with cited
evidence across every language. The Mojo side is the buch page
`mojov1/stdlib/io`.

**Handoff:** `NewLibPhase3Design.md`.
