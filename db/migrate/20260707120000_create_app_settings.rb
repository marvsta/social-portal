class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.string :ai_provider, null: false, default: "anthropic"
      t.string :ai_model

      t.timestamps
    end
  end
end
