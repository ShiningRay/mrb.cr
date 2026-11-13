@[Link(ldflags: "#{__DIR__}/../../lib/libmruby.a")]
lib LibMRuby
  fun mrb_open : Void*
  fun mrb_close(mrb : Void*) : Void
end
