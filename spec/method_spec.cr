require "./spec_helper"

describe "host methods" do
  it "defines a top-level method and converts its return value" do
    MRuby::State.open do |mrb|
      mrb.define_method("add", 2) do |args|
        args[0].as_i64 + args[1].as_i64
      end

      mrb.eval("add(2, 3)").as_i64.should eq(5)
    end
  end

  it "returns strings, floats, booleans, nil, and values" do
    MRuby::State.open do |mrb|
      mrb.define_method("greet", 1) { |args| "hello #{args[0].as_s}" }
      mrb.define_method("half", 1) { |args| args[0].as_f64 / 2.0 }
      mrb.define_method("yes?", 0) { true }
      mrb.define_method("nothing", 0) { nil }
      mrb.define_method("identity", 1) { |args| args[0] }

      mrb.eval("greet('world')").as_s.should eq("hello world")
      mrb.eval("half(5.0)").as_f64.should eq(2.5)
      mrb.eval("yes?").as_bool.should be_true
      mrb.eval("nothing").is_nil?.should be_true
      mrb.eval("identity(42)").as_i64.should eq(42)
    end
  end

  it "reports wrong arity as an ArgumentError" do
    MRuby::State.open do |mrb|
      mrb.define_method("add", 2) { |args| args[0].as_i64 + args[1].as_i64 }

      error = expect_raises(MRuby::Error, /wrong number of arguments/) do
        mrb.eval("add(1)")
      end
      error.script_class.should eq("ArgumentError")
    end
  end

  it "translates Crystal exceptions into mruby runtime errors" do
    MRuby::State.open do |mrb|
      mrb.define_method("explode", 0) { raise "boom" }

      error = expect_raises(MRuby::Error, "boom") do
        mrb.eval("explode")
      end
      error.script_class.should eq("RuntimeError")
    end
  end

  it "exposes arguments through Args" do
    MRuby::State.open do |mrb|
      mrb.define_method("describe", 3) do |args|
        "#{args.size}:#{args.to_a.map(&.as_i64).join(',')}"
      end

      mrb.eval("describe(1, 2, 3)").as_s.should eq("3:1,2,3")
    end
  end

  it "defines instance methods on a class" do
    MRuby::State.open do |mrb|
      mrb.define_class("Calculator")
      mrb.define_method("Calculator", "add", 2) do |args|
        args[0].as_i64 + args[1].as_i64
      end

      mrb.eval("Calculator.new.add(20, 22)").as_i64.should eq(42)
    end
  end

  it "defines class methods" do
    MRuby::State.open do |mrb|
      mrb.define_class("Calculator")
      mrb.define_class_method("Calculator", "twice", 1) do |args|
        args[0].as_i64 * 2
      end

      mrb.eval("Calculator.twice(21)").as_i64.should eq(42)
    end
  end

  it "defines module functions" do
    MRuby::State.open do |mrb|
      mrb.define_module("MathX")
      mrb.define_module_function("MathX", "double", 1) do |args|
        args[0].as_i64 * 2
      end

      mrb.eval("MathX.double(21)").as_i64.should eq(42)
    end
  end

  it "supports class inheritance" do
    MRuby::State.open do |mrb|
      mrb.define_class("Base")
      mrb.define_class("Child", "Base")

      mrb.eval("Child.new.is_a?(Base)").as_bool.should be_true
      mrb.eval("Child.superclass == Base").as_bool.should be_true
    end
  end

  it "makes class and module definition idempotent" do
    MRuby::State.open do |mrb|
      mrb.define_class("Thing")
      mrb.define_class("Thing")
      mrb.define_module("Helpers")
      mrb.define_module("Helpers")

      mrb.eval("Thing.new.class == Thing").as_bool.should be_true
      mrb.eval("Helpers.is_a?(Module)").as_bool.should be_true
    end
  end

  it "rejects modules as superclasses" do
    MRuby::State.open do |mrb|
      mrb.define_module("Helpers")

      expect_raises(MRuby::Error, /not a class/) do
        mrb.define_class("Broken", "Helpers")
      end
    end
  end

  it "defines constants on Object and on classes" do
    MRuby::State.open do |mrb|
      mrb.define_const("ANSWER", 42)
      mrb.define_class("Config")
      mrb.define_const("Config", "NAME", "mrb")
      mrb.define_const("Config", "ENABLED", true)

      mrb.eval("ANSWER").as_i64.should eq(42)
      mrb.eval("Config::NAME").as_s.should eq("mrb")
      mrb.eval("Config::ENABLED").as_bool.should be_true
    end
  end

  it "rejects duplicate host method names" do
    MRuby::State.open do |mrb|
      mrb.define_method("dup", 0) { 1 }
      expect_raises(MRuby::Error, /already defined/) do
        mrb.define_method("dup", 0) { 2 }
      end
    end
  end

  it "rejects undefined owners" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error, /not defined/) do
        mrb.define_method("Missing", "run", 0) { nil }
      end
    end
  end

  it "rejects values from another state" do
    MRuby::State.open do |mrb|
      other = MRuby::State.new
      foreign = other.eval("'foreign'")
      mrb.define_method("foreign_value", 0) { foreign }

      expect_raises(MRuby::Error, /different mruby state/) do
        mrb.eval("foreign_value")
      end

      other.close
    end
  end

  it "rejects registration after close" do
    state = MRuby::State.new
    state.close
    expect_raises(MRuby::StateClosedError) do
      state.define_method("late", 0) { nil }
    end
  end

  it "keeps the state usable after a callback error" do
    MRuby::State.open do |mrb|
      mrb.define_method("explode", 0) { raise "boom" }
      mrb.define_method("ok", 0) { 7 }

      expect_raises(MRuby::Error) { mrb.eval("explode") }
      mrb.eval("ok").as_i64.should eq(7)
    end
  end
end
