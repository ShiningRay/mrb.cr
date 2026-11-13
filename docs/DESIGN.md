# Design

> Status: M1 and M2 implemented (state, values, errors, arena, refs). Other
> sections describe the target contract; check the plan for milestone status.

## Problem

Crystal has no mature, narrow binding to mruby 4.x. Existing options are either
broad bridges with significant macro machinery, incomplete generated bindings,
or tied to older mruby versions.

`mrb.cr` is a from-scratch binding for applications that need:

- mruby as an embedded script runtime;
- explicit control over interpreter lifetime;
- predictable error propagation;
- documented GC and value-ownership rules;
- a small API surface that can be audited.

The binding is not a plugin framework. The host application decides how scripts
are loaded, what capabilities are exposed, and how processes are isolated.

## Goals

1. Bind the mruby 4.0.x C API from Crystal with minimal hidden behavior.
2. Support one interpreter `State` per host or isolated worker; do not share a
   `State` across threads or concurrent fibers.
3. Provide explicit conversion for nil, booleans, integers, floats, strings,
   arrays, and hashes.
4. Surface mruby script errors as Crystal exceptions with script location and
   message.
5. Provide safe GC-arena and reference helpers.
6. Support class, module, method, and constant registration with typed
   callbacks.
7. Build a static mruby library from a pinned source version on Linux, macOS,
   and Windows.
8. Keep the public API small enough to document and test thoroughly.

## Non-goals

- MRI/CRuby support.
- Full Ruby standard library, gems, or Bundler compatibility.
- Automatic wrapping of arbitrary Crystal classes in v1.
- Multiple interpreters in one process.
- Thread-safe shared `State` usage.
- A security sandbox. mruby's security model leaves sandboxing and resource
  limits to the host.
- A plugin protocol or a plugin marketplace.
- Replacing mruby itself.

## Design principles

### Explicit over implicit

The binding should not guess what a Crystal object means in mruby. v1 supports
JSON-like values and explicit callback registration. Arbitrary object wrapping
can be added later behind a separate, opt-in API.

### One state, one owner

`MRuby::State` owns one `mrb_state*`. It is not safe to share a `State` across
threads or concurrent fibers. The host should create one state per process or
per isolated worker. The API should make this ownership visible.

### Errors are values until they are not

Every mruby call that can raise must go through a `mrb_protect`-style boundary.
A script exception becomes `MRuby::Error`. The binding must never print an error
to stdout and then return a fake value.

### Memory lifetimes are documented

mruby values are managed by mruby's GC. Raw `mrb_value` values must not outlive
the state or an arena scope without a registered reference. `Value` and `Ref`
should encode these rules.

### Thin C layer, no hidden macro magic

v1 uses straightforward `lib` declarations and explicit wrapper methods. Macros
can be added later if they preserve readability, but they are not the foundation.

## Architecture

```text
+-----------------------------+
| Host application            |
| (Autobot host, CLI, tests)  |
+--------------+--------------+
               |
               v
+-----------------------------+
| MRuby::State                |
| - mrb_state*                |
| - open/close                |
| - eval/load_file            |
| - define_class/method/const |
+--------------+--------------+
               |
               v
+-----------------------------+
| MRuby::Value / MRuby::Ref   |
| - typed conversion          |
| - GC registration           |
+--------------+--------------+
               |
               v
+-----------------------------+
| lib LibMRuby (C API)        |
| - mruby.h                   |
| - mruby/compile.h           |
| - mruby/error.h             |
+-----------------------------+
```

### `MRuby::State`

Responsibilities:

- Open and close the mruby state.
- Own the GC arena stack.
- Wrap `mrb_load_string`, `mrb_load_file`, and protected calls.
- Register classes, modules, methods, and constants.
- Convert results to `Value`.

Proposed API:

```crystal
MRuby::State.open do |mrb|
  value = mrb.eval("1 + 2")
  value.as_i64
end
```

`State#eval` is the convenience entry point; `State#load_string` is an alias.

`State.open` closes the state even when the block raises. `State#close` is
idempotent.

### `MRuby::Value`

`Value` wraps a single `mrb_value` and a reference to its `State`.

Capabilities:

- `is_nil?` (Crystal reserves `nil?`), `true?`, `false?`, `bool?`
- `as_i64`, `as_f64`, `as_s`, `as_bool`
- `as_array`, `as_hash`
- `type_name`
- `inspect`
- `to_crystal` for supported JSON-like types

Rules:

- Do not expose raw `mrb_value` publicly.
- Numeric conversions check ranges and raise `MRuby::Error` on overflow.
- Strings are copied into Crystal `String` values.
- Arrays and hashes are converted recursively with a depth and size limit.
- Unsupported object types raise `MRuby::Error` rather than returning a pointer.

### `MRuby::Ref`

`Ref` is an explicitly registered long-lived reference.

- Created with `State#ref(value)`.
- Registered with `mrb_gc_register`.
- Released with `Ref#close` or a block form.
- Invalid after the state closes.

