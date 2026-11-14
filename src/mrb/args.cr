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

    # Number of arguments.
    def size : Int32
      @values.size
    end

    # Returns the argument at `index`.
    def [](index : Int32) : Value
      Value.new(@state, @values[index])
    end

    # Yields each argument as a `Value`.
    def each(& : Value ->) : Nil
      @values.each_index do |index|
        yield self[index]
      end
    end

    # Copies the arguments into an array of `Value`.
    def to_a : Array(Value)
      Array(Value).new(size) { |index| self[index] }
    end

    # Returns `true` if a block was passed to this call.
    def block_given? : Bool
      @state.ensure_open!
      LibMRuby.mrb_cr_block_given(@state.raw)
    end

    # Returns the block passed to this call as a `Value` (Proc), or `nil` when
    # no block was given. The returned value is only valid while the state is
    # open and reachable; use `Value#ref` to keep it for later calls.
    def block : Value?
      @state.ensure_open!
      return nil unless block_given?
      Value.new(@state, LibMRuby.mrb_cr_get_block(@state.raw))
    end
  end
end
