require "./spec_helper"

describe "block / Proc API" do
  it "reports block_given? state at top level without raising" do
    MRuby::State.open do |mrb|
      mrb.block_given?.should be_false
      mrb.current_block.should be_nil
    end
  end

  it "detects a block passed to a host method" do
    MRuby::State.open do |mrb|
      mrb.define_method("block?", 0) { |args| args.block_given? }

      mrb.eval("block? { 1 }").as_bool.should be_true
      mrb.eval("block?").as_bool.should be_false
    end
  end

  it "captures the block passed to a host method" do
    MRuby::State.open do |mrb|
      saved = nil
      mrb.define_method("capture", 0) do |args|
        args.block_given?.should be_true
        saved = args.block
        nil
      end

      mrb.eval("capture { |x| x * 2 }")
      saved.should_not be_nil
      saved.not_nil!.proc?.should be_true

      # captured Proc stays callable through State#yield
      mrb.yield(saved.not_nil!, [21]).as_i64.should eq(42)
    end
  end

  it "returns nil block when no block was given" do
    MRuby::State.open do |mrb|
      seen = nil
      mrb.define_method("capture", 0) do |args|
        args.block_given?.should be_false
        seen = args.block
        nil
      end

      mrb.eval("capture")
      seen.should be_nil
    end
  end

  it "yields with arguments and returns the block value" do
    MRuby::State.open do |mrb|
      adder = mrb.eval("Proc.new { |a, b| a + b }")
      adder.proc?.should be_true
      mrb.yield(adder, [2, 3]).as_i64.should eq(5)

      const = mrb.eval("Proc.new { 7 }")
      mrb.yield(const).as_i64.should eq(7)
    end
  end

  it "propagates block exceptions as MRuby::Error and keeps the state usable" do
    MRuby::State.open do |mrb|
      boom = mrb.eval("Proc.new { raise 'inside block' }")

      error = expect_raises(MRuby::Error, /inside block/) do
        mrb.yield(boom)
      end
      error.script_class.should eq("RuntimeError")

      # state still usable after the propagated exception
      mrb.eval("1 + 1").as_i64.should eq(2)
    end
  end

  it "calls a method with args and block via funcall" do
    MRuby::State.open do |mrb|
      mrb.define_method("with_block", 1) do |args|
        blk = args.block
        blk.should_not be_nil
        args.state.yield(blk.not_nil!, [args[0].as_i64 * 2])
      end

      receiver = mrb.eval("Object.new")
      double = mrb.eval("Proc.new { |x| x * 10 }")
      result = mrb.funcall(receiver, "with_block", [2], double)
      result.as_i64.should eq(40)
    end
  end

  it "funcalls a method without a block" do
    MRuby::State.open do |mrb|
      mrb.define_class("Greeter")
      mrb.define_method("Greeter", "greet", 1) do |args|
        "hello #{args[0].as_s}"
      end

      greeter = mrb.eval("Greeter.new")
      mrb.funcall(greeter, "greet", ["world"]).as_s.should eq("hello world")
      mrb.funcall(greeter, "greet", ["world"], nil).as_s.should eq("hello world")
    end
  end

  it "funcall propagates exceptions as MRuby::Error" do
    MRuby::State.open do |mrb|
      mrb.define_method("boom", 0) { raise "from host" }

      expect_raises(MRuby::Error, /from host/) do
        mrb.funcall(mrb.eval("Object.new"), "boom")
      end
    end
  end

  it "funcall on a non-Proc block is rejected" do
    MRuby::State.open do |mrb|
      not_a_proc = mrb.eval("42")

      expect_raises(MRuby::Error, /expected Proc block/) do
        mrb.funcall(mrb.eval("nil"), "to_s", [] of MRuby::CallbackValue, not_a_proc)
      end
    end
  end

  it "keeps a Proc in a Ref across full GC cycles" do
    MRuby::State.open do |mrb|
      double = mrb.eval("Proc.new { |x| x * 2 }")
      ref = double.ref

      5.times { mrb.gc_full }

      blk = ref.value
      blk.proc?.should be_true
      mrb.yield(blk, [21]).as_i64.should eq(42)
      ref.release
    end
  end

  it "registers a Proc through Ref.proc and releases it" do
    MRuby::State.open do |mrb|
      proc_val = mrb.eval("Proc.new { |x| x + 1 }")
      ref = MRuby::Ref.proc(mrb, proc_val)

      ref.value.proc?.should be_true
      mrb.yield(ref.value, [1]).as_i64.should eq(2)
      ref.released?.should be_false
      ref.release
      ref.released?.should be_true
    end
  end

  it "releases a Proc ref when Ref.open_proc block exits" do
    MRuby::State.open do |mrb|
      proc_val = mrb.eval("Proc.new { 5 }")
      MRuby::Ref.open_proc(mrb, proc_val) do |ref|
        mrb.yield(ref.value).as_i64.should eq(5)
        ref.released?.should be_false
      end
    end
  end

  it "rejects blocks from another state on yield and funcall" do
    MRuby::State.open do |mrb|
      other = MRuby::State.new
      foreign = other.eval("Proc.new { 1 }")

      expect_raises(MRuby::Error, /different mruby state/) do
        mrb.yield(foreign)
      end
      expect_raises(MRuby::Error, /different mruby state/) do
        mrb.funcall(mrb.eval("nil"), "to_s", [] of MRuby::CallbackValue, foreign)
      end
      expect_raises(MRuby::Error, /different mruby state/) do
        mrb.funcall(foreign, "to_s")
      end

      other.close
    end
  end

  it "rejects non-Proc values on yield" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error, /expected Proc block/) do
        mrb.yield(mrb.eval("42"))
      end
    end
  end

  it "raises StateClosedError after close" do
    state = MRuby::State.new
    proc_val = state.eval("Proc.new { 1 }")
    state.close

    expect_raises(MRuby::StateClosedError) { state.yield(proc_val) }
    expect_raises(MRuby::StateClosedError) { state.funcall(proc_val, "call") }
    expect_raises(MRuby::StateClosedError) { state.block_given? }
  end

  it "catches a Ruby exception from funcall inside a host callback and runs ensure" do
    MRuby::State.open do |mrb|
      target = mrb.eval("o = Object.new; def o.kaboom; raise 'funcall-boom'; end; o")
      ensured = false
      caught_message = ""
      caught_class = ""

      mrb.define_method("call_boom", 0) do
        begin
          mrb.funcall(target, "kaboom")
          "no-error"
        rescue ex : MRuby::Error
          caught_message = ex.message || ""
          caught_class = ex.script_class
          "rescued"
        ensure
          ensured = true
        end
      end

      result = mrb.eval("call_boom")
      ensured.should be_true
      caught_class.should eq("RuntimeError")
      caught_message.should match(/funcall-boom/)
      result.as_s.should eq("rescued")
      mrb.eval("40 + 2").as_i64.should eq(42)
    end
  end
end
