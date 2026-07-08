class Membership < ApplicationRecord
  # Platform admins are not a membership role — that's the `admin` flag on User.
  # owner  = company admin: manages users, channels, settings, approves posts
  # editor = creates and manages posts for the company
  # viewer/member = read-only
  ROLES = %w[owner editor viewer member].freeze

  belongs_to :user
  belongs_to :company

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :company_id }

  def can_manage?
    role == "owner"
  end

  def can_publish?
    %w[owner editor].include?(role)
  end
end
