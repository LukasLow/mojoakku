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
5 docs            done
6 docs review     done (APPROVED; commit 20f2273)
7 scaffold        done (compiles with Mojo 1.0.0; stubs use abort(...) instead of raise Error(...))
8 scaffold review APPROVED (layout/stubs/inline docs verified; 3 non-blocking notes for phase 9: abort = process exit not catchable error, stdlib base64 name-collision check, .tmp mkdir)
9 tests           done; red baseline 14 files / 0 passed / 14 failed (baseline.log); compile gate via consumer import passes
10 tests review   APPROVED (commit 3bdc9a8)
11 implementation done; all 14 test files green (127 tests, 0 failing); compile gate passes; 3 latent test bugs fixed (see note). next: 12 implementation review
12..13            pending

## Note on test fixes during Phase 11
Three frozen tests were objectively wrong (they contradicted BASE64_DOCS.md and
the one-shot behaviour) and were corrected minimally instead of weakening the
implementation:
- test_base64_decoder.mojo test_feed_holds_sub_quantum_remainder: used a default
  STRICT Decoder with "Zm" and expected success; STRICT must raise
  INVALID_PADDING. Switched to PaddingMode.TOLERANT (the policy that completes an
  unpadded remainder), matching the docs and the sibling
  test_finish_raises_invalid_padding_for_missing_padding.
- test_base64_encoder.mojo test_discard_after_complete_quanta_keeps_them: fed
  "foobar" (6 bytes = two full base64 quanta, nothing held) and claimed "bar" was
  held; changed the input to "foob" (one quantum + one held byte).
- test_base64_padding.mojo test_required_output_decodes_back_strict: compared
  against decode("fo"), which is itself invalid base64; it compares against the
  original bytes now.
These fixes need explicit attention in the Phase-12 review.
