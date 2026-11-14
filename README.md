# mrb.cr

> Thin, explicit Crystal bindings for [mruby](https://mruby.org/).

Repository name: `mrb.cr`. Shard name: `mrb`. Crystal module: `MRuby`.

**Status: 0.2.1.** The binding links mruby 4.0.0, evaluates source and files,
converts JSON-like values, raises structured errors, supports GC arenas and
long-lived references, registers host classes, modules, methods, and constants,
and loads RITE bytecode. Tested on macOS arm64 and in Linux CI. Windows x86_64
MinGW (MSYS2 UCRT64, Crystal mingw32 target) runs the full spec suite, examples,
and a C smoke test in CI; MSVC is verified at the C layer (mruby build, shim
compile, smoke run) only, since no Crystal MSVC target is distributed upstream.
This is a 0.x release and not production-hardened. `mrb.cr` is not a sandbox.

`mrb.cr` is a from-scratch binding intended to be smaller and more predictable
than a general-purpose Ruby bridge:

- mruby 4.x only, no MRI/CRuby support.
- One explicit interpreter state per host or isolated worker; no shared state.
- Explicit value conversion instead of implicit class wrapping.
- Structured errors instead of printed-only script errors.
- GC-arena and reference rules that are documented and tested.
- A narrow API that is suitable for embedding in a host process.

## Why another binding?

Anyolite is a capable and useful project, but it is optimized for a broad
Crystal-to-Ruby bridge. This project targets a different point:

- mruby 4.x as the baseline.
- A small, auditable C API surface.
- No macro-driven wrapping of arbitrary Crystal classes in v1.
- No hidden global interpreter state.
- Clear ownership and thread-affinity rules.
- A host-oriented API for sandboxed script execution.

The goal is not to replace mruby, and not to build a full Ruby implementation.
The goal is to make mruby predictable to embed from Crystal.

## API

```crystal
require "mrb"

MRuby::State.open do |mrb|
  result = mrb.eval("1 + 2")
  puts result.as_i64 # => 3
end
```

Error handling is explicit:

```crystal
MRuby::State.open do |mrb|
  begin
    mrb.eval("raise 'boom'")
  rescue ex : MRuby::Error
    puts ex.message
  end
end
```

Method registration is explicit and typed at the boundary:

```crystal
MRuby::State.open do |mrb|
  mrb.define_method("add", 2) do |args|
    args[0].as_i64 + args[1].as_i64
  end

  mrb.eval("add(2, 3)").as_i64 # => 5
end
```

The evaluation, value conversion, arena/ref, host method registration,
block/Proc handling, and `State#yield`/`State#funcall` APIs are implemented.
See the design and plan for the exact contract.

Block and call helpers:

```crystal
MRuby::State.open do |mrb|
  mrb.define_method("twice", 0) do |args|
    blk = args.block # Value? (valid during callback)
    blk ? mrb.yield(blk.not_nil!) : nil
  end

  mrb.eval("twice { 21 }").as_i64 # => 21

  target = mrb.eval("'hi'")
  mrb.funcall(target, "upcase").as_s # => "HI"
end
```

- `Args#block_given? : Bool` / `Args#block : Value?` —block access during a
  host callback.
- `State#yield(block : Value)` / `yield(block, args : Array)` /
  `yield(block, arg : CallbackValue, *rest : CallbackValue) : Value` —invoke a
  Proc; raises `MRuby::Error` on script exceptions.
- `State#funcall(receiver : Value, name : String, args : Array(CallbackValue) = [] of CallbackValue, block : Value? = nil) : Value` —
  call a Ruby method; raises `MRuby::Error` on script exceptions.
- `Value#proc? : Bool` and `Ref.proc(state : State, value : Value) : Ref` /
  `Ref.open_proc(state : State, value : Value, &)` —GC-register Proc values
  for delayed/yield use (`Ref.proc` requires explicit `#release`).

## Goals

- Embed mruby 4.x in Crystal applications.
- Provide safe, explicit conversion for JSON-like values.
- Make mruby errors observable as Crystal exceptions.
- Support class, module, method, and constant registration without a large
  macro framework.
- Build on Linux, macOS, and Windows with a pinned mruby version.
- Keep the binding small enough to audit and maintain.

## Non-goals

- MRI/CRuby support.
- Full Ruby standard library or gem compatibility.
- Automatic wrapping of arbitrary Crystal classes in v1.
- A plugin marketplace or a plugin protocol.
- A security sandbox. The host application remains responsible for isolation
  and resource limits.

## Documentation

- [Design](docs/DESIGN.md)
- [Implementation plan](docs/PLAN.md)
- [Compatibility notes](docs/COMPATIBILITY.md)
- [Embedding guide](docs/EMBEDDING.md)
- [Benchmarks](docs/BENCHMARKS.md)

## Development

### Prerequisites

- Crystal >= 1.10
- Ruby >= 3.0 with Rake (build time only)
- a C toolchain (clang or gcc)
- `bison` and `gperf` only when regenerating the parser from a grammar
  change; release tags ship a pregenerated parser
- `git`

### Build

```bash
make
```

The Makefile clones mruby **4.0.0** into `vendor/mruby`, builds it with
[`build_config/mrb_cr.rb`](build_config/mrb_cr.rb) (core, compiler, and error
gems only), and copies `libmruby.a` to `lib/`. The gembox intentionally excludes
IO, sockets, and the standard library extensions; hosts that need more should
build their own gembox.

`mrb.cr` links the static library. Ruby and Rake are not required at runtime.

Set `RUBY` if the default `ruby` on `PATH` is older than 3.0:

```bash
make RUBY=/path/to/ruby
```

### Verify

```bash
make check        # format check and specs
make examples     # run the example programs
make bench        # release-mode benchmarks
make asan         # rebuild with AddressSanitizer and run specs
```

`make asan` replaces the normal build. Run `make clean && make` afterwards.

## License

MIT. See [LICENSE](LICENSE).
