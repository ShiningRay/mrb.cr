/*
 * Narrow C shim for mruby macros and inline functions that Crystal cannot
 * call directly. Everything here is a small, auditable wrapper; no policy
 * lives in C.
 */
#include <mruby.h>
#include <mruby/array.h>
#include <mruby/class.h>
#include <mruby/compile.h>
#include <mruby/error.h>
#include <mruby/hash.h>
#include <mruby/object.h>
#include <mruby/string.h>
#include <mruby/variable.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

mrb_bool
mrb_cr_nil_p(mrb_value v)
{
  return mrb_nil_p(v);
}

mrb_bool
mrb_cr_true_p(mrb_value v)
{
  return mrb_true_p(v);
}

mrb_bool
mrb_cr_false_p(mrb_value v)
{
  return mrb_false_p(v);
}

mrb_bool
mrb_cr_integer_p(mrb_value v)
{
  return mrb_integer_p(v);
}

mrb_bool
mrb_cr_float_p(mrb_value v)
{
  return mrb_float_p(v);
}

mrb_bool
mrb_cr_string_p(mrb_value v)
{
  return mrb_string_p(v);
}

mrb_bool
mrb_cr_array_p(mrb_value v)
{
  return mrb_array_p(v);
}

mrb_bool
mrb_cr_hash_p(mrb_value v)
{
  return mrb_hash_p(v);
}

mrb_bool
mrb_cr_symbol_p(mrb_value v)
{
  return mrb_symbol_p(v);
}

const char *
mrb_cr_class_name(mrb_state *mrb, mrb_value v)
{
  return mrb_obj_classname(mrb, v);
}

int64_t
mrb_cr_integer_as_i64(mrb_value v)
{
  return (int64_t)mrb_integer(v);
}

double
mrb_cr_float_as_f64(mrb_value v)
{
  return (double)mrb_float(v);
}

const char *
mrb_cr_string_ptr(mrb_state *mrb, mrb_value v, int64_t *len)
{
  (void)mrb;
  *len = (int64_t)RSTRING_LEN(v);
  return RSTRING_PTR(v);
}

int64_t
mrb_cr_array_len(mrb_value v)
{
  return (int64_t)RARRAY_LEN(v);
}

mrb_value
mrb_cr_array_entry(mrb_value v, int64_t index)
{
  return mrb_ary_entry(v, (mrb_int)index);
}

int64_t
mrb_cr_hash_size(mrb_state *mrb, mrb_value v)
{
  return (int64_t)mrb_hash_size(mrb, v);
}

mrb_value
mrb_cr_hash_keys(mrb_state *mrb, mrb_value v)
{
  return mrb_hash_keys(mrb, v);
}

mrb_value
mrb_cr_hash_get(mrb_state *mrb, mrb_value v, mrb_value key)
{
  return mrb_hash_get(mrb, v, key);
}

struct mrb_cr_eval_args {
  const char *code;
  size_t len;
  mrb_ccontext *cxt;
};

static mrb_value
mrb_cr_eval_body(mrb_state *mrb, mrb_value data)
{
  struct mrb_cr_eval_args *args = (struct mrb_cr_eval_args *)mrb_cptr(data);
  return mrb_load_nstring_cxt(mrb, args->code, args->len, args->cxt);
}

mrb_value
mrb_cr_eval(mrb_state *mrb, const char *code, size_t len, const char *filename,
            mrb_bool *error)
{
  struct mrb_cr_eval_args args;
  mrb_value result;
  mrb_ccontext *cxt = mrb_ccontext_new(mrb);

  cxt->capture_errors = TRUE;
  mrb_ccontext_filename(mrb, cxt, filename);

  args.code = code;
  args.len = len;
  args.cxt = cxt;
  result = mrb_protect(mrb, mrb_cr_eval_body, mrb_cptr_value(mrb, &args), error);
  mrb_ccontext_free(mrb, cxt);

  /* mrb_load_nstring reports parser errors through mrb->exc without raising. */
  if (!*error && mrb->exc != NULL) {
    *error = TRUE;
  }
  return result;
}

mrb_bool
mrb_cr_has_exception(mrb_state *mrb)
{
  return mrb->exc != NULL;
}

mrb_value
mrb_cr_exception(mrb_state *mrb)
{
  return mrb_obj_value(mrb->exc);
}

void
mrb_cr_clear_exception(mrb_state *mrb)
{
  mrb->exc = NULL;
}

static mrb_value
mrb_cr_message_body(mrb_state *mrb, mrb_value exc)
{
  return mrb_funcall(mrb, exc, "message", 0);
}

mrb_value
mrb_cr_exception_message(mrb_state *mrb, mrb_value exc)
{
  struct RObject *saved = mrb->exc;
  mrb_bool error = FALSE;
  mrb_value message = mrb_protect(mrb, mrb_cr_message_body, exc, &error);

  if (error) {
    mrb->exc = saved;
    return mrb_nil_value();
  }
  return message;
}

int
mrb_cr_arena_save(mrb_state *mrb)
{
  return mrb_gc_arena_save(mrb);
}

void
mrb_cr_arena_restore(mrb_state *mrb, int index)
{
  mrb_gc_arena_restore(mrb, index);
}

void
mrb_cr_gc_register(mrb_state *mrb, mrb_value value)
{
  mrb_gc_register(mrb, value);
}

