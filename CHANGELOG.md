# Changelog

## 0.1.0 (unreleased)

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
