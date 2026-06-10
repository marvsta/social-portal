class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :logo_url
      t.string :website
      t.string :timezone, default: "UTC", null: false
      t.text :description

      t.timestamps
    end
    add_index :companies, :slug, unique: true
  end
end
