require "./spec_helper"

describe MRuby::State do
  it "opens and closes a state" do
    state = MRuby::State.new
    state.closed?.should be_false
    state.close
    state.closed?.should be_true
  end

  it "closes the state when the block exits" do
    state = nil

    MRuby::State.open do |mrb|
      state = mrb
    end

    state.not_nil!.closed?.should be_true
  end

  it "closes the state when the block raises" do
    state = nil

    expect_raises(Exception, "boom") do
      MRuby::State.open do |mrb|
        state = mrb
        raise "boom"
      end
    end

    state.not_nil!.closed?.should be_true
  end

  it "makes close idempotent" do
    state = MRuby::State.new
    state.close
    state.close
    state.closed?.should be_true
  end
end

describe MRuby do
  it "has a version" do
    MRuby::VERSION.should eq("0.1.0")
  end
end
