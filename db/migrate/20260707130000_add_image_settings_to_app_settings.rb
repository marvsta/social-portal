class AddImageSettingsToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :image_model, :string, null: false, default: "gpt-image-1-mini"
    add_column :app_settings, :image_quality, :string, null: false, default: "medium"
  end
end
