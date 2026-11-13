module MRuby
  # Raised for mruby parse errors, runtime errors, and C-boundary failures.
  class Error < Exception
    # mruby exception class name, when the error came from a script.
    getter script_class : String?

    # Script file reported by mruby, when available.
    getter script_file : String?

    # Script line reported by mruby, when available.
    getter script_line : Int32?

    def initialize(message : String, @script_class : String? = nil,
                   @script_file : String? = nil, @script_line : Int32? = nil)
      super(message)
    end
  end

  # Raised when a `State` or `Value` is used after the state has been closed.
  class StateClosedError < Error
    def initialize(message = "mruby state is closed")
      super(message)
    end
  end
end
