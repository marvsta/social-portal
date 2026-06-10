class User < ApplicationRecord
  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :companies, through: :memberships
  has_many :sessions, dependent: :destroy
  has_many :authored_posts, class_name: "Post", foreign_key: :author_id, dependent: :nullify
  belongs_to :current_company, class_name: "Company", optional: true

  validates :email, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  normalizes :email, with: ->(value) { value.to_s.strip.downcase }

  def display_name
    name.presence || email.split("@").first
  end

  def member_of?(company)
    memberships.exists?(company_id: company.id)
  end

  def role_in(company)
    memberships.find_by(company_id: company.id)&.role
  end
end
