module MRuby
  class State
    # Raw pointer to the underlying `mrb_state`. Internal.
    getter raw : Void*

    @closed = false

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
      raise MRuby::Error.new("failed to open mruby state") if @raw.null?
    end

    def closed?
      @closed
    end

    def close
      return if @closed
      LibMRuby.mrb_close(@raw)
      @closed = true
    end
  end
end
