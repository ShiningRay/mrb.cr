require "./spec_helper"

private def with_script(source : String, &block : String ->)
  File.tempfile("mrb-spec", ".rb") do |file|
    file.print(source)
    file.flush
    yield file.path
  end
end

describe "file loading" do
  it "loads a Ruby file and returns its value" do
    MRuby::State.open do |mrb|
      with_script("x = 20\nx + 22\n") do |path|
        mrb.load_file(path).as_i64.should eq(42)
      end
    end
  end

  it "reports the file and line for syntax errors" do
    MRuby::State.open do |mrb|
      with_script("x = 1\n1 + * 2\n") do |path|
        error = expect_raises(MRuby::Error) do
          mrb.load_file(path)
        end
        error.script_class.should eq("SyntaxError")
        error.script_file.should eq(path)
        error.script_line.should eq(2)
      end
    end
  end

  it "reports runtime errors from files" do
    MRuby::State.open do |mrb|
      with_script("raise 'from file'\n") do |path|
        error = expect_raises(MRuby::Error) do
          mrb.load_file(path)
        end
        error.script_class.should eq("RuntimeError")
        error.message.should eq("from file")
        error.script_file.should eq(path)
      end
    end
  end

  it "raises a clear error for a missing file" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error, /failed to read script/) do
        mrb.load_file("/nonexistent/mrb-spec-script.rb")
      end
    end
  end
end

describe "bytecode" do
  it "compiles and loads bytecode" do
    MRuby::State.open do |mrb|
      irep = mrb.compile("40 + 2")
      irep.empty?.should be_false
      mrb.load_irep(irep).as_i64.should eq(42)
    end
  end

  it "compiles and loads bytecode with host callbacks" do
    MRuby::State.open do |mrb|
      mrb.define_method("triple", 1) { |args| args[0].as_i64 * 3 }
      irep = mrb.compile("triple(14)")
      mrb.load_irep(irep).as_i64.should eq(42)
    end
  end

  it "reports syntax errors while compiling" do
    MRuby::State.open do |mrb|
      error = expect_raises(MRuby::Error) do
        mrb.compile("1 +\n", "broken.rb")
      end
      error.script_class.should eq("SyntaxError")
      error.script_file.should eq("broken.rb")
    end
  end

  it "reports runtime errors from bytecode" do
    MRuby::State.open do |mrb|
      irep = mrb.compile("raise 'from irep'")
      error = expect_raises(MRuby::Error, "from irep") do
        mrb.load_irep(irep)
      end
      error.script_class.should eq("RuntimeError")
    end
  end

  it "rejects malformed bytecode without crashing" do
    MRuby::State.open do |mrb|
      expect_raises(MRuby::Error) do
        mrb.load_irep(Bytes[1, 2, 3, 4])
      end
    end
  end
end
