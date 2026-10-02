class Post < ApplicationRecord
  STATUSES = %w[draft pending_review approved scheduled publishing published partial_failure failed].freeze
  # post = feed post (image, video, or carousel); reel = one video published
  # as a Reel; story = one image/video, live 24h, no caption on Instagram.
  POST_TYPES = %w[post reel story].freeze

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
  CONTENT_FIELDS = %w[caption hashtags post_type].freeze

  # Stories carry no caption on Instagram, so don't force one.
  validates :caption, presence: true, unless: :story?
  validates :status, inclusion: { in: STATUSES }
  validates :post_type, inclusion: { in: POST_TYPES }
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

  def reel? = post_type == "reel"
  def story? = post_type == "story"

  # Nil-safe list/heading title: stories can have no caption.
  def display_title(length = 50)
    title.presence || caption.to_s.truncate(length).presence || "#{post_type_label} ##{id}"
  end

  def post_type_label
    { "post" => "Feed post", "reel" => "Reel", "story" => "Story" }[post_type] || post_type.humanize
  end

  def post_type_icon_class
    { "post" => "fa fa-th-large", "reel" => "fa fa-video-camera", "story" => "fa fa-clock-o" }[post_type] || "fa fa-th-large"
  end

  # Human-readable reasons this post can't be published yet, based on its
  # type/media combination. Checked before scheduling or publishing so the
  # user gets told up front instead of the job failing later. Only Instagram
  # auto-publishes, so the media rules only bite when an IG channel is on.
  def publish_blockers
    return [] if social_channels.none? { |c| c.platform == "instagram" }

    blockers = []
    attachments = media.attached? ? media.to_a : []
    if attachments.empty?
      blockers << "Instagram needs at least one image or video"
    elsif reel?
      blockers << "a reel needs exactly one video" unless attachments.size == 1 && attachments.first.video?
    elsif story?
      blockers << "a story needs exactly one image or video" unless attachments.size == 1
    end
    blockers
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
