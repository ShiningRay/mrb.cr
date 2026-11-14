# mrb.cr 0.2.1

0.2.1 is a patch release addressing the follow-ups reported in issue #1.

## Fix

- `MRuby::VERSION` in the 0.2.0 release remained `"0.1.0"` even though `shard.yml` and release metadata were versioned 0.2.0. This release corrects `MRuby::VERSION` to `"0.2.1"` (and the corresponding spec). Users who installed 0.2.0 should upgrade to 0.2.1 so the runtime constant reports the correct release.

No API changes.

## Tested scope

- Windows x86_64 MinGW (MSYS2 UCRT64), Crystal 1.22.1, gcc 16.2.0, mruby 4.0.0: local full `crystal spec` — 84 examples, 0 failures, 0 errors, 0 pending.
- MSVC is unverified.
- No Windows CI runner executed locally; GitHub Actions Windows status is unverified in this session.

## Compatibility

- mruby 4.0.0 only.
- Crystal >= 1.10.
- Ruby >= 3.0 and Rake at build time only.
- A C toolchain (clang or gcc).
- `bison` and `gperf` only when regenerating the parser from a grammar change; release tags ship a pregenerated parser.

## Upgrade notes

- Only the `MRuby::VERSION` constant value changes. No API changes.

## Versioning

`mrb.cr` uses 0.x versioning. `0.2.1` is a patch release fixing the reported `MRuby::VERSION` value.
