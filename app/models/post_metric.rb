class PostMetric < ApplicationRecord
  belongs_to :channel_post

  validates :captured_at, presence: true

  scope :recent, -> { order(captured_at: :desc) }

  def total_engagement
    likes.to_i + comments.to_i + shares.to_i + saves.to_i
  end
end
