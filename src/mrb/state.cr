module MRuby
  # Owns one mruby interpreter state.
  #
  # A state is not thread-safe. Create one state per process or isolated
  # worker and do not call it from multiple threads or concurrent fibers.
  class State
    # Raw pointer to the underlying `mrb_state`. Internal.
    getter raw : Void*

    @closed = false

    # Opens a state, yields it, and closes it even when the block raises.
    def self.open(&)
      state = new
      begin
        yield state
      ensure
        state.close
      end
    end

    def initialize
      @raw = LibMRuby.mrb_open
      raise Error.new("failed to open mruby state") if @raw.null?
    end

    def closed? : Bool
      @closed
    end

    def close
      return if @closed
      LibMRuby.mrb_close(@raw)
      @closed = true
    end

    # Evaluates Ruby source and returns the last expression value.
    #
    # Raises `MRuby::Error` for parser errors and script exceptions.
    def eval(code : String) : Value
      ensure_open!
      error = false
      raw = LibMRuby.mrb_cr_eval(@raw, code.to_unsafe, code.bytesize.to_u64, "(eval)", pointerof(error))
      raise_last_error if error
      Value.new(self, raw)
    end

    # Evaluates Ruby source. Alias for `#eval`.
    def load_string(code : String) : Value
      eval(code)
    end

    # Runs the block inside a GC arena and restores the arena on exit.
    #
    # Values created inside the block are protected only until it returns.
    # Use `#ref` for values that must outlive the arena.
    def arena(&)
      ensure_open!
      index = LibMRuby.mrb_cr_arena_save(@raw)
      begin
        yield
      ensure
        LibMRuby.mrb_cr_arena_restore(@raw, index)
      end
    end

    # Registers a value with mruby's GC. See `Ref`.
    def ref(value : Value) : Ref
      value.ref
    end

    # Forces a full mruby GC. Diagnostic and test helper.
    def gc_full : Nil
      ensure_open!
      LibMRuby.mrb_cr_gc_full(@raw)
    end

    # Number of live mruby objects. Diagnostic and test helper.
    def live_object_count : Int64
      ensure_open!
      LibMRuby.mrb_cr_live_objects(@raw)
    end

    def ensure_open! : Nil
      raise StateClosedError.new if @closed
    end

    # Copies mruby string bytes into a Crystal string. Internal.
    def copy_string(value : LibMRuby::MrbValue) : String
      len = 0_i64
      pointer = LibMRuby.mrb_cr_string_ptr(@raw, value, pointerof(len))
      return "" if pointer.null?
      String.new(pointer, len.to_i32)
    end

    private def raise_last_error : NoReturn
      exception = LibMRuby.mrb_cr_exception(@raw)
      class_pointer = LibMRuby.mrb_cr_class_name(@raw, exception)
      class_name = class_pointer.null? ? nil : String.new(class_pointer)
      message_value = LibMRuby.mrb_cr_exception_message(@raw, exception)

      message = if LibMRuby.mrb_cr_nil_p(message_value)
                  "mruby error#{class_name ? " (#{class_name})" : ""}"
                elsif LibMRuby.mrb_cr_string_p(message_value)
                  copy_string(message_value)
                else
                  "mruby error#{class_name ? " (#{class_name})" : ""}"
                end

      LibMRuby.mrb_cr_clear_exception(@raw)
      file, line = parse_location(message)
      raise Error.new(message, script_class: class_name, script_file: file, script_line: line)
    end

    # mruby prefixes parser errors with "<file>:<line>:<column>: ".
    private def parse_location(message : String) : {String?, Int32?}
      if match = message.match(/\A(.*):(\d+):(\d+): /)
        {match[1], match[2].to_i32}
      else
        {nil, nil}
      end
    end
  end
end
