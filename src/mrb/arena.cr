module MRuby
  # Convenience wrapper for `State#arena`.
  module Arena
    # Runs the block inside a GC arena and restores it afterwards.
    def self.open(state : State, &)
      state.arena do
        yield
      end
    end
  end
end
