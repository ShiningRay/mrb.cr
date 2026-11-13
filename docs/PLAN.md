# Implementation Plan

> Status: planning. Milestones are completed only when their acceptance criteria
> pass on a real build.

## Guiding constraints

- mruby 4.0.x is the first target.
- One interpreter state per process or host.
- No implicit wrapping of arbitrary Crystal classes in v1.
- Every milestone ends with tests, documentation, and a clean build.
- The binding stays small; features that belong to the host do not enter the
  binding.

## M0: repository and build spike

Goal: prove that Crystal can link a minimal mruby 4.0.x static library on the
primary platforms.

Deliverables:

- Pin an mruby 4.0.x tag and record the exact version.
- Build script or `Makefile` that fetches and builds `libmruby.a`.
- Minimal `lib LibMRuby` declarations for `mrb_open` and `mrb_close`.
- A smoke spec that opens and closes a state.
- CI skeleton for Crystal formatting and specs.
- Documented gembox and build prerequisites.

Acceptance criteria:

- `crystal spec` passes on macOS arm64.
- The mruby build is reproducible from a clean checkout.
- The linked binary starts and exits without a crash.
- The build does not require a Ruby runtime after `libmruby.a` is produced.
- The exact mruby tag and build flags are recorded in the README or a build
  manifest.

Risks:

- mruby 4.0 build may require a newer Ruby/Rake than the local environment.
- Static linking flags differ across Linux, macOS, and Windows.
- Crystal's `@[Link]` path resolution needs a stable layout.

## M1: state, values, and errors

Goal: make a small, safe evaluation path usable.

Deliverables:

- `MRuby::State.open` and `State#close`.
- `State#eval` / `State#load_string`.
- `MRuby::Value` for nil, bool, integer, float, string, array, and hash.
- `MRuby::Error` for parse and runtime errors.
- Numeric range checks and string copying.
- Specs for success and failure paths.

Acceptance criteria:

- Evaluating valid Ruby returns the expected Crystal value.
- A syntax error and a runtime exception both produce `MRuby::Error` with a
  useful message.
- Unsupported object types fail with a clear error, not a pointer leak.
- `State.open` closes the state when the block raises.
- No mruby value escapes its state.

## M2: GC arena and references

Goal: make lifetime rules explicit and testable.

Deliverables:

- `MRuby::Arena` block helper with save/restore.
- `MRuby::Ref` with GC registration and release.
- Documentation of temporary vs long-lived values.
- Stress tests that allocate many values across arena scopes.
- Tests for use-after-close and invalid ref errors.

Acceptance criteria:

- Values created inside an arena are restored when the block exits.
- A `Ref` survives repeated GC cycles until released.
- Releasing a `Ref` twice is safe or raises a clear error.
- Using a value after `State#close` raises a deterministic error.
- A 100k-value allocation loop does not grow memory without bound.

## M3: classes, modules, methods, constants

Goal: allow host code to expose a narrow API to scripts.

Deliverables:

- `define_class`, `define_module`, `define_method`, `define_const`.
- `MRuby::Args` with arity validation.
- Typed callback registration for common signatures.
- Crystal exception to mruby error translation.
- Tests for instance methods, module functions, constants, and arity errors.

Acceptance criteria:

- A script can call a host-defined method and receive the converted result.
- Wrong arity produces a clear mruby error.
- A Crystal exception becomes a mruby runtime error with a stable message.
- No arbitrary Crystal object can be passed accidentally.
- Method registration is removed cleanly when the state closes.

## M4: file loading, bytecode, examples

Goal: cover the embedding paths a host actually needs.

Deliverables:

- `State#load_file`.
- `mrb_load_irep` support if the C API is stable in the pinned version.
- Error location mapping for file-based scripts.
- Examples: calculator, host callback, JSON-like value conversion.
- Documentation for embedding in a host process.

Acceptance criteria:

- Loading a valid `.rb` file returns a value.
- A syntax error in a file reports the file and line.
- A bytecode load path is either implemented and tested or explicitly deferred.
- Examples run in CI or a documented smoke script.

## M5: hardening and cross-platform

Goal: make the binding safe to depend on for a host process.

Deliverables:

- ASAN or valgrind runs where supported.
- Fuzz or malformed-input tests for parser and value conversion.
- Windows build path and CI.
- macOS CI.
- Benchmarks for open/close, eval, and callback overhead.
- API documentation pass.

Acceptance criteria:

- Linux and macOS CI are green.
- Windows build and smoke test are green or the limitation is documented.
- No known memory leaks in the stress suite.
- Malformed input cannot crash the host process in the test suite.
- Public API has no undocumented ownership rules.

## M6: 0.1.0 release

Goal: publish a small, honest first release.

Deliverables:

- API freeze for 0.x.
- README quick start and examples.
- CHANGELOG.
- Tag and release notes.
- Compatibility statement for mruby and Crystal versions.

Acceptance criteria:

- `crystal spec` and format check pass on supported platforms.
- A clean consumer project can depend on the shard and run the README example.
- The release notes state what is not supported.
- No claim of sandboxing or production readiness beyond the tested scope.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| mruby 4.0 build is not reproducible | M0 blocked | Pin tag, document flags, add CI cache |
| GC lifetime bug | Crashes or leaks | Arena/ref rules, stress tests, no raw values |
| Crystal C ABI mismatch | Link failures | Minimal `lib` surface, platform CI |
| Windows toolchain differences | Platform gap | Separate Windows milestone, MSVC-first |
| API grows into a framework | Maintenance burden | Non-goals, explicit review, keep host logic out |
| Error mapping loses location | Poor debugging | Store file/line/class, test syntax and runtime errors |
| Thread misuse | Data races | Document one-state-per-process; no hidden mutex |

## Definition of done for 0.1.0

- The binding can open a state, evaluate code, convert JSON-like values, call a
  host method, and surface errors.
- GC/ref rules are documented and tested.
- Linux and macOS are supported and tested.
- Windows is either supported or explicitly marked unsupported.
- The README and API docs match the actual behavior.
- No untested security claims.
