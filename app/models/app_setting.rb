# Global (all-companies) application settings. There is exactly one row,
# accessed through AppSetting.current.
class AppSetting < ApplicationRecord
  validates :ai_provider, inclusion: { in: proc { Ai::Providers.keys } }
  validate :model_matches_provider

  def self.current
    first_or_create!
  end

  def ai_model_or_default
    ai_model.presence || Ai::Providers.default_model(ai_provider)
  end

  private

  def model_matches_provider
    return if ai_model.blank?
    return unless Ai::Providers.keys.include?(ai_provider)
    unless Ai::Providers.model_ids(ai_provider).include?(ai_model)
      errors.add(:ai_model, "isn't available for the #{ai_provider} provider")
    end
  end
end
