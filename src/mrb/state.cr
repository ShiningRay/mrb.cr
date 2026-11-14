module MRuby
  # Values a host callback may return or pass to mruby calls. Only scalars and
  # `Value` handles (including Proc values) are converted; compound values must
  # be wrapped explicitly.
  alias CallbackValue = Value | Nil | Bool | Int32 | Int64 | Float64 | String

  # Owns one mruby interpreter state.
  #
  # A state is not thread-safe. Create one state per process or isolated
  # worker and do not call it from multiple threads or concurrent fibers.
  class State
    # Raw pointer to the underlying `mrb_state`. Internal.
    getter raw : Void*

    @@registry = {} of Void* => State

    @closed = false
    @methods = {} of String => MethodEntry

    private record MethodEntry,
      arity : Int32,
      callback : Proc(Args, CallbackValue),
      kind : Symbol,
      owner : String?

    # Looks up a live state from a raw mrb_state pointer.
    def self.from_raw(raw : Void*) : State?
      @@registry[raw]?
    end

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
      @@registry[@raw] = self
    end

    # Returns `true` after the state has been closed.
    def closed? : Bool
      @closed
    end

    # Closes the state and drops host callback registrations.
    #
    # Idempotent. Values and refs created from this state become invalid.
    def close
      return if @closed
      @methods.clear
      @@registry.delete(@raw)
      LibMRuby.mrb_close(@raw)
      @closed = true
    end

    # Evaluates Ruby source and returns the last expression value.
    #
    # Raises `MRuby::Error` for parser errors and script exceptions.
    def eval(code : String) : Value
      eval_with_filename(code, "(eval)")
    end

    # Creates a Proc value from Ruby source returning a block/lambda.
    #
    # The returned `Value` holds a Proc; use `#yield` or `#funcall` to call it.
    def create_proc(code : String, filename : String = "(proc)") : Value
      eval_with_filename(code, filename)
    end

    # Returns `true` if a Proc block is available in the current mruby context.
    #
    # Valid inside host callbacks; false at top-level scripts or when the
    # underlying call slot does not hold a Proc.
    def block_given? : Bool
      ensure_open!
      return false unless LibMRuby.mrb_cr_block_given(@raw)
      blk = LibMRuby.mrb_cr_get_block(@raw)
      LibMRuby.mrb_cr_proc_p(@raw, blk)
    end

    # Returns the current block (Proc) as a `Value`, or nil if no Proc block is
    # available in the current context.
    def current_block : Value?
      ensure_open!
      return nil unless LibMRuby.mrb_cr_block_given(@raw)
      blk = LibMRuby.mrb_cr_get_block(@raw)
      return nil unless LibMRuby.mrb_cr_proc_p(@raw, blk)
      Value.new(self, blk)
    end

    # Evaluates Ruby source. Alias for `#eval`.
    def load_string(code : String) : Value
      eval(code)
    end

    # Reads and evaluates a Ruby file. Errors report the file path and line.
    def load_file(path : String) : Value
      ensure_open!
      source = File.read(path)
      eval_with_filename(source, path)
    rescue ex : IO::Error
      raise Error.new("failed to read script '#{path}': #{ex.message}", script_file: path)
    end

    # Compiles Ruby source into mruby bytecode (RITE format).
    def compile(code : String, filename : String = "(compile)") : Bytes
      ensure_open!
      unless code.valid_encoding?
        raise Error.new("source is not valid UTF-8", script_file: filename)
      end
      bin = Pointer(UInt8).null
      bin_len = 0_u64
      ok = LibMRuby.mrb_cr_compile_irep(@raw, code.to_unsafe, code.bytesize.to_u64,
        filename.to_unsafe, pointerof(bin), pointerof(bin_len))

      unless ok
        if LibMRuby.mrb_cr_has_exception(@raw)
          raise_last_error(filename)
        else
          raise Error.new("failed to compile source", script_file: filename)
        end
      end

      begin
        Slice.new(bin, bin_len.to_i).dup
      ensure
        LibMRuby.mrb_cr_free_bin(@raw, bin)
      end
    end

    # Loads mruby bytecode produced by `#compile` or `mrbc`.
    def load_irep(data : Bytes, filename : String = "(irep)") : Value
      ensure_open!
      error = false
      raw = LibMRuby.mrb_cr_load_irep(@raw, data.to_unsafe, data.size.to_u64,
        filename.to_unsafe, pointerof(error))
      raise_last_error(filename) if error
      Value.new(self, raw)
    end

    private def eval_with_filename(code : String, filename : String) : Value
      ensure_open!
      unless code.valid_encoding?
        raise Error.new("source is not valid UTF-8", script_file: filename)
      end
      error = false
      raw = LibMRuby.mrb_cr_eval(@raw, code.to_unsafe, code.bytesize.to_u64,
        filename.to_unsafe, pointerof(error))
      raise_last_error(filename) if error
      Value.new(self, raw)
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

    # Yields to an mruby block (Proc value) with no arguments.
    # Raises `MRuby::Error` if the block raises.
    def yield(block : Value) : Value
      invoke_block(block, [] of CallbackValue)
    end

    # Yields to an mruby block with the given argument array.
    # Raises `MRuby::Error` if the block raises.
    def yield(block : Value, args : Array) : Value
      converted = Array(CallbackValue).new(args.size)
      args.each { |arg| converted << arg.as(CallbackValue) }
      invoke_block(block, converted)
    end

    # Yields to an mruby block with splat-style arguments.
    # Raises `MRuby::Error` if the block raises.
    def yield(block : Value, arg : CallbackValue, *rest : CallbackValue) : Value
      converted = Array(CallbackValue).new(rest.size + 1)
      converted << arg
      rest.each { |a| converted << a }
      invoke_block(block, converted)
    end

    private def invoke_block(block : Value, args : Array(CallbackValue)) : Value
      ensure_open!
      ensure_same_state!(block)
      raise Error.new("expected Proc block, got #{block.type_name}") unless block.proc?
      argv = to_mrb_argv(args)
      error = false
      if argv.empty?
        raw = LibMRuby.mrb_cr_yield(@raw, block.raw_value, 0_i64, Pointer(LibMRuby::MrbValue).null, pointerof(error))
      else
        raw = LibMRuby.mrb_cr_yield(@raw, block.raw_value, argv.size.to_i64, argv.to_unsafe, pointerof(error))
      end
      raise_last_error("(yield)") if error
      Value.new(self, raw)
    end

    # Calls a method on a receiver, optionally passing an mruby block (Proc).
    # Raises `MRuby::Error` if the call raises.
    def funcall(receiver : Value, name : String, args : Array(CallbackValue) = [] of CallbackValue, block : Value? = nil) : Value
      ensure_open!
      ensure_same_state!(receiver)
      blk = if block
              ensure_same_state!(block)
              raise Error.new("expected Proc block, got #{block.type_name}") unless block.proc?
              block.raw_value
            else
              LibMRuby.mrb_cr_nil_value
            end
      argv = to_mrb_argv(args)
      error = false
      if argv.empty?
        raw = LibMRuby.mrb_cr_funcall(@raw, receiver.raw_value, name.to_unsafe, 0_i64,
          Pointer(LibMRuby::MrbValue).null, blk, pointerof(error))
      else
        raw = LibMRuby.mrb_cr_funcall(@raw, receiver.raw_value, name.to_unsafe, argv.size.to_i64,
          argv.to_unsafe, blk, pointerof(error))
      end
      raise_last_error("(funcall)") if error
      Value.new(self, raw)
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

    # Defines an instance method on `Object`, callable from the top level.
    #
    # Host method names must be unique within a state because mruby callbacks
    # are dispatched by method symbol.
    def define_method(name : String, arity : Int32, &block : Args -> CallbackValue) : Nil
      register_method(nil, name, arity, :instance, block)
    end

    # Defines an instance method on a previously defined class.
    def define_method(class_name : String, name : String, arity : Int32, &block : Args -> CallbackValue) : Nil
      register_method(class_name, name, arity, :instance, block)
    end

    # Defines a class method on a previously defined class.
    def define_class_method(class_name : String, name : String, arity : Int32, &block : Args -> CallbackValue) : Nil
      register_method(class_name, name, arity, :class, block)
    end

    # Defines a module function on a previously defined module.
    def define_module_function(module_name : String, name : String, arity : Int32, &block : Args -> CallbackValue) : Nil
      register_method(module_name, name, arity, :module, block)
    end

    # Defines a class with an optional superclass name.
    #
    # Defining an existing class without a superclass is a no-op. Redefining
    # an existing class with a superclass raises `MRuby::Error`.
    def define_class(name : String, superclass : String? = nil) : Nil
      ensure_open!
      existing = LibMRuby.mrb_cr_class_get(@raw, name.to_unsafe)
      unless existing.null?
        raise Error.new("class '#{name}' is already defined") if superclass
        return
      end

      super_pointer = superclass ? class_pointer(superclass) : Pointer(Void).null
      if superclass && LibMRuby.mrb_cr_module_pointer_p(super_pointer)
        raise Error.new("superclass '#{superclass}' is a module, not a class")
      end

      result = LibMRuby.mrb_cr_define_class(@raw, name.to_unsafe, super_pointer)
      raise Error.new("failed to define class '#{name}'") if result.null?
    end

    # Defines a module. Defining an existing module is a no-op.
    def define_module(name : String) : Nil
      ensure_open!
      return unless LibMRuby.mrb_cr_class_get(@raw, name.to_unsafe).null?
      result = LibMRuby.mrb_cr_define_module(@raw, name.to_unsafe)
      raise Error.new("failed to define module '#{name}'") if result.null?
    end

    # Defines a constant on `Object`.
    def define_const(name : String, value : CallbackValue) : Nil
      define_const(nil, name, value)
    end

    # Defines a constant on a class or module.
    def define_const(class_name : String?, name : String, value : CallbackValue) : Nil
      ensure_open!
      target = class_name ? class_pointer(class_name) : Pointer(Void).null
      LibMRuby.mrb_cr_define_const(@raw, target, name.to_unsafe, to_mrb_value(value))
    end

    # Internal: dispatches a host method call from the C trampoline.
    def dispatch_host_method(raw : Void*, result_ptr : LibMRuby::CallbackResult*) : Nil
      name_pointer = LibMRuby.mrb_cr_current_method_name(raw)
      name = name_pointer.null? ? "" : String.new(name_pointer)
      entry = @methods[name]?

      if entry.nil?
        LibMRuby.mrb_cr_callback_result_set(
          result_ptr, LibMRuby.mrb_cr_nil_value,
          "no host callback registered for '#{name}'".to_unsafe, 1)
        return
      end

      argc = LibMRuby.mrb_cr_current_argc(raw).to_i32
      if argc != entry.arity
        LibMRuby.mrb_cr_callback_result_set(
          result_ptr, LibMRuby.mrb_cr_nil_value,
          "wrong number of arguments (given #{argc}, expected #{entry.arity})".to_unsafe, 2)
        return
      end

      argv = LibMRuby.mrb_cr_current_argv(raw)
      args = Args.new(self, Slice(LibMRuby::MrbValue).new(argv, argc))

      begin
        result = entry.callback.call(args)
        LibMRuby.mrb_cr_callback_result_set(result_ptr, to_mrb_value(result), Pointer(UInt8).null, 0)
      rescue ex : Error
        LibMRuby.mrb_cr_callback_result_set(
          result_ptr, LibMRuby.mrb_cr_nil_value,
          (ex.message || "host callback error").to_unsafe, 1)
      rescue ex
        LibMRuby.mrb_cr_callback_result_set(
          result_ptr, LibMRuby.mrb_cr_nil_value,
          (ex.message || "host callback error").to_unsafe, 1)
      end
    end

    # Internal: raises `StateClosedError` when the state is closed.
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

    protected def ensure_same_state!(value : Value) : Nil
      unless value.state.same?(self)
        raise Error.new("value belongs to a different mruby state")
      end
    end

    private def to_mrb_argv(args : Array(CallbackValue)) : Array(LibMRuby::MrbValue)
      args.map { |arg| to_mrb_value(arg) }
    end

    private def register_method(owner : String?, name : String, arity : Int32,
                                kind : Symbol, callback : Proc(Args, CallbackValue)) : Nil
      ensure_open!
      raise Error.new("arity must be non-negative, got #{arity}") if arity < 0
      if @methods.has_key?(name)
        raise Error.new("host method '#{name}' is already defined in this state")
      end

      target = owner ? class_pointer(owner) : LibMRuby.mrb_cr_object_class(@raw)
      aspec = LibMRuby.mrb_cr_args_req(arity)
      name_pointer = name.to_unsafe

      case kind
      when :instance
        LibMRuby.mrb_cr_define_method(@raw, target, name_pointer, aspec)
      when :class
        LibMRuby.mrb_cr_define_class_method(@raw, target, name_pointer, aspec)
      when :module
        LibMRuby.mrb_cr_define_module_function(@raw, target, name_pointer, aspec)
      else
        raise Error.new("unknown method kind: #{kind}")
      end

      @methods[name] = MethodEntry.new(arity, callback, kind, owner)
    end

    private def class_pointer(name : String) : Void*
      pointer = LibMRuby.mrb_cr_class_get(@raw, name.to_unsafe)
      raise Error.new("class or module '#{name}' is not defined") if pointer.null?
      pointer
    end

    private def to_mrb_value(value : CallbackValue) : LibMRuby::MrbValue
      case value
      when Value
        ensure_same_state!(value)
        value.raw_value
      when Nil
        LibMRuby.mrb_cr_nil_value
      when Bool
        value ? LibMRuby.mrb_cr_true_value : LibMRuby.mrb_cr_false_value
      when String
        LibMRuby.mrb_cr_string_value(@raw, value.to_unsafe, value.bytesize.to_u64)
      when Float64
        LibMRuby.mrb_cr_float_value(@raw, value)
      when Int32, Int64
        LibMRuby.mrb_cr_integer_value(@raw, value.to_i64)
      else
        raise Error.new("cannot convert #{value.class} to an mruby value")
      end
    end

    private def raise_last_error(filename : String = "(eval)") : NoReturn
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
      message = message.scrub
      file, line = parse_location(message, filename)
      raise Error.new(message, script_class: class_name, script_file: file, script_line: line)
    end

    # mruby reports captured parser errors as "line N: ..." and some errors
    # as "<file>:<line>:<column>: ...".
    private def parse_location(message : String, filename : String) : {String?, Int32?}
      if match = message.match(/\Aline (\d+): /)
        {filename, match[1].to_i32}
      elsif match = message.match(/\A(.*):(\d+):(\d+): /)
        {match[1], match[2].to_i32}
      else
        {filename, nil}
      end
    end
  end

  # Internal: entry point for the C method trampoline.
  def self.dispatch(raw : Void*, _self_value : LibMRuby::MrbValue, result_ptr : LibMRuby::CallbackResult*) : Nil
    if state = State.from_raw(raw)
      state.dispatch_host_method(raw, result_ptr)
    else
      LibMRuby.mrb_cr_callback_result_set(
        result_ptr, LibMRuby.mrb_cr_nil_value, "unknown mruby state".to_unsafe, 1)
    end
  end
end

LibMRuby.mrb_cr_set_dispatch(
  ->(raw : Void*, self_value : LibMRuby::MrbValue, result_ptr : LibMRuby::CallbackResult*) do
    MRuby.dispatch(raw, self_value, result_ptr)
  end.pointer
)
