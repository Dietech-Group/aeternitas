module Aeternitas
  # Provides test helpers for aeternitas
  module Test
    # Executes a block of code in test mode; all cooldowns and wait times are set to 0.
    def self.test_mode
      original_mode = Aeternitas.test_mode?
      Aeternitas.test_mode = true
      yield
    ensure
      Aeternitas.test_mode = original_mode
    end
  end
end
