require "./mrb/version"
require "./mrb/lib_mruby"
require "./mrb/error"
require "./mrb/value"
require "./mrb/args"
require "./mrb/state"
require "./mrb/ref"
require "./mrb/arena"

# Crystal bindings for the mruby C API.
#
# The binding is intentionally narrow:
# - one `MRuby::State` per interpreter;
# - explicit value conversion;
# - explicit error handling;
# - no implicit Crystal object wrapping.
module MRuby
end
