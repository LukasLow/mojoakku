# time_clock — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected
end state.

## Duration arithmetic extras

- `saturating_add`/`saturating_sub`/`saturating_mul` — clamping arithmetic that stops at the representable bound. (origin: `rust.md` §3)
- `checked_add`/`checked_sub`/`checked_mul`/`checked_div` — variants that return an optional "overflow / not representable" result instead of wrapping or raising. (origin: `rust.md` §3)
- `abs_diff` — non-panicking absolute difference between two durations. (origin: `rust.md` §3)
- `round`/`truncate` to a unit — snap a duration to a multiple of a unit. (origin: `go.md` §3)

## Duration construction / conversion

- `from_secs_f64`/`from_millis`/`from_micros` unit constructors — build a duration from a named unit. (origin: `rust.md` §3)
- float-seconds constructor with a checked `try_*` form — accept fractional seconds without an unchecked panic. (origin: `rust.md` §4)
- `parse_duration` — parse a duration from a string. (origin: `go.md` §3)
- `Duration.to_string` — format a duration human-readably. (origin: `go.md` §3)

## Clock / instant extras

- `clock_resolution` — report the clock's expected resolution. (origin: `python.md` §10)
- `now_wall` — a separate wall/system clock alongside the monotonic one. (origin: `c.md` §10, `rust.md` §10)
- `measure_time` — helper returning a duration measured around a block. (origin: `kotlin.md` §10)
- `test_clock` / injectable time source — deterministic time for tests. (origin: `kotlin.md` §10)

## Timeout / cancellation

- `sleep(Duration)` — blocking sleep primitive. (origin: `c.md` §12, `go.md` §6)
- `cancel` — explicit cancellation token for a pending wait. (origin: `go.md` §11, `js_ts.md` §10)
- `infinite` / no-timeout sentinel — explicit "no deadline" state. (origin: `kotlin.md` §10)

## Out of scope but possible

- calendar/date — wall-clock calendar arithmetic, belongs in a separate library. (origin: `c.md` §1)
