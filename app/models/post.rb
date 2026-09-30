class Post < ApplicationRecord
  STATUSES = %w[draft pending_review approved scheduled publishing published partial_failure failed].freeze

  belongs_to :company
  belongs_to :author, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :channel_posts, dependent: :destroy
  has_many :social_channels, through: :channel_posts
  has_many_attached :media

  # Statuses where the post hasn't gone out yet — a new scheduled_at must be
  # in the future for these. Published posts keep their (now past) time.
  PRE_PUBLISH_STATUSES = %w[draft pending_review approved scheduled].freeze
  # An edit to these fields after approval sends the post back to review.
  CONTENT_FIELDS = %w[caption hashtags].freeze

  validates :caption, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :scheduled_at_in_future, if: -> { scheduled_at_changed? && scheduled_at.present? && PRE_PUBLISH_STATUSES.include?(status) }

  before_save :revert_approval_on_content_change

  scope :upcoming, -> { where(status: %w[scheduled approved pending_review]).order(:scheduled_at) }
  scope :published, -> { where(status: %w[published partial_failure]) }
  scope :between, ->(from, to) { where(scheduled_at: from..to) }

  def status_label
    {
      "draft"            => "Draft",
      "pending_review"   => "Pending review",
      "approved"         => "Approved",
      "scheduled"        => "Scheduled",
      "publishing"       => "Publishing…",
      "published"        => "Published",
      "partial_failure"  => "Partial failure",
      "failed"           => "Failed"
    }[status] || status.humanize
  end

  def status_color
    {
      "draft"            => "#A0AEC0",
      "pending_review"   => "#F59E0B",
      "approved"         => "#10B981",
      "scheduled"        => "#7366FF",
      "publishing"       => "#3B82F6",
      "published"        => "#16A34A",
      "partial_failure"  => "#EA580C",
      "failed"           => "#DC2626"
    }[status] || "#7366FF"
  end

  def submit_for_review!
    update!(status: "pending_review")
  end

  def approve!(approver)
    update!(status: "approved", approved_by: approver, approved_at: Time.current)
  end

  def schedule!
    raise ArgumentError, "Cannot schedule without a scheduled_at" if scheduled_at.blank?
    update!(status: "scheduled")
  end

  def primary_media_url
    return nil unless media.attached?
    Rails.application.routes.url_helpers.rails_blob_path(media.first, only_path: true)
  rescue StandardError
    nil
  end

  def total_engagement
    channel_posts.includes(:post_metrics).sum do |cp|
      latest = cp.post_metrics.order(captured_at: :desc).first
      latest ? (latest.likes + latest.comments + latest.shares + latest.saves) : 0
    end
  end

  private

  # Approval covers specific content. If the caption, hashtags, or media
  # change after sign-off, the approval no longer applies: send the post back
  # to review. Workflow transitions change status explicitly and are exempt;
  # a knocked-back scheduled post also invalidates its pending PublishJob,
  # whose status guard refuses to run on a pending_review post.
  def revert_approval_on_content_change
    return unless %w[approved scheduled].include?(status)
    return if status_changed?
    return unless CONTENT_FIELDS.any? { |f| will_save_change_to_attribute?(f) } || attachment_changes.any?
    self.status = "pending_review"
    self.approved_by = nil
    self.approved_at = nil
  end

  def scheduled_at_in_future
    return if scheduled_at.blank?
    errors.add(:scheduled_at, "must be in the future") if scheduled_at <= Time.current
  end
end
