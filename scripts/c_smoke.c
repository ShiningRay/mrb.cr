/*
 * C-level smoke test for libmruby + mrb_shim, independent of Crystal.
 * Verifies that the C toolchain (MSVC or gcc) can compile, link, and run the
 * mruby core plus the shim, and that eval, error propagation, and message
 * extraction work through the shim surface.
 *
 * Build (gcc, MinGW/Unix):
 *   mkdir -p build && gcc -I vendor/mruby/include -I vendor/mruby/build/host/include \
 *     -o build/smoke scripts/c_smoke.c lib/mrb_shim.o lib/libmruby.a
 * Build (MSVC, from a Developer Command Prompt, flags mirroring the
 * visualcpp toolchain used for libmruby):
 *   cl /nologo /MD /D_CRT_SECURE_NO_WARNINGS /I vendor/mruby/include \
 *     /I vendor/mruby/build/host/include /Fe:build\smoke.exe \
 *     scripts/c_smoke.c lib/mrb_shim.obj lib/libmruby.lib
 *
 * Exit code 0 plus "smoke: ok" means the C layer is functional.
 */
#include <mruby.h>
#include <stdio.h>
#include <string.h>

/* Shim surface, normally declared on the Crystal side in src/mrb/lib_mruby.cr. */
mrb_value mrb_cr_eval(mrb_state *mrb, const char *code, size_t len,
                      const char *filename, mrb_bool *error);
mrb_bool mrb_cr_has_exception(mrb_state *mrb);
void mrb_cr_clear_exception(mrb_state *mrb);
mrb_value mrb_cr_exception(mrb_state *mrb);
mrb_value mrb_cr_exception_message(mrb_state *mrb, mrb_value exc);
long long mrb_cr_integer_as_i64(mrb_value v);
const char *mrb_cr_string_ptr(mrb_state *mrb, mrb_value v, long long *len);

static int failures = 0;

static void
expect(int cond, const char *what)
{
  if (cond) {
    printf("smoke: %s ok\n", what);
  }
  else {
    fprintf(stderr, "smoke: FAIL %s\n", what);
    failures++;
  }
}

int
main(void)
{
  mrb_state *mrb = mrb_open();
  expect(mrb != NULL, "mrb_open");
  if (mrb == NULL) {
    return 1;
  }

  /* 1. eval produces an integer */
  mrb_bool err = FALSE;
  mrb_value v = mrb_cr_eval(mrb, "1 + 2", strlen("1 + 2"), "(smoke)", &err);
  expect(!err && !mrb_cr_has_exception(mrb), "eval without error");
  expect(mrb_cr_integer_as_i64(v) == 3, "eval 1 + 2 == 3");

  /* 2. script exceptions surface through the shim error flag */
  mrb_cr_clear_exception(mrb);
  err = FALSE;
  v = mrb_cr_eval(mrb, "raise \"boom\"", strlen("raise \"boom\""), "(smoke)", &err);
  expect(err || mrb_cr_has_exception(mrb), "raise sets the error flag");

  mrb_value msg = mrb_cr_exception_message(mrb, mrb_cr_exception(mrb));
  long long len = 0;
  const char *msgp = mrb_cr_string_ptr(mrb, msg, &len);
  expect(msgp != NULL && strstr(msgp, "boom") != NULL, "exception message contains boom");

  mrb_close(mrb);

  if (failures > 0) {
    return 1;
  }
  printf("smoke: ok\n");
  return 0;
}
