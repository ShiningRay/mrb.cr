module MRuby
  # Arguments passed to a host-defined mruby method.
  #
  # An `Args` instance is only valid for the duration of the callback. Do not
  # store it or hand it to another fiber.
  class Args
    include Enumerable(Value)

    getter state : State

    def initialize(@state : State, @values : Slice(LibMRuby::MrbValue))
    end

    def size : Int32
      @values.size
    end

    def [](index : Int32) : Value
      Value.new(@state, @values[index])
    end

    def each(& : Value ->) : Nil
      @values.each_index do |index|
        yield self[index]
      end
    end

    def to_a : Array(Value)
      Array(Value).new(size) { |index| self[index] }
    end
  end
end
