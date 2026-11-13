require "../src/mrb"

MRuby::State.open do |mrb|
  value = mrb.eval("{ 'name' => 'mrb.cr', 'tags' => ['crystal', 'mruby'], 'version' => 0.1 }")
  puts value.to_crystal.inspect
end
