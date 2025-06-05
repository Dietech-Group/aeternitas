require "spec_helper"

describe Aeternitas do
  it "has a version number" do
    expect(Aeternitas::VERSION).not_to be nil
  end

  describe ".enqueue_due_pollables" do
    it "enqueues all due pollables with next polling < Time.now " do
      due_pollable = FullPollable.create(name: "Foo")
      meta_data = due_pollable.pollable_meta_data
      meta_data.update!(state: "waiting", next_polling: 10.days.ago)
      Aeternitas.enqueue_due_pollables

      enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.find do |job|
        job[:job] == Aeternitas::PollJob && job[:args] == [due_pollable.pollable_meta_data.id]
      end
      expect(enqueued_job).to be_present
      expect(enqueued_job[:queue]).to eq(due_pollable.pollable_configuration.queue)
    end

    it "enqueues jobs in the right queue" do
      FullPollable.create(name: "Foo")
      SimplePollable.create(name: "Bar")
      Aeternitas.enqueue_due_pollables
      enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs

      jobs_in_full_pollables_queue = enqueued_jobs.filter do |job|
        job[:queue] == "full_pollables"
      end
      expect(jobs_in_full_pollables_queue.size).to eq(1)

      jobs_in_polling_queue = enqueued_jobs.filter do |job|
        job[:queue] == "polling"
      end
      expect(jobs_in_polling_queue.size).to eq(1)

      expect(enqueued_jobs.size).to eq(2)
    end

    it "does not enqueue pollables with state other than waiting" do
      enqueued_pollable = FullPollable.create(name: "Foo")
      meta_data = enqueued_pollable.pollable_meta_data
      meta_data.update!(state: "enqueued", next_polling: 10.days.ago)
      Aeternitas.enqueue_due_pollables

      job_not_enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.none? do |job|
        job[:job] == Aeternitas::PollJob && job[:args] == [enqueued_pollable.pollable_meta_data.id]
      end
      expect(job_not_enqueued).to be true
    end

    it "does not enqueue undue pollables" do
      undue_pollable = FullPollable.create(name: "Foo")
      meta_data = undue_pollable.pollable_meta_data
      meta_data.update!(state: "waiting", next_polling: 10.days.from_now)
      Aeternitas.enqueue_due_pollables

      job_not_enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.none? do |job|
        job[:job] == Aeternitas::PollJob && job[:args] == [undue_pollable.pollable_meta_data.id]
      end
      expect(job_not_enqueued).to be true
    end
  end
end
