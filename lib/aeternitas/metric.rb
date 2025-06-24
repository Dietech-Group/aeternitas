require "active_record"

module Aeternitas
  # Stores a single metric data point in the database.
  class Metric < ActiveRecord::Base
    self.table_name = "aeternitas_metrics"

    validates :name, presence: true
    validates :pollable_class, presence: true
    validates :value, presence: true
  end
end
