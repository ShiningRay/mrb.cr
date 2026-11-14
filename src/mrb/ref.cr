module MRuby
  # A GC-rooted reference to an mruby value.
  #
  # Create a ref for values that must outlive the current GC arena, for
  # example host callback state or values cached between evaluations.
  # Release it with `#release`, or use `Ref.open` for block cleanup.
  class Ref
    getter state : State

    @raw : LibMRuby::MrbValue
    @released = false

    # Internal constructor. Use `Value#ref` or `State#ref` instead.
    def initialize(@state : State, @raw : LibMRuby::MrbValue)
      @state.ensure_open!
      LibMRuby.mrb_cr_gc_register(@state.raw, @raw)
    end

    # Registers a Proc value, yields the ref, and releases it on exit.
    def self.open_proc(state : State, value : Value, &)
      ref = value.ref
      begin
        yield ref
      ensure
        ref.release
      end
    end

    # Registers a Proc value and returns a ref for delayed calls.
    def self.proc(state : State, value : Value) : Ref
      value.ref
    end

    # Registers a value, yields the ref, and releases it on exit.
    def self.open(value : Value, &)
      ref = value.ref
      begin
        yield ref
      ensure
        ref.release
      end
    end

    # Returns `true` after `#release` has run.
    def released? : Bool
      @released
    end

    # Returns a fresh value handle for the registered object.
    def value : Value
      raise StateClosedError.new if @state.closed?
      raise Error.new("reference has been released") if @released
      Value.new(@state, @raw)
    end

    # Unregisters the value. Safe to call more than once.
    #
    # Releasing after the state has closed is a no-op; mruby already freed
    # every object at that point.
    def release
      return if @released
      unless @state.closed?
        LibMRuby.mrb_cr_gc_unregister(@state.raw, @raw)
      end
      @released = true
    end
  end
end
