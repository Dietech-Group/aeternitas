require "active_record"

module Aeternitas
  # Stores the state of a distributed lock in the database.
  class GuardLock < ActiveRecord::Base
    self.table_name = "aeternitas_guard_locks"

    enum state: {
      processing: "processing",
      cooldown: "cooldown",
      sleeping: "sleeping"
    }

    validates :lock_key, presence: true, uniqueness: true
    validates :locked_until, presence: true
    validates :token, presence: true
    validates :state, presence: true, inclusion: {in: states.keys}
  end
end
