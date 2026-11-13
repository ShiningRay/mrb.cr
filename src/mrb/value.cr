module MRuby
  # Converted representation of JSON-like mruby values.
  #
  # Modeled after `JSON::Any`: a single wrapper with a recursive union makes
  # nested arrays and hashes usable without exposing mruby pointers.
  struct CrystalValue
    alias Raw = Nil | Bool | Int64 | Float64 | String | Array(CrystalValue) | Hash(CrystalValue, CrystalValue)

    getter raw : Raw

    def initialize(@raw : Raw)
    end

    def is_nil? : Bool
      @raw.nil?
    end

    def as_bool? : Bool?
      @raw.as?(Bool)
    end

    def as_i64? : Int64?
      @raw.as?(Int64)
    end

    def as_f64? : Float64?
      @raw.as?(Float64)
    end

    def as_s? : String?
      @raw.as?(String)
    end

    def as_array? : Array(CrystalValue)?
      @raw.as?(Array(CrystalValue))
    end

    def as_hash? : Hash(CrystalValue, CrystalValue)?
      @raw.as?(Hash(CrystalValue, CrystalValue))
    end

    def ==(other : CrystalValue) : Bool
      @raw == other.raw
    end

    def hash(hasher)
      @raw.hash(hasher)
    end

    def inspect(io : IO) : Nil
      @raw.inspect(io)
    end

    def to_s(io : IO) : Nil
      @raw.to_s(io)
    end
  end

  # A single mruby value tied to an open `State`.
  #
  # Values are shallow handles. They stay valid while the state is open and the
  # object is still reachable from mruby's GC roots. Register a `Ref` for
  # long-lived references.
  class Value
    getter state : State

    def initialize(@state : State, @raw : LibMRuby::MrbValue)
    end

    # Returns `true` for mruby `nil`.
    #
    # Named `is_nil?` because Crystal reserves `nil?` for its own type tests.
    def is_nil? : Bool
      ensure_open!
      LibMRuby.mrb_cr_nil_p(@raw)
    end

    def true? : Bool
      ensure_open!
      LibMRuby.mrb_cr_true_p(@raw)
    end

    def false? : Bool
      ensure_open!
      LibMRuby.mrb_cr_false_p(@raw)
    end

    def bool? : Bool
      ensure_open!
      true? || false?
    end

    def integer? : Bool
      ensure_open!
      LibMRuby.mrb_cr_integer_p(@raw)
    end

    def float? : Bool
      ensure_open!
      LibMRuby.mrb_cr_float_p(@raw)
    end

    def string? : Bool
      ensure_open!
      LibMRuby.mrb_cr_string_p(@raw)
    end

    def array? : Bool
      ensure_open!
      LibMRuby.mrb_cr_array_p(@raw)
    end

    def hash? : Bool
      ensure_open!
      LibMRuby.mrb_cr_hash_p(@raw)
    end

    def symbol? : Bool
      ensure_open!
      LibMRuby.mrb_cr_symbol_p(@raw)
    end

    # Converts a boolean value. `nil`, `false`, and `true` are accepted;
    # other types raise `MRuby::Error`.
    def as_bool : Bool
      ensure_open!
      return false if is_nil? || false?
      return true if true?
      raise type_error("Bool")
    end

    def as_i64 : Int64
      ensure_open!
      raise type_error("Integer") unless integer?
      LibMRuby.mrb_cr_integer_as_i64(@raw)
    end

    def as_f64 : Float64
      ensure_open!
      raise type_error("Float") unless float?
      LibMRuby.mrb_cr_float_as_f64(@raw)
    end

    # Copies the mruby string bytes into a Crystal `String`.
    def as_s : String
      ensure_open!
      raise type_error("String") unless string?
      state.copy_string(@raw)
    end

    # Returns a shallow array of values.
    def as_array : Array(Value)
      ensure_open!
      raise type_error("Array") unless array?
      len = LibMRuby.mrb_cr_array_len(@raw).to_i
      Array(Value).new(len) do |index|
        Value.new(state, LibMRuby.mrb_cr_array_entry(@raw, index.to_i64))
      end
    end

    # Returns a shallow hash of values.
    def as_hash : Hash(Value, Value)
      ensure_open!
      raise type_error("Hash") unless hash?
      keys = LibMRuby.mrb_cr_hash_keys(state.raw, @raw)
      len = LibMRuby.mrb_cr_array_len(keys).to_i
      result = Hash(Value, Value).new(initial_capacity: len)
      len.times do |index|
        key = Value.new(state, LibMRuby.mrb_cr_array_entry(keys, index.to_i64))
        value = Value.new(state, LibMRuby.mrb_cr_hash_get(state.raw, @raw, key.raw))
        result[key] = value
      end
      result
    end

    # Name of the mruby class, for example `"Integer"` or `"Object"`.
    def type_name : String
      ensure_open!
      pointer = LibMRuby.mrb_cr_class_name(state.raw, @raw)
      pointer.null? ? "unknown" : String.new(pointer)
    end

    # Recursively converts JSON-like values into Crystal values.
    #
    # Raises `MRuby::Error` for unsupported object types or when the depth or
    # node limit is exceeded.
    def to_crystal(max_depth : Int32 = 64, max_nodes : Int32 = 100_000) : CrystalValue
      ensure_open!
      Converter.new(max_depth, max_nodes).convert(self, 0)
    end

    # Registers this value with mruby's GC so it survives arena restoration
    # and GC cycles until the returned `Ref` is released.
    def ref : Ref
      ensure_open!
      Ref.new(state, @raw)
    end

    # Renders the JSON-like value, or a placeholder for unsupported or closed
    # values.
    def inspect(io : IO) : Nil
      to_crystal.inspect(io)
    rescue ex : Error
      io << "#<MRuby::Value " << (state.closed? ? "closed" : type_name) << '>'
    end

    def ==(other : Value) : Bool
      @raw.w == other.raw.w && state.same?(other.state)
    end

    def hash(hasher)
      @raw.w.hash(hasher)
    end

    # Internal: raw handle used by the callback dispatcher.
    def raw_value : LibMRuby::MrbValue
      ensure_open!
      @raw
    end

    protected def raw : LibMRuby::MrbValue
      @raw
    end

    protected def ensure_open! : Nil
      raise StateClosedError.new if state.closed?
    end

    protected def type_error(expected : String) : Error
      Error.new("expected #{expected}, got #{type_name}")
    end

    private class Converter
      def initialize(@max_depth : Int32, @max_nodes : Int32)
        @nodes = 0
      end

      def convert(value : Value, depth : Int32) : CrystalValue
        @nodes += 1
        raise Error.new("value exceeds node limit (#{@max_nodes})") if @nodes > @max_nodes
        raise Error.new("value exceeds depth limit (#{@max_depth})") if depth > @max_depth

        if value.is_nil?
          CrystalValue.new(nil)
        elsif value.true?
          CrystalValue.new(true)
        elsif value.false?
          CrystalValue.new(false)
        elsif value.integer?
          CrystalValue.new(value.as_i64)
        elsif value.float?
          CrystalValue.new(value.as_f64)
        elsif value.string?
          CrystalValue.new(value.as_s)
        elsif value.array?
          elements = value.as_array
          CrystalValue.new(
            Array(CrystalValue).new(elements.size) do |index|
              convert(elements[index], depth + 1)
            end
          )
        elsif value.hash?
          pairs = value.as_hash
          result = Hash(CrystalValue, CrystalValue).new(initial_capacity: pairs.size)
          pairs.each do |key, item|
            result[convert(key, depth + 1)] = convert(item, depth + 1)
          end
          CrystalValue.new(result)
        else
          raise Error.new("cannot convert #{value.type_name} to a Crystal value")
        end
      end
    end
  end
end
