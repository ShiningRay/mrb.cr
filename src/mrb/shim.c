/*
 * Narrow C shim for mruby macros and inline functions that Crystal cannot
 * call directly. Everything here is a small, auditable wrapper; no policy
 * lives in C.
 */
#include <mruby.h>
#include <mruby/array.h>
#include <mruby/compile.h>
#include <mruby/error.h>
#include <mruby/hash.h>
#include <mruby/object.h>
#include <mruby/string.h>
#include <stdint.h>
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
