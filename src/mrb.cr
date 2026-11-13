require "./mrb/version"
require "./mrb/lib_mruby"
require "./mrb/error"
require "./mrb/state"

# Crystal bindings for the mruby C API.
#
# The binding is intentionally narrow:
# - one `MRuby::State` per interpreter;
# - explicit value conversion;
# - explicit error handling;
# - no implicit Crystal object wrapping.
module MRuby
end
