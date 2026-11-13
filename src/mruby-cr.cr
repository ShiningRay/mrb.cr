require "./mruby_cr/version"

# Crystal bindings for the mruby C API.
#
# The binding is intentionally narrow:
# - one `MRuby::State` per interpreter;
# - explicit value conversion;
# - explicit error handling;
# - no implicit Crystal object wrapping.
module MRuby
end
