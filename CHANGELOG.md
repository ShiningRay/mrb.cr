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
