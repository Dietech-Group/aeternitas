require "spec_helper"

describe Aeternitas::PollJob do
  let(:pollable_meta_data) { FullPollable.create(name: "Test Pollable").pollable_meta_data }
  let(:pollable) { pollable_meta_data.pollable }
  subject(:job) { described_class.new }

  describe "#perform" do
    it "finds the PollableMetaData and calls execute_poll on the pollable" do
      expect(Aeternitas::PollableMetaData).to receive(:find_by).with(id: pollable_meta_data.id).and_return(pollable_meta_data)
      expect(pollable_meta_data).to receive(:pollable).and_return(pollable)
      expect(pollable).to receive(:execute_poll)

      job.perform(pollable_meta_data.id)
    end
  end
end
