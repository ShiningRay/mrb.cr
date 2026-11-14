# mrb.cr 0.2.0

Release 0.2.0 adds Windows MinGW build support and a public block/Proc API, closing
the issues reported in issue #1.

## Included

- `lib_mruby.cr` Windows branch now links the canonical `lib/libmruby.a` and
  `lib/mrb_shim.o` instead of MSVC-only artifact names; `.lib`/`.obj` aliases
  are produced for compatibility.
- `Makefile` and `scripts/build_windows.ps1` copy the mruby build config to a
  writable path (`vendor/mruby/build/mrb_cr.rb`) before running Rake, avoiding
  `.lock` writes into read-only directories.
- Build scripts support both MSVC (`cl.exe`) and MinGW gcc toolchains.
- bison and gperf are no longer listed as required tools; release tags ship a
  pregenerated parser.
- Block/Proc API: `Args#block_given?`, `Args#block`, `State#yield` overloads,
  `State#funcall`, `Value#proc?`, `Ref.proc`, and `Ref.open_proc`.
- `State#funcall` and `State#yield` use `mrb_protect` and preserve exception
  details from Ruby blocks.
- Documentation updates for Windows status, block/Proc usage, and API signatures.

## Tested scope

- Windows x86_64 MinGW (MSYS2 UCRT64), Crystal 1.22.1, gcc 16.2.0,
  mruby 4.0.0: local smoke build plus full `crystal spec` with
  84 examples, 0 failures, 0 errors, 0 pending.
- MSVC is unverified.
- No Windows CI runner executed locally; GitHub Actions Windows status is
  unverified in this session.

## Compatibility

- mruby 4.0.0 only.
- Crystal >= 1.10.
- Ruby >= 3.0 and Rake at build time only.
- A C toolchain (clang or gcc).
- `bison` and `gperf` only when regenerating the parser from a grammar change;
  release tags ship a pregenerated parser.

## Upgrade notes

- Consumers must rebuild the native library after upgrading.
- On Windows the shard links `lib/libmruby.a` and `lib/mrb_shim.o`
  (with `.lib`/`.obj` aliases).
- The new block/Proc APIs are additive; existing evaluation/value/method APIs
  remain unchanged.

## Not supported

- MRI/CRuby, full Ruby standard library, gems, or Bundler.
- A security sandbox.

## Versioning

`mrb.cr` uses 0.x versioning. `0.2.0` adds public API and Windows MinGW build
support without removing existing APIs.