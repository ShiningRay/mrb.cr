require "benchmark"
require "../src/mrb"

# Run with `make bench` after building the shard.
Benchmark.ips do |x|
  x.report("state open/close") do
    MRuby::State.open { }
  end
end

MRuby::State.open do |mrb|
  mrb.define_method("add", 2) { |args| args[0].as_i64 + args[1].as_i64 }

  100.times { mrb.eval("1 + 2") }

  Benchmark.ips do |x|
    x.report("eval integer expression") do
      mrb.eval("1 + 2")
    end

    x.report("eval host callback") do
      mrb.eval("add(2, 3)")
    end

    x.report("eval JSON-like array") do
      mrb.eval("[1, 2.5, 'x', true, nil]").to_crystal
    end
  end
end
