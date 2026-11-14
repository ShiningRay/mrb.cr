## 0.2.1 (2026-11-14)

- Fix: report 0.2.1 in MRuby::VERSION (was incorrectly 0.1.0 in 0.2.0). No API changes.

## 0.2.0 (2026-11-14)

- Added Windows MinGW (MSYS2 UCRT64) build support and canonical native library artifact names.
- Added writable mruby config copy to avoid .lock writes into read-only directories.
- Added block/Proc API: Args#block_given?, Args#block, State#yield, State#funcall, Value#proc?, Ref.proc, Ref.open_proc.
- State#funcall and State#yield now use mrb_protect and preserve Ruby exception details.
- Updated documentation for Windows status, block/Proc usage, and API signatures.

# Changelog

## 0.1.0 (2026-11-14)

- Repository scaffold.
- Initial design and implementation plan.
- Link mruby 4.0.0 as a pinned static library (M0).
- Minimal `MRuby::State` open/close lifecycle with block cleanup.
- `State#eval` / `State#load_string` with protected evaluation (M1).
- JSON-like `MRuby::Value` conversion for nil, bool, integer, float, string,
  array, and hash, plus `to_crystal` with depth and node limits.
- Structured `MRuby::Error` with script class and message; parser diagnostics
  are captured instead of printed.
- Deterministic `MRuby::StateClosedError` for use after close.
- `MRuby::Arena` / `State#arena` GC arena save/restore with exception safety
  (M2).
- `MRuby::Ref` long-lived GC references with idempotent release and a block
  form.
- Diagnostic `State#gc_full` and `State#live_object_count` helpers with
  bounded-allocation stress coverage.
- Host class, module, method, class-method, module-function, and constant
  registration (M3).
- `MRuby::Args` with explicit arity checking and a single C trampoline.
- Crystal exceptions and argument errors are translated into mruby
  `RuntimeError` / `ArgumentError` with stable messages.
- `State#load_file` with file and line reporting for script errors (M4).
- `State#compile` and `State#load_irep` for RITE bytecode.
- Examples for calculator, host callbacks, and JSON-like value conversion,
  plus an embedding guide and `make examples`.
- Hardening (M5): malformed source and bytecode fuzz specs, UTF-8 source
  validation, ASAN build target, and conversion limit coverage.
- Release-mode benchmarks (`make bench`) and recorded reference numbers.
- Windows build script and platform-specific link names; Windows remains
  unverified.
- Compatibility matrix updated to distinguish tested and CI-configured targets.
