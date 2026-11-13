# Link the local build produced by `make`.
#
# The C shim wraps mruby macros and inline functions that Crystal cannot call
# directly. Both files live under lib/ and are built by the Makefile.
@[Link(ldflags: "#{__DIR__}/../../lib/mrb_shim.o #{__DIR__}/../../lib/libmruby.a -lm")]
lib LibMRuby
  # Layout-compatible with mruby's `mrb_value` (MRB_WORD_BOXING, 64-bit).
  struct MrbValue
    w : UInt64
  end

  fun mrb_open : Void*
  fun mrb_close(mrb : Void*) : Void

  fun mrb_cr_nil_p(v : MrbValue) : Bool
  fun mrb_cr_true_p(v : MrbValue) : Bool
  fun mrb_cr_false_p(v : MrbValue) : Bool
  fun mrb_cr_integer_p(v : MrbValue) : Bool
  fun mrb_cr_float_p(v : MrbValue) : Bool
  fun mrb_cr_string_p(v : MrbValue) : Bool
  fun mrb_cr_array_p(v : MrbValue) : Bool
  fun mrb_cr_hash_p(v : MrbValue) : Bool
  fun mrb_cr_symbol_p(v : MrbValue) : Bool

  fun mrb_cr_class_name(mrb : Void*, v : MrbValue) : UInt8*
  fun mrb_cr_integer_as_i64(v : MrbValue) : Int64
  fun mrb_cr_float_as_f64(v : MrbValue) : Float64
  fun mrb_cr_string_ptr(mrb : Void*, v : MrbValue, len : Int64*) : UInt8*
  fun mrb_cr_array_len(v : MrbValue) : Int64
  fun mrb_cr_array_entry(v : MrbValue, index : Int64) : MrbValue
  fun mrb_cr_hash_size(mrb : Void*, v : MrbValue) : Int64
  fun mrb_cr_hash_keys(mrb : Void*, v : MrbValue) : MrbValue
  fun mrb_cr_hash_get(mrb : Void*, v : MrbValue, key : MrbValue) : MrbValue

  fun mrb_cr_eval(mrb : Void*, code : UInt8*, len : LibC::SizeT, filename : UInt8*, error : Bool*) : MrbValue
  fun mrb_cr_has_exception(mrb : Void*) : Bool
  fun mrb_cr_exception(mrb : Void*) : MrbValue
  fun mrb_cr_clear_exception(mrb : Void*) : Void
  fun mrb_cr_exception_message(mrb : Void*, exc : MrbValue) : MrbValue
end
