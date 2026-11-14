# Compatibility

> Status: implementation and hardening in progress. The matrix distinguishes
> tested, CI-configured, and unverified targets.

## Runtime versions

| Component | Target |
|---|---|
| mruby | 4.0.0 (pinned) |
| Crystal | >= 1.10 (developed with 1.21.1) |
| Ruby (build only) | >= 3.0 with Rake; not a runtime dependency |
| C compiler | Clang or GCC; on Windows MSYS2 UCRT64 gcc for the Crystal mingw32 target; MSVC verified at the C layer only (see platforms) |

## Platforms

| Platform | Status |
|---|---|
| macOS arm64 | Tested locally (Crystal 1.21.1, mruby 4.0.0) |
| macOS x86_64 | Not tested |
| Linux x86_64 | CI configured (Ubuntu, Crystal latest) |
| Linux arm64 | Not tested |
| Windows x86_64 (MSYS2 UCRT64 gcc, mingw32 target) | CI configured (windows-latest: full `crystal spec`, examples, C smoke) and smoke-tested locally (Crystal 1.22.1, gcc 16.2.0, mruby 4.0.0, 2026-11-14) — see Windows notes |
| Windows x86_64 (MSVC, C layer) | CI configured (windows-latest: mruby `visualcpp` build, `cl.exe` shim, C smoke run) |

Windows notes:

- The supported Crystal path on Windows is the official mingw32 target
  (`x86_64-w64-windows-gnu`) with MSYS2 UCRT64 gcc. The shard's `@[Link]`
  annotation branches on `flag?(:gnu)` and links `lib/libmruby.a` +
  `lib/mrb_shim.o` for MinGW, or `lib/libmruby.lib` + `lib/mrb_shim.obj` for
  an MSVC-target Crystal build.
- [`scripts/build_windows.ps1`](../scripts/build_windows.ps1) supports MSVC
  (`cl.exe`) and MinGW gcc toolchains. mruby's toolchain is auto-detected via
  `VisualStudioVersion`/`VSINSTALLDIR` (Developer Command Prompt → visualcpp).
  It copies the mruby build config to a writable build path and stages both
  artifact name pairs (`libmruby.a`/`mrb_shim.o` and `libmruby.lib`/
  `mrb_shim.obj`); one file of each pair is a byte copy of the toolchain's
  native output.
- MSVC specifics: mruby's `visualcpp` toolchain archives with `lib.exe` into
  `libmruby.lib` and compiles with `/MD` + `MRB_STACK_EXTEND_DOUBLING`; the
  shim is compiled with the same flags so both sides share one ABI view.
- [scripts/c_smoke.c](../scripts/c_smoke.c) is a Crystal-independent C smoke
  test (eval, exception flag, message extraction) that CI builds and runs
  under gcc and cl.exe. The Crystal MSVC target itself is not distributed
  upstream, so Crystal linking on Windows remains mingw32; MSVC artifacts are
  verified at the C layer only.
- bison and gperf are not required to build a release tag; mruby ships a
  pregenerated parser. They are only needed when checking out mruby from git
  or regenerating the parser after a grammar change. The Windows CI job
  builds without them on purpose.
- Local smoke (MSYS2 UCRT64, Crystal default target `x86_64-w64-windows-gnu`):
  `ruby -S rake -j4` in `vendor/mruby` with config copied to
  `vendor/mruby/build/mrb_cr.rb`, `gcc -O2 -I... -c src/mrb/shim.c`, and
  `crystal build src/mrb.cr` succeeded. Full `crystal spec`: 84 examples,
  0 failures, 0 errors, plus the C smoke under gcc.

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
| spec (CI) | latest | 4.0.0 | Windows (MSYS2 UCRT64 gcc) | Configured |
| examples | latest | 4.0.0 | Ubuntu/macOS/Windows | Configured |
| C smoke | — | 4.0.0 | Ubuntu/macOS/Windows (gcc) | Configured |
| C smoke (MSVC) | — | 4.0.0 | Windows (cl.exe) | Configured |
| ASAN | 1.21.1 | 4.0.0 | macOS arm64 | Passing |

The suite covers parser and runtime errors, malformed source and bytecode,
arena/ref lifetimes, host callbacks, file loading, and conversion limits.
