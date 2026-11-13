require "../src/mrb"

expression = ARGV.join(" ")
expression = "1 + 2 * 3" if expression.empty?

MRuby::State.open do |mrb|
  puts mrb.eval(expression).to_crystal.raw
end
