# Task lib-base64 — MojoAkku library base64 (template library)

Goal: build mojoakku/base64 through the full 13-phase NewLib pipeline. It is the
first library and therefore the template every later library copies.

Status: restarting from scratch after the workflows were reworked (max 6
researchers one per group, researchers write `.research/<lang>.md` directly,
`src/` + `api/` layout, per-library Taskfile, user API-review gate, commit per
phase).

## Frozen run config
See mojoakku/base64/.research/README.md (selected languages, adapted question set).

## Who does what
- researchers (max 5 for this run): one per language group, each writes
  `.research/<lang>.md` directly; they never report through a docs agent.
- reviewer: phase 2 review (completeness, sources, contradictions).

## Phase status
1 research        done (C, C++, Go, Rust, Python, Perl, JS/TS, Java, Elixir + Mojo buch)
2 research review APPROVED
3 design          done; user approved the public API (BASE64_DOCS.md, 15 entries)
4 design review   APPROVED (5 passes; 3 items open with Phase-7 compile checks)
5..13             pending
