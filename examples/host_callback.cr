require "../src/mrb"

MRuby::State.open do |mrb|
  mrb.define_class("Greeter")
  mrb.define_method("Greeter", "greet", 1) do |args|
    "hello, #{args[0].as_s}"
  end

  puts mrb.eval("Greeter.new.greet('mrb')").as_s
end
