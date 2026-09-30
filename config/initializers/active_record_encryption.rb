# Active Record encryption (used for SocialChannel#access_token).
#
# Keys come from config/credentials.yml.enc (active_record_encryption:) by
# default. On hosts where the master key isn't available (or to rotate without
# re-encrypting credentials), the ENV vars below take precedence — set all
# three together.
Rails.application.configure do
  if ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].present?
    config.active_record.encryption.primary_key        = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key  = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
  end

  # Tokens saved before encryption was introduced are plaintext; read them
  # as-is and encrypt on the next save (a data migration re-saves them all).
  config.active_record.encryption.support_unencrypted_data = true
end
