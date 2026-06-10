class SocialChannel < ApplicationRecord
  PLATFORMS = %w[instagram facebook linkedin twitter tiktok].freeze
  STATUSES = %w[active paused disconnected].freeze

  belongs_to :company
  has_many :channel_posts, dependent: :destroy
  has_many :posts, through: :channel_posts

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :handle, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
  scope :for_platform, ->(p) { where(platform: p) }

  def display
    display_name.presence || handle
  end

  def supports_auto_publish?
    platform == "instagram" && access_token.present? && external_account_id.present?
  end

  def platform_label
    {
      "instagram" => "Instagram",
      "facebook"  => "Facebook",
      "linkedin"  => "LinkedIn",
      "twitter"   => "X (Twitter)",
      "tiktok"    => "TikTok"
    }[platform] || platform.humanize
  end

  def platform_color
    {
      "instagram" => "#E1306C",
      "facebook"  => "#1877F2",
      "linkedin"  => "#0A66C2",
      "twitter"   => "#000000",
      "tiktok"    => "#69C9D0"
    }[platform] || "#7366FF"
  end
end
