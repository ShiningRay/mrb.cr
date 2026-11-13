# Benchmarks

Reference numbers from one machine, not a performance guarantee. Re-run with:

```bash
make bench
```

## Environment

- Date: 2026-11-14
- Machine: Apple Silicon (macOS arm64)
- Crystal 1.21.1, release build
- mruby 4.0.0, core + `mruby-compiler` + `mruby-error`
- Source: [`benchmark/bench.cr`](../benchmark/bench.cr)

## Results

| Operation | Throughput | Mean latency |
|---|---|---|
| State open/close | 44.6k/s | 22.4 µs |
| Eval integer expression (`1 + 2`) | 152.5k/s | 6.6 µs |
| Eval host callback (`add(2, 3)`) | 355.9k/s | 2.8 µs |
| Eval and convert JSON-like array | 482.4k/s | 2.1 µs |

Observations:

- Opening a state allocates the interpreter and is the most expensive
  operation. Reuse one state per worker where possible.
- `eval` compiles source on every call. Compile once with `State#compile` and
  reuse bytecode with `State#load_irep` for repeated execution.
- Callback dispatch is a C trampoline plus a Crystal hash lookup; overhead is
  small compared with compilation.

The host callback and JSON rows include conversion and allocation, so they are
not directly comparable with raw mruby VM throughput.
