class ChannelPost < ApplicationRecord
  STATUSES = %w[pending publishing published failed skipped].freeze

  belongs_to :post
  belongs_to :social_channel
  has_many :post_metrics, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :post_id, uniqueness: { scope: :social_channel_id }

  scope :published, -> { where(status: "published") }

  def latest_metric
    post_metrics.order(captured_at: :desc).first
  end

  def engagement
    m = latest_metric
    return 0 unless m
    m.likes.to_i + m.comments.to_i + m.shares.to_i + m.saves.to_i
  end

  def mark_publishing!
    update!(status: "publishing", last_attempted_at: Time.current, attempts: attempts + 1)
  end

  def mark_published!(external_id:, external_url: nil)
    update!(status: "published", published_at: Time.current, external_id: external_id, external_url: external_url, last_error: nil)
  end

  def mark_failed!(error_message)
    update!(status: "failed", last_error: error_message)
  end
end