Refs are for host-owned callbacks and long-lived plugin state, not for every
temporary value.

### `MRuby::Arena`

`Arena` wraps `mrb_gc_arena_save`/`mrb_gc_arena_restore`.

```crystal
mrb.arena do
  value = mrb.eval("[1, 2, 3]")
  value.as_array
end
```

The arena is restored when the block exits, including on exceptions. Values
that must survive the block need a `Ref`.

### `MRuby::Error`

All script and C-boundary failures become `MRuby::Error`:

- message
- script file and line when available
- mruby exception class name when available
- optional cause

`mrb_print_error` is debug-only. It must not be the primary error path.

### Method registration

Proposed shape:

```crystal
mrb.define_method("add", 2) do |args|
  args[0].as_i64 + args[1].as_i64
end
```

Rules:

- Arity is explicit.
- Arguments arrive as `MRuby::Args` of `Value`.
- Return values are converted explicitly.
- A Crystal exception is translated into a mruby runtime error with a stable
  prefix.
- The binding does not automatically wrap arbitrary Crystal objects.

Class and module registration:

```crystal
mrb.define_class("Calculator")
mrb.define_method("Calculator", "add", 2) do |args|
  args[0].as_i64 + args[1].as_i64
end
```

The exact naming and scoping API is subject to M3.

## C API strategy

Use hand-written `lib LibMRuby` declarations for the subset needed by the
binding. Start with:

- state: `mrb_open`, `mrb_close`
- loading: `mrb_load_string`, `mrb_load_file`
- errors: `mrb_protect`, `mrb->exc`, exception inspection
- values: nil, bool, fixnum, float, string, array, hash
- GC: arena save/restore, `mrb_gc_register`, `mrb_gc_unregister`
- classes/modules: `mrb_define_class`, `mrb_define_module`,
  `mrb_define_method`, `mrb_define_const`
- symbols: `mrb_intern_cstr`, `mrb_sym_name`

Do not bind the entire mruby API in v1. Add functions only with tests and a
documented ownership rule.

## Build strategy

- Pin mruby to a specific 4.0.x tag.
- Build a static `libmruby.a` with a controlled gembox.
- Link it from Crystal with `@[Link]`.
- Provide a `Makefile` or build script that fetches and builds mruby.
- Keep the mruby source out of the repository; pin the tag and checksum.
- CI builds on Linux, macOS, and Windows.
- The binding does not require a Ruby runtime at application runtime; Ruby and
  Rake are build-time dependencies only.

The initial gembox should include only what the binding tests need. The host
application can use a more restricted or extended gembox.

## Threading and concurrency

- `State` is not thread-safe.
- Do not call a `State` from multiple fibers concurrently.
- One `State` per host process or isolated worker.
- A future optional API may add a mutex, but the core binding should not hide
  serialization.
- Document the owner thread/fiber in the README and tests.

## Security

The binding must not imply that mruby is a sandbox. The host is responsible for:

- process or container isolation;
- CPU, memory, output, and wall-clock limits;
- restricting the mruby gembox;
- disabling program execution;
- validating all host callbacks.

The binding should make these boundaries visible, not hide them behind a
"safe eval" API.

## Compatibility

- mruby: 4.0.x first; evaluate 4.1 after 4.0 support is stable.
- Crystal: >= 1.10.
- Platforms: Linux x86_64/arm64, macOS arm64/x86_64, Windows x86_64.
- No MRI/CRuby target.
- Semantic versioning for the Crystal API.
- mruby version updates are minor releases only after the compatibility suite
  passes.

## Alternatives considered

### Anyolite

Anyolite is the most complete existing option. It is broader than this project:
it supports mruby and MRI, macro-based wrapping, and an extensive bridge. It is
also tied to mruby 3.3.0, has a singleton interpreter, and its error path is not
transparent enough for a host runtime.

`mrb.cr` does less, but with explicit ownership, mruby 4.x, and a small audit
surface.

### mruby.cr

`mruby.cr` is an incomplete set of generated unsafe bindings. It does not solve
value conversion, GC ownership, or errors.

### Direct C bindings only

Using raw C bindings in every host would duplicate the same conversion and
lifetime rules. A small shared binding is worth the abstraction.

### Process-isolated mruby only

A process boundary is still required for untrusted scripts. `mrb.cr` is the
in-host binding used inside that process, not a replacement for process
isolation.

## Open questions

1. Should v1 expose a macro-based class wrapper at all, or stay fully explicit?
2. Should `Value` support arbitrary mruby object types, or only JSON-like values?
3. Should `State` support a mutex-backed serialized mode?
4. What is the minimum mruby gembox for the test suite?
5. How should Crystal exceptions map to mruby exception classes?
6. Do we need `mrb_load_irep` in v1, or only source loading?
7. Which Windows toolchain is the primary target: MSVC or clang-cl?
8. Should the binding expose a `State#eval` convenience method, or only
   `load_string`?
