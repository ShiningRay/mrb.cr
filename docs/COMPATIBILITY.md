# Compatibility

> Status: implementation and hardening in progress. The matrix distinguishes
> tested, CI-configured, and unverified targets.

## Runtime versions

| Component | Target |
|---|---|
| mruby | 4.0.0 (pinned) |
| Crystal | >= 1.10 (developed with 1.21.1) |
| Ruby (build only) | >= 3.0 with Rake; not a runtime dependency |
| C compiler | Clang or GCC; MSVC path unverified |

## Platforms

| Platform | Status |
|---|---|
| macOS arm64 | Tested locally (Crystal 1.21.1, mruby 4.0.0) |
| macOS x86_64 | Not tested |
| Linux x86_64 | CI configured (Ubuntu, Crystal latest) |
| Linux arm64 | Not tested |
| Windows x86_64 | Build script provided, unverified |

Windows notes:

- [`scripts/build_windows.ps1`](../scripts/build_windows.ps1) builds
  `lib/libmruby.lib` and `lib/mrb_shim.obj` for the MSVC target.
- The shard's `@[Link]` annotation selects the Windows library names under
  `flag?(:windows)`.
- mruby requires bison and gperf on Windows; the parser sources are generated
  during the build.
- No Windows CI runner is configured yet. Treat Windows as unsupported until a
  smoke run is recorded.

## Supported values

The v1 boundary supports JSON-like values:

- `nil`
- `true` / `false`
- Integer (`mrb_int`, typically 64-bit; no bigint gem in the default build)
- Float
- String (bytes copied; source code must be valid UTF-8)
- Array
- Hash

Arbitrary mruby object types are not automatically converted. Host callbacks
may return `MRuby::Value`, `nil`, `Bool`, `Int32`, `Int64`, `Float64`, or
`String`.

## Not supported

- MRI/CRuby.
- Full Ruby standard library or gems.
- Bundler.
- Multiple interpreters sharing one `State`.
- Thread-safe or fiber-safe shared `State`.
- Automatic Crystal object wrapping.
- A security sandbox.
- bigint values (the default gembox excludes `mruby-bigint`).

## Versioning

- The Crystal API follows semantic versioning.
- mruby upgrades are minor releases only after the compatibility suite passes.
- Removing a public API requires a major version.
- Adding a new supported value type is a minor feature.
- The mruby version is pinned per release and documented in the release notes.
- RITE bytecode is tied to the producing mruby version; do not load bytecode
  across mruby releases.

## Security boundary

`mrb.cr` is a language binding. It does not isolate scripts, enforce CPU or
memory limits, or restrict the mruby API surface by itself. Hosts must provide:

- process or container isolation;
- resource limits;
- a restricted gembox;
- explicit host capabilities;
- input validation.

The default build enables only the interpreter core, `mruby-compiler`, and
`mruby-error`. It does not include IO, sockets, time, or the standard library
extensions.

## Test matrix

| Job | Crystal | mruby | Platform | Status |
|---|---|---|---|---|
| spec (local) | 1.21.1 | 4.0.0 | macOS arm64 | Passing, including ASAN |
| spec (CI) | latest | 4.0.0 | Ubuntu | Configured |
| spec (CI) | latest | 4.0.0 | macOS | Configured |
| examples | latest | 4.0.0 | Ubuntu/macOS | Configured |
| ASAN | 1.21.1 | 4.0.0 | macOS arm64 | Passing |

The suite covers parser and runtime errors, malformed source and bytecode,
arena/ref lifetimes, host callbacks, file loading, and conversion limits.
