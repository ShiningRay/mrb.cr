# Compatibility

> Status: implementation and hardening in progress. The matrix distinguishes
> tested, CI-configured, and unverified targets.

## Runtime versions

| Component | Target |
|---|---|
| mruby | 4.0.0 (pinned) |
| Crystal | >= 1.10 (developed with 1.21.1) |
| Ruby (build only) | >= 3.0 with Rake; not a runtime dependency |
| C compiler | Clang or GCC; on Windows MSVC (the official Crystal Windows distribution targets MSVC and links with cl.exe) or MSYS2 UCRT64 gcc for an MSYS2-built mingw32-target Crystal |

## Platforms

| Platform | Status |
|---|---|
| macOS arm64 | Tested locally (Crystal 1.21.1, mruby 4.0.0) |
| macOS x86_64 | Not tested |
| Linux x86_64 | CI configured (Ubuntu, Crystal latest) |
| Linux arm64 | Not tested |
| Windows x86_64 (official Crystal, MSVC target) | CI passing end to end (windows-latest: mruby `visualcpp` build, `cl.exe` shim, full `crystal spec` linked by cl.exe, examples, C smoke) — see Windows notes |
| Windows x86_64 (MSYS2 UCRT64 gcc, mingw32 target) | Makefile build + C smoke CI configured; full `crystal spec` smoke-tested locally (MSYS2-built Crystal 1.22.1, gcc 16.2.0, mruby 4.0.0, 2026-11-14) — see Windows notes |

Windows notes:

- The official Crystal Windows distribution targets **MSVC**: it drives
  `cl.exe` for linking and expects `libmruby.lib` + `lib/mrb_shim.obj`
  (verified for 1.21.1 and 1.22.x on `windows-latest`; the full spec suite
  passes this way in CI). Build the C side with
  [`scripts/build_windows.ps1`](../scripts/build_windows.ps1), which
  auto-selects mruby's `visualcpp` toolchain via `VisualStudioVersion`/
  `VSINSTALLDIR`.
- An MSYS2-built Crystal (mingw32 target, `flag?(:gnu)`) instead links
  `lib/libmruby.a` + `lib/mrb_shim.o` built by `make` with gcc. The full
  spec suite passed locally this way (84 examples, 0 failures); CI covers
  the Makefile build and C smoke because GitHub runners only ship the
  official MSVC-target Crystal.
- The shard's `@[Link]` annotation branches on `flag?(:gnu)`; the build
  scripts stage both artifact name pairs (`libmruby.a`/`mrb_shim.o` and
  `libmruby.lib`/`mrb_shim.obj`), one file of each pair being a byte copy of
  the toolchain's native output.
- MSVC specifics: mruby's `visualcpp` toolchain archives with `lib.exe` into
  `libmruby.lib` and compiles with `/MD` + `MRB_STACK_EXTEND_DOUBLING`; the
  shim is compiled with the same flags so both sides share one ABI view.
  The script pins the MSVC linker/archiver via `LD`/`AR` to space-free
  absolute paths because mruby's rake shells commands out unquoted — bare
  `link.exe` can resolve to a GNU coreutils `link` bundled with Git for
  Windows / RubyInstaller's MSYS, and spaced paths get split.
- [scripts/c_smoke.c](../scripts/c_smoke.c) is a Crystal-independent C smoke
  test (eval, exception flag, message extraction) that CI builds and runs
  under gcc and cl.exe.
- bison and gperf are not required to build a release tag; mruby ships a
  pregenerated parser. They are only needed when checking out mruby from git
  or regenerating the parser after a grammar change. The Windows CI jobs
  build without them on purpose.
- Local smoke (MSYS2 UCRT64, MSYS2-built Crystal 1.22.1): `ruby -S rake -j4`
  in `vendor/mruby` with config copied to `vendor/mruby/build/mrb_cr.rb`,
  `gcc -O2 -I... -c src/mrb/shim.c`, `crystal build src/mrb.cr` and full
  `crystal spec`: 84 examples, 0 failures, 0 errors, plus the C smoke under
  gcc.

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
| spec (CI) | latest | 4.0.0 | Windows (MSVC, official Crystal) | Passing |
| spec (local) | 1.22.1 (MSYS2-built, mingw32) | 4.0.0 | Windows (MSYS2 UCRT64 gcc) | Passing |
| examples | latest | 4.0.0 | Ubuntu/macOS/Windows (MSVC) | Configured |
| C smoke | — | 4.0.0 | Ubuntu/macOS (gcc), Windows (gcc via msys2) | Configured |
| C smoke (MSVC) | — | 4.0.0 | Windows (cl.exe) | Passing |
| ASAN | 1.21.1 | 4.0.0 | macOS arm64 | Passing |

The suite covers parser and runtime errors, malformed source and bytecode,
arena/ref lifetimes, host callbacks, file loading, and conversion limits.
