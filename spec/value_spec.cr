require "./spec_helper"

describe MRuby::Value do
  it "reports type names" do
    MRuby::State.open do |mrb|
      mrb.eval("1").type_name.should eq("Integer")
      mrb.eval("1.5").type_name.should eq("Float")
      mrb.eval("'x'").type_name.should eq("String")
      mrb.eval("[]").type_name.should eq("Array")
      mrb.eval("{}").type_name.should eq("Hash")
      mrb.eval("nil").type_name.should eq("NilClass")
    end
  end

  it "raises on mismatched conversions" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error, /expected Integer, got String/) do
        mrb.eval("'x'").as_i64
      end

      expect_raises(MRuby::Error, /expected Float, got Integer/) do
        mrb.eval("1").as_f64
      end

      expect_raises(MRuby::Error, /expected String, got Integer/) do
        mrb.eval("1").as_s
      end

      expect_raises(MRuby::Error, /expected Bool, got Integer/) do
        mrb.eval("1").as_bool
      end
    end
  end

  it "converts JSON-like values to Crystal" do
    MRuby::State.open do |mrb|
      converted = mrb.eval("{ 'name' => 'mrb', 'tags' => [1, 2.5, nil, true] }").to_crystal
      hash = converted.as_hash?.not_nil!

      hash[MRuby::CrystalValue.new("name")].as_s?.should eq("mrb")
      tags = hash[MRuby::CrystalValue.new("tags")].as_array?.not_nil!
      tags.map(&.raw).should eq([1_i64, 2.5, nil, true] of MRuby::CrystalValue::Raw)
    end
  end

  it "refuses unsupported object types" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error, /cannot convert Object/) do
        mrb.eval("Object.new").to_crystal
      end
    end
  end

  it "enforces the depth limit" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error, /depth limit/) do
        mrb.eval("[[[[[1]]]]]").to_crystal(max_depth: 2)
      end
    end
  end

  it "enforces the node limit" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error, /node limit/) do
        mrb.eval("[1, 2, 3, 4, 5]").to_crystal(max_nodes: 3)
      end
    end
  end

  it "compares values by identity" do
    MRuby::State.open do |mrb|
      mrb.eval("1").should eq(mrb.eval("1"))
      mrb.eval("'a'").should_not eq(mrb.eval("'a'"))
    end
  end

  it "inspects through the converted value" do
    MRuby::State.open do |mrb|
      mrb.eval("[1, 'a']").inspect.should eq(%([1, "a"]))
    end
  end
end
