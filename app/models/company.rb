class Company < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :social_channels, dependent: :destroy
  has_many :posts, dependent: :destroy
  # Users pointing at this company as their last-active one (users.current_company_id
  # has a FK, so it must be cleared before the company can be destroyed).
  has_many :current_users, class_name: "User", foreign_key: :current_company_id,
    inverse_of: :current_company, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9\-]+\z/, message: "may only contain lowercase letters, numbers, and dashes" }

  before_validation :ensure_slug

  def to_param
    slug
  end

  private

  def ensure_slug
    return if slug.present?
    self.slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
  end
end
