require "./spec_helper"

describe "malformed input" do
  it "rejects random source bytes without crashing" do
    MRuby::State.open do |mrb|
      1_000.times do |seed|
        random = Random.new(seed)
        size = random.rand(0..64)
        bytes = Bytes.new(size) { random.rand(256).to_u8 }

        begin
          mrb.eval(String.new(bytes))
        rescue MRuby::Error
          # Parser or runtime errors are expected for most inputs.
        end
      end
    end
  end

  it "handles deeply nested but parseable source" do
    MRuby::State.open do |mrb|
      depth = 100
      source = "[" * depth + "1" + "]" * depth
      value = mrb.eval(source)
      value.to_crystal(max_depth: depth + 1).is_nil?.should be_false
    end
  end

  it "rejects values past the conversion limits" do
    MRuby::State.open do |mrb|
      source = "[" * 200 + "1" + "]" * 200
      expect_raises(MRuby::Error, /depth limit/) do
        mrb.eval(source).to_crystal(max_depth: 10)
      end

      expect_raises(MRuby::Error, /node limit/) do
        mrb.eval("Array.new(1_000) { |i| i }").to_crystal(max_nodes: 10)
      end
    end
  end

  it "rejects truncated and random bytecode" do
    MRuby::State.open do |mrb|
      irep = mrb.compile("1 + 2")
      expect_raises(MRuby::Error) do
        mrb.load_irep(irep[0, irep.size // 2])
      end

      100.times do |seed|
        random = Random.new(seed + 1_000)
        bytes = Bytes.new(random.rand(0..32)) { random.rand(256).to_u8 }
        begin
          mrb.load_irep(bytes)
        rescue MRuby::Error
        end
      end
    end
  end

  it "survives repeated error and recovery cycles" do
    MRuby::State.open do |mrb|
      500.times do |index|
        expect_raises(MRuby::Error) do
          mrb.eval("raise 'error #{index}'")
        end

        mrb.eval("1 + 1").as_i64.should eq(2)
      end
    end
  end

  it "keeps the state usable after malformed input" do
    MRuby::State.open do |mrb|
      begin
        mrb.eval("def broken(")
      rescue MRuby::Error
      end

      mrb.eval("'still alive'").as_s.should eq("still alive")
    end
  end
end
