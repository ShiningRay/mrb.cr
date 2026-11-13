# Compatibility

> Status: design phase. This matrix describes intent, not tested support.

## Runtime versions

| Component | Target |
|---|---|
| mruby | 4.0.x first; 4.1 after a compatibility pass |
| Crystal | >= 1.10 |
| Ruby (build only) | Version required by the pinned mruby build; not a runtime dependency |
| Rake (build only) | Required to build mruby |
| C compiler | GCC, Clang, or MSVC depending on platform |

## Platforms

| Platform | Planned status |
|---|---|
| Linux x86_64 | Primary |
| Linux arm64 | Primary |
| macOS arm64 | Primary |
| macOS x86_64 | Secondary |
| Windows x86_64 | Planned; toolchain decision is open |

## Supported values

The v1 boundary supports JSON-like values:

- `nil`
- `true` / `false`
- Integer (range checked)
- Float
- String (UTF-8)
- Array
- Hash

Arbitrary mruby object types are not automatically converted. They require an
explicit future API.

## Not supported

- MRI/CRuby.
- Full Ruby standard library or gems.
- Bundler.
- Multiple interpreters in one process.
- Thread-safe shared `State`.
- Automatic Crystal object wrapping.
- A security sandbox.

## Versioning

- The Crystal API follows semantic versioning.
- mruby upgrades are minor releases only after the compatibility suite passes.
- Removing a public API requires a major version.
- Adding a new supported value type is a minor feature.
- The mruby version is pinned per release and documented in the release notes.

## Security boundary

`mrb.cr` is a language binding. It does not isolate scripts, enforce CPU or
memory limits, or restrict the mruby API surface by itself. Hosts must provide:

- process or container isolation;
- resource limits;
- a restricted gembox;
- explicit host capabilities;
- input validation.

## Test matrix

Planned:

| Job | Crystal | mruby | Platform |
|---|---|---|---|
| linux-x86_64 | stable | pinned 4.0.x | Ubuntu |
| linux-arm64 | stable | pinned 4.0.x | Linux arm64 runner/container |
| macos-arm64 | stable | pinned 4.0.x | macOS |
| windows-x86_64 | stable | pinned 4.0.x | Windows, when viable |
| crystal-next | nightly | pinned 4.0.x | Linux, non-blocking |

The matrix is not implemented in the design-phase skeleton.
