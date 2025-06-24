require "spec_helper"

describe Aeternitas::Metrics do
  let(:pollable_class) { FullPollable }
  let!(:metric1) { Aeternitas::Metric.create!(name: "polls", pollable_class: pollable_class.name, value: 1, created_at: 12.hours.ago) }
  let!(:metric2) { Aeternitas::Metric.create!(name: "polls", pollable_class: pollable_class.name, value: 1, created_at: 20.minutes.ago) }
  let!(:metric3) { Aeternitas::Metric.create!(name: "polls", pollable_class: "OtherPollable", value: 1, created_at: 30.minutes.ago) }
  let!(:metric4) { Aeternitas::Metric.create!(name: "failed_polls", pollable_class: pollable_class.name, value: 1, created_at: 30.minutes.ago) }

  describe ".log" do
    it "creates a new metric record with a value of 1" do
      expect {
        Aeternitas::Metrics.log(:successful_polls, pollable_class)
      }.to change(Aeternitas::Metric, :count).by(1)

      last_metric = Aeternitas::Metric.order(:id).last
      expect(last_metric.name).to eq("successful_polls")
      expect(last_metric.pollable_class).to eq(pollable_class.name)
      expect(last_metric.value).to eq(1)
    end

    it "does not create a record for an unknown metric" do
      expect {
        Aeternitas::Metrics.log(:unknown_metric, pollable_class)
      }.not_to change(Aeternitas::Metric, :count)
    end
  end

  describe ".log_value" do
    it "creates a new metric record with the given value" do
      expect {
        Aeternitas::Metrics.log_value(:execution_time, pollable_class, 1.23)
      }.to change(Aeternitas::Metric, :count).by(1)

      last_metric = Aeternitas::Metric.order(:id).last
      expect(last_metric.name).to eq("execution_time")
      expect(last_metric.pollable_class).to eq(pollable_class.name)
      expect(last_metric.value).to eq(1.23)
    end
  end

  describe ".get" do
    it "retrieves the correct records within the time frame" do
      metrics = Aeternitas::Metrics.get(:polls, pollable_class, from: 1.hour.ago, to: Time.now)
      expect(metrics.count).to eq(1)
      expect(metrics.first).to eq(metric2)
    end

    it "retrieves all records if a larger time frame is given" do
      metrics = Aeternitas::Metrics.get(:polls, pollable_class, from: 1.day.ago)
      expect(metrics.count).to eq(2)
      expect(metrics).to include(metric1, metric2)
    end
  end
end
