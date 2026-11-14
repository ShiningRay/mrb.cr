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
| Windows x86_64 (MSYS2 UCRT64 gcc, mingw32 target) | Smoke-tested locally (Crystal 1.22.1, ruby 4.0.6, gcc 16.2.0, mruby 4.0.0, 2026-11-14; full `crystal spec` 84 examples, 0 failures) — see Windows notes |
| Windows x86_64 (MSVC) | Build script provided, unverified |

Windows notes:

- [`scripts/build_windows.ps1`](../scripts/build_windows.ps1) supports MSVC
  (`cl.exe`) and MinGW gcc toolchains. It copies the mruby build config to a
  writable build path, builds mruby 4.0.0, and produces canonical
  `lib/libmruby.a` + `lib/mrb_shim.o` with `.lib`/`.obj` aliases.
- The shard's `@[Link]` annotation (Windows branch) links the canonical
  `lib/libmruby.a` and `lib/mrb_shim.o` for Crystal's mingw32 target.
- bison and gperf are not required to build a release tag; mruby ships a
  pregenerated parser. They are only needed when checking out mruby from git
  or regenerating the parser after a grammar change.
- Local smoke (MSYS2 UCRT64, Crystal default target `x86_64-w64-windows-gnu`):
  `ruby -S rake -j4` in `vendor/mruby` with config copied to
  `vendor/mruby/build/mrb_cr.rb`, `gcc -O2 -I... -c src/mrb/shim.c`, and
  `crystal build src/mrb.cr` succeeded. Full `crystal spec`: 84 examples,
  0 failures, 0 errors.
  MSVC target/build remains unverified.
- No Windows CI runner executed locally; GitHub Actions Windows status is
  unverified in this session.

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
