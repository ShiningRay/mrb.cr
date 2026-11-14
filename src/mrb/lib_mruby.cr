# Link the local build produced by `make`.
#
# The C shim wraps mruby macros and inline functions that Crystal cannot call
# directly. Canonical artifact names are libmruby.a and mrb_shim.o (Makefile
# may create .lib/.obj aliases on Windows for toolchain compatibility).
{% if flag?(:windows) %}
  @[Link(ldflags: "#{__DIR__}/../../lib/mrb_shim.o #{__DIR__}/../../lib/libmruby.a")]
{% else %}
  @[Link(ldflags: "#{__DIR__}/../../lib/mrb_shim.o #{__DIR__}/../../lib/libmruby.a -lm")]
{% end %}
lib LibMRuby
  # Layout-compatible with mruby's `mrb_value` (MRB_WORD_BOXING, 64-bit).
  struct MrbValue
    w : UInt64
  end

  # Mirrors mrb_cr_callback_result in src/mrb/shim.c. Field names are local
  # to Crystal; the C layout is value, message, error_kind.
  struct CallbackResult
    data : MrbValue
    message : UInt8*
    error_kind : Int32
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

  fun mrb_cr_arena_save(mrb : Void*) : Int32
  fun mrb_cr_arena_restore(mrb : Void*, index : Int32) : Void
  fun mrb_cr_gc_register(mrb : Void*, value : MrbValue) : Void
  fun mrb_cr_gc_unregister(mrb : Void*, value : MrbValue) : Void
  fun mrb_cr_gc_full(mrb : Void*) : Void
  fun mrb_cr_live_objects(mrb : Void*) : Int64

  fun mrb_cr_set_dispatch(fn : Void*) : Void
  fun mrb_cr_callback_result_set(result : CallbackResult*, value : MrbValue, message : UInt8*, error_kind : Int32) : Void
  fun mrb_cr_args_req(count : Int32) : UInt32
  fun mrb_cr_define_method(mrb : Void*, cla : Void*, name : UInt8*, aspec : UInt32) : Void
  fun mrb_cr_define_class_method(mrb : Void*, cla : Void*, name : UInt8*, aspec : UInt32) : Void
  fun mrb_cr_define_module_function(mrb : Void*, cla : Void*, name : UInt8*, aspec : UInt32) : Void
  fun mrb_cr_define_class(mrb : Void*, name : UInt8*, super : Void*) : Void*
  fun mrb_cr_define_module(mrb : Void*, name : UInt8*) : Void*
  fun mrb_cr_class_get(mrb : Void*, name : UInt8*) : Void*
  fun mrb_cr_object_class(mrb : Void*) : Void*
  fun mrb_cr_module_pointer_p(ptr : Void*) : Bool
  fun mrb_cr_define_const(mrb : Void*, cla : Void*, name : UInt8*, value : MrbValue) : Void

  fun mrb_cr_current_method_name(mrb : Void*) : UInt8*
  fun mrb_cr_current_argc(mrb : Void*) : Int64
  fun mrb_cr_current_argv(mrb : Void*) : MrbValue*

  fun mrb_cr_nil_value : MrbValue
  fun mrb_cr_true_value : MrbValue
  fun mrb_cr_false_value : MrbValue
  fun mrb_cr_integer_value(mrb : Void*, value : Int64) : MrbValue
  fun mrb_cr_float_value(mrb : Void*, value : Float64) : MrbValue
  fun mrb_cr_string_value(mrb : Void*, ptr : UInt8*, len : LibC::SizeT) : MrbValue

  fun mrb_cr_proc_p(mrb : Void*, v : MrbValue) : Bool
  fun mrb_cr_block_given(mrb : Void*) : Bool
  fun mrb_cr_get_block(mrb : Void*) : MrbValue
  fun mrb_cr_yield(mrb : Void*, blk : MrbValue, argc : Int64, argv : MrbValue*, error : Bool*) : MrbValue
  fun mrb_cr_funcall(mrb : Void*, receiver : MrbValue, name : UInt8*, argc : Int64, argv : MrbValue*, blk : MrbValue, error : Bool*) : MrbValue

  fun mrb_cr_compile_irep(mrb : Void*, code : UInt8*, len : LibC::SizeT, filename : UInt8*, bin : UInt8**, bin_len : LibC::SizeT*) : Bool
  fun mrb_cr_free_bin(mrb : Void*, bin : Void*) : Void
  fun mrb_cr_load_irep(mrb : Void*, data : UInt8*, len : LibC::SizeT, filename : UInt8*, error : Bool*) : MrbValue
end
