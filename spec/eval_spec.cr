require "./spec_helper"

describe MRuby::State do
  it "evaluates integers" do
    MRuby::State.open do |mrb|
      mrb.eval("1 + 2").as_i64.should eq(3)
    end
  end

  it "evaluates negative and large integers" do
    MRuby::State.open do |mrb|
      mrb.eval("-42").as_i64.should eq(-42_i64)
      mrb.eval("2 ** 62").as_i64.should eq(4_611_686_018_427_387_904_i64)
    end
  end

  it "evaluates floats" do
    MRuby::State.open do |mrb|
      mrb.eval("3.5").as_f64.should eq(3.5)
    end
  end

  it "evaluates strings" do
    MRuby::State.open do |mrb|
      mrb.eval("'hello'").as_s.should eq("hello")
      mrb.eval("\"hello\\nworld\"").as_s.should eq("hello\nworld")
      mrb.eval(%q{"a\0b"}).as_s.should eq("a\0b")
      mrb.eval(%q{"你好"}).as_s.should eq("你好")
    end
  end

  it "evaluates nil and booleans" do
    MRuby::State.open do |mrb|
      value = mrb.eval("nil")
      value.is_nil?.should be_true
      value.as_bool.should be_false

      mrb.eval("true").as_bool.should be_true
      mrb.eval("false").as_bool.should be_false
    end
  end

  it "evaluates arrays" do
    MRuby::State.open do |mrb|
      array = mrb.eval("[1, 'two', true, nil]").as_array
      array.size.should eq(4)
      array[0].as_i64.should eq(1)
      array[1].as_s.should eq("two")
      array[2].as_bool.should be_true
      array[3].is_nil?.should be_true
    end
  end

  it "evaluates hashes" do
    MRuby::State.open do |mrb|
      hash = mrb.eval("{ 'a' => 1, 'b' => 2 }").as_hash
      hash.size.should eq(2)
      values = hash.values.map(&.as_i64).sort
      values.should eq([1_i64, 2_i64])
    end
  end

  it "loads a string through load_string" do
    MRuby::State.open do |mrb|
      mrb.load_string("6 * 7").as_i64.should eq(42)
    end
  end

  it "raises MRuby::Error for syntax errors" do
    MRuby::State.open do |mrb|
      error = expect_raises(MRuby::Error) do
        mrb.eval("1 +")
      end
      error.script_class.should eq("SyntaxError")
      error.message.not_nil!.should contain("syntax error")
    end
  end

  it "raises MRuby::Error for runtime errors" do
    MRuby::State.open do |mrb|
      error = expect_raises(MRuby::Error) do
        mrb.eval("raise 'boom'")
      end
      error.script_class.should eq("RuntimeError")
      error.message.should eq("boom")
    end
  end

  it "keeps working after a script error" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error) { mrb.eval("raise 'boom'") }
      mrb.eval("1 + 1").as_i64.should eq(2)
    end
  end

  it "raises a deterministic error when used after close" do
    state = MRuby::State.new
    state.close
    expect_raises(MRuby::StateClosedError) do
      state.eval("1")
    end
  end

  it "keeps values attached to their state" do
    state = MRuby::State.new
    value = state.eval("'still here'")
    state.close
    expect_raises(MRuby::StateClosedError) do
      value.as_s
    end
  end
end
