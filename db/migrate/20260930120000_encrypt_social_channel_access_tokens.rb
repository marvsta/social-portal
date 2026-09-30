class EncryptSocialChannelAccessTokens < ActiveRecord::Migration[8.1]
  # Data-only migration: re-saves every channel so plaintext access tokens
  # (stored before `encrypts :access_token` existed) get encrypted. Reading
  # plaintext still works via support_unencrypted_data, so this is safe to
  # run on a live app.
  def up
    SocialChannel.reset_column_information
    SocialChannel.where.not(access_token: nil).find_each(&:encrypt)
  end

  def down
    # Irreversible on purpose: we never write tokens back to plaintext.
  end
end
