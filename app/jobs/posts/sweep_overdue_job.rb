module Posts
  # Safety net for scheduled posts whose PublishJob never fired (queue wiped,
  # job lost, worker down at the scheduled time). Runs on the Solid Queue
  # recurring schedule; enqueuing is idempotent because PublishJob claims
  # channel posts under a lock, so a sweep racing the real job is harmless.
  class SweepOverdueJob < ApplicationJob
    queue_as :default

    GRACE_PERIOD = 5.minutes

    def perform
      Post.where(status: "scheduled")
          .where(scheduled_at: ..GRACE_PERIOD.ago)
          .find_each do |post|
        Rails.logger.info("SweepOverdueJob: re-enqueueing publish for overdue post #{post.id}")
        PublishJob.perform_later(post.id, scheduled_for: post.scheduled_at)
      end
    end
  end
end