void
mrb_cr_gc_unregister(mrb_state *mrb, mrb_value value)
{
  mrb_gc_unregister(mrb, value);
}

void
mrb_cr_gc_full(mrb_state *mrb)
{
  mrb_full_gc(mrb);
}

int64_t
mrb_cr_live_objects(mrb_state *mrb)
{
  return (int64_t)mrb->gc.live;
}

/* Host callbacks ---------------------------------------------------------- */

typedef struct mrb_cr_callback_result {
  mrb_value value;
  const char *message;
  int error_kind; /* 0 = ok, 1 = runtime error, 2 = argument error */
} mrb_cr_callback_result;

typedef void (*mrb_cr_dispatch_fn)(mrb_state *, mrb_value, mrb_cr_callback_result *);

static mrb_cr_dispatch_fn mrb_cr_dispatch_callback = NULL;

void
mrb_cr_set_dispatch(void *fn)
{
  mrb_cr_dispatch_callback = (mrb_cr_dispatch_fn)fn;
}

void
mrb_cr_callback_result_set(mrb_cr_callback_result *result, mrb_value value,
                           const char *message, int error_kind)
{
  result->value = value;
  result->message = message;
  result->error_kind = error_kind;
}

static mrb_value
mrb_cr_method_entry(mrb_state *mrb, mrb_value self)
{
  mrb_cr_callback_result result;

  result.value = mrb_nil_value();
  result.message = NULL;
  result.error_kind = 0;

  if (mrb_cr_dispatch_callback != NULL) {
    mrb_cr_dispatch_callback(mrb, self, &result);
  }
  else {
    result.message = "no host dispatcher registered";
    result.error_kind = 1;
  }

  if (result.error_kind != 0) {
    char buf[512];
    snprintf(buf, sizeof(buf), "%s",
             result.message != NULL ? result.message : "host callback failed");
    if (result.error_kind == 2) {
      mrb_raise(mrb, E_ARGUMENT_ERROR, buf);
    }
    else {
      mrb_raise(mrb, E_RUNTIME_ERROR, buf);
    }
  }
  return result.value;
}

mrb_aspec
mrb_cr_args_req(int count)
{
  return MRB_ARGS_REQ(count);
}

void
mrb_cr_define_method(mrb_state *mrb, struct RClass *cla, const char *name, mrb_aspec aspec)
{
  mrb_define_method(mrb, cla, name, mrb_cr_method_entry, aspec);
}

void
mrb_cr_define_class_method(mrb_state *mrb, struct RClass *cla, const char *name, mrb_aspec aspec)
{
  mrb_define_class_method(mrb, cla, name, mrb_cr_method_entry, aspec);
}

void
mrb_cr_define_module_function(mrb_state *mrb, struct RClass *cla, const char *name, mrb_aspec aspec)
{
  mrb_define_module_function(mrb, cla, name, mrb_cr_method_entry, aspec);
}

void *
mrb_cr_define_class(mrb_state *mrb, const char *name, void *super)
{
  struct RClass *super_class = super != NULL ? (struct RClass *)super : mrb->object_class;
  return (void *)mrb_define_class(mrb, name, super_class);
}

void *
mrb_cr_define_module(mrb_state *mrb, const char *name)
{
  return (void *)mrb_define_module(mrb, name);
}

void *
mrb_cr_class_get(mrb_state *mrb, const char *name)
{
  mrb_sym sym = mrb_intern_cstr(mrb, name);
  mrb_value object = mrb_obj_value(mrb->object_class);
  mrb_value value;

  if (!mrb_const_defined(mrb, object, sym)) {
    return NULL;
  }
  value = mrb_const_get(mrb, object, sym);
  if (mrb_class_p(value) || mrb_module_p(value)) {
    return (void *)mrb_class_ptr(value);
  }
  return NULL;
}

void *
mrb_cr_object_class(mrb_state *mrb)
{
  return (void *)mrb->object_class;
}

mrb_bool
mrb_cr_module_pointer_p(void *ptr)
{
  return ((struct RBasic *)ptr)->tt == MRB_TT_MODULE;
}

void
mrb_cr_define_const(mrb_state *mrb, void *cla, const char *name, mrb_value value)
{
  struct RClass *target = cla != NULL ? (struct RClass *)cla : mrb->object_class;
  mrb_define_const(mrb, target, name, value);
}

const char *
mrb_cr_current_method_name(mrb_state *mrb)
{
  return mrb_sym_name(mrb, mrb_get_mid(mrb));
}

mrb_int
mrb_cr_current_argc(mrb_state *mrb)
{
  return mrb_get_argc(mrb);
}

const mrb_value *
mrb_cr_current_argv(mrb_state *mrb)
{
  return mrb_get_argv(mrb);
}

mrb_value
mrb_cr_nil_value(void)
{
  return mrb_nil_value();
}

mrb_value
mrb_cr_true_value(void)
{
  return mrb_true_value();
}

mrb_value
mrb_cr_false_value(void)
{
  return mrb_false_value();
}

mrb_value
mrb_cr_integer_value(mrb_state *mrb, int64_t value)
{
  return mrb_int_value(mrb, (mrb_int)value);
}

mrb_value
mrb_cr_float_value(mrb_state *mrb, double value)
{
  return mrb_float_value(mrb, (mrb_float)value);
}

mrb_value
mrb_cr_string_value(mrb_state *mrb, const char *ptr, size_t len)
{
  return mrb_str_new(mrb, ptr, len);
}
