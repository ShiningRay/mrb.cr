# Embedding mrb.cr

This guide covers embedding mruby through `mrb.cr` in a Crystal host process.
The binding is a language bridge, not a sandbox.

## Build the native library

The shard links a pinned mruby 4.0.0 static library:

```bash
make RUBY=/path/to/ruby
```

`make` clones mruby into `vendor/mruby`, builds it with
[`build_config/mrb_cr.rb`](../build_config/mrb_cr.rb), and copies
`libmruby.a` plus the C shim object into `lib/`.

Requirements:

- Crystal >= 1.10
- Ruby >= 3.0 with Rake (build time only)
- clang or gcc
- bison and gperf only when regenerating the parser from a grammar change;
  release tags ship a pregenerated parser
- git

The resulting binary does not require Ruby at runtime.

## Add the dependency

```yaml
dependencies:
  mrb:
    github: ShiningRay/mrb.cr
```

Consumers must run `make` inside the shard directory once (or add
`scripts.postinstall` in their own automation) so that `lib/libmruby.a` and
`lib/mrb_shim.o` exist before Crystal links the program. The `lib/` directory
is build output and is not committed.

## Open one state per host

```crystal
require "mrb"

MRuby::State.open do |mrb|
  value = mrb.eval("1 + 2")
  puts value.as_i64 # => 3
end
```

Rules:

- `State` owns one `mrb_state*` and is not thread-safe.
- Do not share a state across threads or concurrent fibers.
- Create one state per process or isolated worker.
- `State.open` closes the state even when the block raises.
- Values and refs are invalid after the state closes.

## Load scripts

```crystal
mrb.load_file("scripts/worker.rb")
```

Errors carry the file and line when mruby reports them:

```crystal
begin
  mrb.load_file("scripts/broken.rb")
rescue ex : MRuby::Error
  puts ex.script_file
  puts ex.script_line
  puts ex.message
end
```

## Expose host capabilities

```crystal
mrb.define_class("Config")
mrb.define_method("Config", "get", 1) do |args|
  key = args[0].as_s
  settings.fetch(key)
end
```

- Host method names must be unique per state.
- Arguments arrive as `MRuby::Args`; arity is checked before the callback.
- Callbacks may return `MRuby::Value`, `nil`, `Bool`, `Int32`, `Int64`,
  `Float64`, or `String`.
- A Crystal exception becomes an mruby `RuntimeError`; an arity mismatch
  becomes an mruby `ArgumentError`.

Prefer narrow, validated capabilities. Do not expose raw file, process, or
network access unless the script is trusted.

## Manage lifetimes

```crystal
mrb.arena do
  doc = mrb.eval("build_document()")
  # Temporary values are protected until the block exits.
end

ref = mrb.ref(mrb.eval("cache"))
mrb.gc_full
puts ref.value.inspect
ref.release
```

- Values are shallow handles protected by the GC arena.
- Use `Ref` for host-owned values that must survive arena restoration.
- Release refs explicitly; release is idempotent.
- `to_crystal` copies JSON-like values with depth and node limits.

## Isolation

mruby does not enforce CPU, memory, or wall-clock limits. Hosts must add:

- process or container isolation;
- resource limits;
- a restricted gembox (the default shard build enables only core,
  `mruby-compiler`, and `mruby-error`);
- validated host callbacks;
- input limits for scripts and values.

## Blocks and Proc calls

Host callbacks can inspect and invoke Ruby blocks (signatures per
`src/mrb/args.cr`, `src/mrb/state.cr`, `src/mrb/value.cr`, `src/mrb/ref.cr`):

```crystal
MRuby::State.open do |mrb|
  mrb.define_method("call_with", 1) do |args|
    if args.block_given?
      blk = args.block.not_nil! # Value? valid during this callback
      mrb.yield(blk, [args[0]] of MRuby::CallbackValue)
    else
      nil
    end
  end

  mrb.eval("call_with(21) { |x| x * 2 }").as_i64 # => 42
end
```

- `Args#block_given? : Bool` — `true` when a Proc block was passed to the host
  method (`src/mrb/args.cr:37-40`).
- `Args#block : Value?` — returns the block Proc or `nil`. The value is only
  valid while the host callback/state context is valid; to keep it for later
  calls, register it (e.g. `Value#ref`) and protect its lifetime
  (`src/mrb/args.cr:45-49`).
- `State#yield(block : Value) : Value`, `yield(block : Value, args : Array) : Value`,
  and `yield(block : Value, arg : CallbackValue, *rest : CallbackValue) : Value`
  invoke a Proc and raise `MRuby::Error` if the block raises
  (`src/mrb/state.cr:176-195`, `197-210`).
- `State#funcall(receiver : Value, name : String, args : Array(CallbackValue) = [] of CallbackValue, block : Value? = nil) : Value`
  calls a Ruby method and raises `MRuby::Error` on script exceptions. The
  optional `block` parameter accepts a Proc `Value` (or `nil`)
  (`src/mrb/state.cr:214-235`).

Proc lifetime helpers:

```crystal
proc_val = mrb.eval("Proc.new { |x| x + 1 }")
ref = MRuby::Ref.proc(mrb, proc_val) # GC-registered
mrb.yield(ref.value, [1_i64] of MRuby::CallbackValue).as_i64 # => 2
ref.release

MRuby::Ref.open_proc(mrb, mrb.eval("Proc.new { 5 }")) do |r|
  mrb.yield(r.value).as_i64 # released on block exit
end
```

- `Value#proc? : Bool` reports whether a value is a Proc (`src/mrb/value.cr:123-126`).
- `Ref.proc(state : State, value : Value) : Ref` registers the value with mruby's
  GC and returns a ref; caller is responsible for `#release`
  (`src/mrb/ref.cr:30-32`).
- `Ref.open_proc(state : State, value : Value, &)` registers, yields the ref, and
  releases it on exit (`src/mrb/ref.cr:20-27`). Registered refs keep Procs alive
  across full GC cycles while held.

## Bytecode

`State#compile` produces RITE bytecode and `State#load_irep` executes it:

```crystal
irep = mrb.compile(File.read("scripts/worker.rb"), "worker.rb")
File.write("worker.mrb", irep)
# ...
mrb.load_irep(File.read("worker.mrb").to_slice, "worker.rb")
```

Bytecode is tied to the mruby version used to produce it. Do not load
bytecode produced by a different mruby release.

## Examples

- [`examples/calculator.cr`](../examples/calculator.cr)
- [`examples/host_callback.cr`](../examples/host_callback.cr)
- [`examples/json_values.cr`](../examples/json_values.cr)

Run them with `make examples`.
