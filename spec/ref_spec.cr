require "./spec_helper"

describe MRuby::Arena do
  it "restores the arena after the block" do
    MRuby::State.open do |mrb|
      before = mrb.live_object_count

      mrb.arena do
        200.times { mrb.eval("[1, 2, 3]") }
      end

      mrb.gc_full
      after = mrb.live_object_count
      (after - before).should be < 400
    end
  end

  it "offers a module-level block helper" do
    MRuby::State.open do |mrb|
      value = MRuby::Arena.open(mrb) do
        mrb.eval("40 + 2")
      end
      value.as_i64.should eq(42)
    end
  end

  it "does not grow memory without bound across many arena scopes" do
    MRuby::State.open do |mrb|
      before = mrb.live_object_count

      # Allocate roughly 100k strings across 100 arena scopes.
      100.times do
        mrb.arena do
          mrb.eval("Array.new(1_000) { |i| i.to_s }")
        end
      end

      mrb.gc_full
      after = mrb.live_object_count
      (after - before).should be < 5_000
    end
  end
end

describe MRuby::Ref do
  it "keeps a value alive after its arena is restored" do
    MRuby::State.open do |mrb|
      ref = nil

      mrb.arena do
        ref = mrb.eval("'kept'").ref
      end

      ref = ref.not_nil!
      10.times { mrb.gc_full }
      ref.value.as_s.should eq("kept")
      ref.release
    end
  end

  it "releases through the block form" do
    MRuby::State.open do |mrb|
      saved_ref = nil

      MRuby::Ref.open(mrb.eval("[1, 2]")) do |ref|
        saved_ref = ref
        ref.value.as_array.size.should eq(2)
      end

      saved_ref.not_nil!.released?.should be_true
    end
  end

  it "makes release idempotent" do
    MRuby::State.open do |mrb|
      ref = mrb.eval("'x'").ref
      ref.release
      ref.release
      ref.released?.should be_true
    end
  end

  it "raises when reading a released ref" do
    MRuby::State.open do |mrb|
      ref = mrb.eval("'x'").ref
      ref.release
      expect_raises(MRuby::Error, /released/) do
        ref.value
      end
    end
  end

  it "does not crash when released after the state closes" do
    state = MRuby::State.new
    ref = state.eval("'x'").ref
    state.close
    ref.release
    ref.released?.should be_true
    expect_raises(MRuby::StateClosedError) do
      ref.value
    end
  end

  it "raises for diagnostic helpers after close" do
    state = MRuby::State.new
    state.close
    expect_raises(MRuby::StateClosedError) { state.gc_full }
    expect_raises(MRuby::StateClosedError) { state.live_object_count }
  end
end
