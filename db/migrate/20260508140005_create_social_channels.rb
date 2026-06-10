class CreateSocialChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :social_channels do |t|
      t.references :company, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :handle
      t.string :display_name
      t.string :avatar_url
      t.string :external_account_id
      t.text :access_token
      t.datetime :token_expires_at
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_index :social_channels, [ :company_id, :platform ]
  end
end
