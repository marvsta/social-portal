class Membership < ApplicationRecord
  ROLES = %w[owner admin editor viewer member].freeze

  belongs_to :user
  belongs_to :company

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :company_id }

  def can_manage?
    %w[owner admin].include?(role)
  end

  def can_publish?
    %w[owner admin editor].include?(role)
  end
end
