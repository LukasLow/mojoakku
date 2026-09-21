# PerformanceInvestigation

## Purpose
Measure before and after with benchmarks, isolate the bottleneck, and never optimize without a measurement.

## Inputs
- Performance complaint or requirement with a concrete metric (latency, throughput, memory).
- Target scope in `mojoakku/<lib>/`.
- Existing benchmarks or a defined workload/reproduction.
- Baseline measurement of the current code.

## Preconditions
- The full `_tests/` suite of the affected library is green.
- A baseline measurement exists before any optimization edit; no code is changed before it is recorded.
- The performance target is stated numerically and is reproducible.

## Roles
- `manager`: opens the task, states the target metric, routes the work. Manager starts NO Manager.
- `debug`: isolates the bottleneck with profiling evidence.
- `coder`: runs the baseline and post-change benchmarks (via `smd`), returns raw output, and applies the optimization only after the bottleneck is proven.
- `reviewer`: owns the review gate.
- `explore`: maps hot call paths.

## Steps
1. `manager` opens the task and records the target metric and acceptable workload.
2. `coder` establishes the baseline: run the benchmark at least three times and record median and spread.
3. `debug` profiles the workload to isolate the bottleneck, producing evidence per hot path.
4. `explore` maps the hot call paths with `file:line` references to confirm the bottleneck location.
5. `coder` applies the smallest change that addresses the proven bottleneck; only measured bottlenecks are optimized.
6. `coder` re-runs the identical benchmark under identical conditions and records median and spread.
7. `debug` compares before/after, confirms the improvement is real and not measurement noise, and checks for regressions elsewhere.
8. `coder` re-runs the full `_tests/` suite to prove behavior is unchanged.
9. `reviewer` applies the review gate.
10. `manager` commits the optimization with a message naming the metric and the improvement.

## Artifacts / Outputs
- Benchmark script/steps and raw baseline/after output files.
- Profile evidence identifying the bottleneck with `file:line`.
- Optimization diff localized to the bottleneck.
- Before/after comparison table (median, spread, target met or not).
- Task-log entry with the metric and the result.
- One git commit carrying the optimization.

## Review Gate
`reviewer` verifies: (a) a baseline existed before the change, (b) the bottleneck is proven by profiling, not guessed, (c) before/after use the identical workload and conditions, (d) the improvement exceeds measurement noise, (e) behavior is unchanged and tests are green. An optimization without a prior measurement => reject.

## Handoff: Refactor.md if the optimized code needs restructuring, APIReview.md if the hot-path change affects the public API, otherwise close the task.
