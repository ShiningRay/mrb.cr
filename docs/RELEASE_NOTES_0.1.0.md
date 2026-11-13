# mrb.cr 0.1.0

First release of a thin, explicit Crystal binding for mruby 4.0.0.

## Included

- Pinned mruby 4.0.0 static build (core, `mruby-compiler`, `mruby-error`).
- `MRuby::State` with block-scoped open/close and deterministic state-closed
  errors.
- `State#eval`, `State#load_string`, and `State#load_file`.
- JSON-like values: nil, boolean, integer, float, string, array, and hash.
- Recursive `Value#to_crystal` with depth and node limits.
- `MRuby::Arena`, `MRuby::Ref`, and `MRuby::Args`.
- Host classes, modules, instance methods, class methods, module functions,
  and constants.
- Crystal exception and arity translation into mruby `RuntimeError` and
  `ArgumentError`.
- RITE bytecode via `State#compile` and `State#load_irep`.
- Examples, embedding guide, benchmarks, fuzz coverage, and an ASAN build
  target.

## Tested scope

- macOS arm64 with Crystal 1.21.1 and mruby 4.0.0: `make check`, examples, and
  ASAN specs.
- Linux x86_64 and macOS CI jobs build mruby and run the suite and examples.
- Windows has a build script and platform-specific link names, but no verified
  run. Treat Windows as unsupported.

## Not supported

- MRI/CRuby, full Ruby standard library, gems, or Bundler.
- Multiple interpreters sharing one `State`.
- Thread-safe or fiber-safe shared `State`.
- Automatic wrapping of arbitrary Crystal classes.
- bigint values in the default gembox.
- A security sandbox, resource limits, or process isolation.
- Bytecode compatibility across mruby versions.

## Compatibility

- mruby 4.0.0 (pinned; upgrade only after the compatibility suite passes).
- Crystal >= 1.10.
- Ruby >= 3.0 with Rake, bison, and gperf at build time only.
- The compiled binary does not require Ruby at runtime.

## Build note

Consumers must build the native library once inside the shard checkout:

```bash
make RUBY=/path/to/ruby
```

The `lib/` directory is build output and is not committed. See
[EMBEDDING.md](EMBEDDING.md).

## Versioning

0.x releases may change the Crystal API. Breaking changes are called out in
the changelog; compatibility with mruby upgrades is tested before each release.
