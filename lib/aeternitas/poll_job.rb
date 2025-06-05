require_relative "application_job"

module Aeternitas
  # ActiveJob worker responsible for executing the polling.
  class PollJob < ApplicationJob
    queue_as :polling

    # Uniqueness and retry still missing

    def perform(pollable_meta_data_id)
      meta_data = Aeternitas::PollableMetaData.find_by(id: pollable_meta_data_id)
      if meta_data
        pollable = meta_data.pollable
        pollable&.execute_poll
      else
        ActiveJob::Base.logger.warn "Aeternitas::PollJob: PollableMetaData with ID #{pollable_meta_data_id} not found."
      end
    end
  end
end
