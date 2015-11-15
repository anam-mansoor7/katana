require 'test_helper'

class TestJobTest < ActiveSupport::TestCase
  describe "#total_running_time" do
    let(:job) { TestJob.new }

    it "returns the correct time when completed_at, started_at exist" do
      job.started_at = Time.current
      job.completed_at = Time.current + 3.minutes

      job.total_running_time.must_equal 3.minutes
    end

    it "returns the correct time when only started_at exists" do
      job.started_at = Time.current

      job.total_running_time.
        must_equal (Time.current - job.started_at).round
    end

    it "returns nil when no started_at, completed_at exist" do
      job.total_running_time.must_equal nil
    end
  end
end